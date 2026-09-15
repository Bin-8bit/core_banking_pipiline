"""
extract.py — Đọc dữ liệu từ PostgreSQL nguồn (core_banking).

Chịu trách nhiệm duy nhất: lấy dữ liệu thô ra khỏi Postgres.
Không transform, không biết gì về BigQuery — đúng tinh thần tầng Bronze.
"""

import logging

import pandas as pd
from sqlalchemy import create_engine, text

from etl.config import CHUNK_SIZE, PG_SCHEMA, get_pg_uri

logger = logging.getLogger("pipeline")


def get_engine():
    """Tạo SQLAlchemy engine kết nối tới Postgres nguồn."""
    return create_engine(get_pg_uri(), pool_pre_ping=True)


def test_connection(engine) -> str:
    """
    Kiểm tra kết nối tới Postgres, trả về version string.
    Gọi hàm này trước khi chạy pipeline để fail sớm nếu sai credential.
    """
    with engine.connect() as conn:
        version = conn.execute(text("SELECT version();")).scalar()
    return version


def count_rows(engine, table_name: str) -> int:
    """Đếm số dòng của 1 bảng ở source — dùng để đối chiếu sau khi load."""
    query = text(f"SELECT COUNT(*) FROM {PG_SCHEMA}.{table_name};")
    with engine.connect() as conn:
        return conn.execute(query).scalar()


def extract_table(engine, table_name: str) -> pd.DataFrame:
    """
    Đọc toàn bộ dữ liệu 1 bảng từ Postgres về DataFrame (full load).

    Với bảng lớn, dùng chunksize để đọc theo lô rồi ghép lại, tránh
    việc pandas giữ toàn bộ result set trong RAM cùng lúc.
    """
    query = f"SELECT * FROM {PG_SCHEMA}.{table_name};"
    logger.info("[%s] Extracting: %s", table_name, query)

    chunks = []
    total = 0
    for chunk in pd.read_sql(query, engine, chunksize=CHUNK_SIZE):
        chunks.append(chunk)
        total += len(chunk)
        logger.info("[%s] ... đã đọc %s dòng", table_name, f"{total:,}")

    if not chunks:
        logger.warning("[%s] Bảng rỗng, không có dòng nào.", table_name)
        return pd.DataFrame()

    df = pd.concat(chunks, ignore_index=True)
    logger.info("[%s] Extract xong: %s dòng, %d cột",
                table_name, f"{len(df):,}", len(df.columns))
    return df
