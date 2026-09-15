import logging
from datetime import datetime, timezone
from decimal import Decimal, ROUND_HALF_UP

import pandas as pd
from google.cloud import bigquery

from etl.config import (
    BQ_DATASET,
    BQ_LOCATION,
    GCP_PROJECT_ID,
    SOURCE_SYSTEM,
    SQL_DIR,
)

logger = logging.getLogger("pipeline")

#Tạo BigQuery client
def get_client() -> bigquery.Client:
    return bigquery.Client(project=GCP_PROJECT_ID, location=BQ_LOCATION)

#Tạo dataset và toàn bộ bảng Bronze
def create_bronze_tables(client: bigquery.Client) -> int:
    sql_files = sorted(SQL_DIR.glob("*.sql"))
    if not sql_files:
        raise FileNotFoundError(f"Không tìm thấy file .sql nào trong {SQL_DIR}")

    logger.info("Bắt đầu tạo dataset + bảng Bronze (%d file SQL)", len(sql_files))

    for sql_file in sql_files:
        sql = sql_file.read_text(encoding="utf-8")
        sql = sql.replace("{{PROJECT_ID}}", GCP_PROJECT_ID)
        sql = sql.replace("{{LOCATION}}", BQ_LOCATION)

        logger.info("  -> Chạy %s", sql_file.name)
        job = client.query(sql)
        job.result()  # chờ hoàn tất, raise nếu lỗi

    logger.info("Đã tạo xong dataset %s.%s và toàn bộ bảng Bronze.",
                GCP_PROJECT_ID, BQ_DATASET)
    return len(sql_files)

#Bổ sung 3 cột lineage của tầng Bronze
def add_metadata(df: pd.DataFrame, run_id: str, ingested_at: datetime) -> pd.DataFrame:
    df = df.copy()
    df["_ingested_at"] = ingested_at
    df["_source_system"] = SOURCE_SYSTEM
    df["_ingestion_batch_id"] = run_id
    return df

#Ép kiểu các cột
def coerce_numeric_columns(df: pd.DataFrame, schema, table_name: str) -> pd.DataFrame:
    numeric_fields = [
        f for f in schema
        if f.field_type in ("NUMERIC", "BIGNUMERIC") and f.name in df.columns
    ]
    if not numeric_fields:
        return df

    df = df.copy()
    for field in numeric_fields:
        scale = field.scale if field.scale is not None else 2
        quant = Decimal(1).scaleb(-scale)

        def to_decimal(value):
            if value is None:
                return None
            try:
                if pd.isna(value):
                    return None
            except (TypeError, ValueError):
                pass  # Decimal/str không hỗ trợ pd.isna, bỏ qua
            # Đi qua str() để tránh sai số nhị phân của float
            return Decimal(str(value)).quantize(quant, rounding=ROUND_HALF_UP)

        before = df[field.name].dtype
        df[field.name] = df[field.name].map(to_decimal).astype(object)
        logger.info("[%s] Ép kiểu cột NUMERIC '%s': %s -> Decimal(scale=%d)",
                    table_name, field.name, before, scale)

    return df

#Nạp DataFrame vào bảng Bronze tương ứng trên BigQuery
def load_table(
    client: bigquery.Client,
    df: pd.DataFrame,
    table_name: str,
    write_mode: str = "WRITE_TRUNCATE",
) -> int:
    table_ref = f"{GCP_PROJECT_ID}.{BQ_DATASET}.{table_name}"

    # get_table sẽ raise NotFound nếu bảng chưa tồn tại
    dest_table = client.get_table(table_ref)

    # Ép cột NUMERIC về Decimal trước khi pyarrow chuyển đổi
    df = coerce_numeric_columns(df, dest_table.schema, table_name)

    job_config = bigquery.LoadJobConfig(
        schema=dest_table.schema,
        write_disposition=getattr(bigquery.WriteDisposition, write_mode),
        autodetect=False,
    )

    logger.info("[%s] Loading %s dòng vào %s (%s)",
                table_name, f"{len(df):,}", table_ref, write_mode)

    job = client.load_table_from_dataframe(df, table_ref, job_config=job_config)
    job.result()

    # Đọc lại số dòng thực tế trong bảng sau khi load để đối chiếu
    final_table = client.get_table(table_ref)
    logger.info("[%s] Load xong. Tổng số dòng trong bảng: %s",
                table_name, f"{final_table.num_rows:,}")

    return job.output_rows or len(df)