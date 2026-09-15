import argparse
import sys
import time
import uuid
from datetime import datetime, timezone

try:
    from etl import config
    from etl.extract import count_rows, extract_table, get_engine, test_connection
    from etl.load import add_metadata, create_bronze_tables, get_client, load_table
    from etl.logger import setup_logger
except ImportError as e:
    print(f"ERROR: Thiếu thư viện — {e}", file=sys.stderr)
    print("", file=sys.stderr)
    print("Hãy cài dependencies trước khi chạy:", file=sys.stderr)
    print("    ./run.sh setup", file=sys.stderr)
    print("hoặc thủ công:", file=sys.stderr)
    print("    python3 -m venv venv && source venv/bin/activate", file=sys.stderr)
    print("    pip install -r requirements.txt", file=sys.stderr)
    sys.exit(1)


def parse_args():
    parser = argparse.ArgumentParser(
        description="Pipeline full-load: PostgreSQL core_banking -> BigQuery Bronze layer"
    )
    parser.add_argument(
        "--tables",
        help="Danh sách bảng cách nhau bởi dấu phẩy (mặc định: toàn bộ 11 bảng)",
    )
    parser.add_argument(
        "--create-tables-only",
        action="store_true",
        help="Chỉ tạo dataset + bảng Bronze rồi thoát, không load dữ liệu",
    )
    parser.add_argument(
        "--skip-create-tables",
        action="store_true",
        help="Bỏ qua bước tạo bảng (dùng khi bảng đã tồn tại)",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Chỉ extract từ Postgres và đếm dòng, không ghi lên BigQuery",
    )
    parser.add_argument(
        "--write-mode",
        choices=["WRITE_TRUNCATE", "WRITE_APPEND"],
        default="WRITE_TRUNCATE",
        help="WRITE_TRUNCATE: ghi đè (mặc định, cho full load). "
             "WRITE_APPEND: ghi thêm (cho incremental sau này).",
    )
    return parser.parse_args()


def print_summary(logger, results, run_id, started_at):
    """In bảng tổng kết kết quả từng bảng vào log."""
    elapsed_total = time.time() - started_at

    logger.info("")
    logger.info("=" * 70)
    logger.info("TỔNG KẾT — run_id=%s", run_id)
    logger.info("=" * 70)
    logger.info("%-32s %12s %10s %10s", "BẢNG", "SỐ DÒNG", "TRẠNG THÁI", "THỜI GIAN")
    logger.info("-" * 70)

    for r in results:
        rows = f"{r['rows']:,}" if r["rows"] is not None else "-"
        logger.info("%-32s %12s %10s %9.1fs",
                    r["table"], rows, r["status"], r["elapsed"])

    logger.info("-" * 70)

    ok = [r for r in results if r["status"] in ("OK", "DRY-RUN")]
    failed = [r for r in results if r["status"] == "FAILED"]
    total_rows = sum(r["rows"] or 0 for r in ok)

    is_dry_run = any(r["status"] == "DRY-RUN" for r in results)
    label = "Đã kiểm tra" if is_dry_run else "Thành công"

    logger.info("%s: %d/%d bảng | Tổng số dòng: %s | Tổng thời gian: %.1fs",
                label, len(ok), len(results), f"{total_rows:,}", elapsed_total)

    if is_dry_run and not failed:
        logger.info("")
        logger.info("Dry-run OK. Chạy thật bằng: ./run.sh run")

    if failed:
        logger.error("Các bảng bị lỗi: %s",
                     ", ".join(r["table"] for r in failed))
        logger.error("Chạy lại riêng các bảng lỗi: python main.py --tables %s",
                     ",".join(r["table"] for r in failed))

    logger.info("=" * 70)
    return len(failed)


def main():
    args = parse_args()

    run_id = str(uuid.uuid4())
    started_at = time.time()
    logger = setup_logger(run_id)

    # --- Validate cấu hình ---
    try:
        config.validate()
    except ValueError as e:
        logger.error(str(e))
        sys.exit(1)

    tables = args.tables.split(",") if args.tables else config.TABLES
    ingested_at = datetime.now(timezone.utc)

    logger.info("Postgres  : %s:%s/%s (schema=%s)",
                config.PG_HOST, config.PG_PORT, config.PG_DB, config.PG_SCHEMA)
    logger.info("BigQuery  : %s.%s (%s)",
                config.GCP_PROJECT_ID, config.BQ_DATASET, config.BQ_LOCATION)
    logger.info("Chế độ    : %s",
                "DRY-RUN (không ghi lên BQ)" if args.dry_run
                else f"FULL LOAD ({args.write_mode})")
    logger.info("Số bảng   : %d — %s", len(tables), ", ".join(tables))
    logger.info("")

    # --- Khởi tạo BigQuery client ---
    bq_client = None
    if not args.dry_run:
        try:
            bq_client = get_client()
            logger.info("Kết nối BigQuery thành công.")
        except Exception as e:
            logger.error("Không kết nối được BigQuery: %s", e)
            logger.error("Gợi ý: chạy `gcloud auth application-default login` trước.")
            sys.exit(1)

    #Tạo dataset + bảng Bronze
    if not args.dry_run and not args.skip_create_tables:
        try:
            create_bronze_tables(bq_client)
        except Exception as e:
            logger.error("Lỗi khi tạo bảng Bronze: %s", e)
            sys.exit(1)

        if args.create_tables_only:
            logger.info("Đã chọn --create-tables-only, kết thúc tại đây.")
            sys.exit(0)

    #Kết nối Postgres
    try:
        engine = get_engine()
        version = test_connection(engine)
        logger.info("Kết nối Postgres thành công: %s", version.split(",")[0])
        logger.info("")
    except Exception as e:
        logger.error("Không kết nối được Postgres: %s", e)
        logger.error("Kiểm tra PG_HOST/PG_PORT/PG_USER/PG_PASSWORD trong .env, "
                     "và xem máy có truy cập được %s:%s không.",
                     config.PG_HOST, config.PG_PORT)
        sys.exit(1)

    #Extract + Load từng bảng
    results = []
    for table_name in tables:
        table_name = table_name.strip()
        t0 = time.time()
        logger.info("-" * 70)

        try:
            src_count = count_rows(engine, table_name)
            logger.info("[%s] Source có %s dòng.", table_name, f"{src_count:,}")

            df = extract_table(engine, table_name)

            if args.dry_run:
                logger.info("[%s] DRY-RUN: bỏ qua bước load lên BigQuery.", table_name)
                results.append({
                    "table": table_name, "rows": len(df),
                    "status": "DRY-RUN", "elapsed": time.time() - t0,
                })
                continue

            df = add_metadata(df, run_id, ingested_at)
            rows_loaded = load_table(bq_client, df, table_name, args.write_mode)

            # Đối chiếu số dòng source vs số dòng đã load
            if rows_loaded != src_count:
                logger.warning("[%s] CHÊNH LỆCH: source=%s nhưng loaded=%s",
                               table_name, f"{src_count:,}", f"{rows_loaded:,}")

            results.append({
                "table": table_name, "rows": rows_loaded,
                "status": "OK", "elapsed": time.time() - t0,
            })

        except Exception as e:
            logger.exception("[%s] THẤT BẠI: %s", table_name, e)
            results.append({
                "table": table_name, "rows": None,
                "status": "FAILED", "elapsed": time.time() - t0,
            })

    engine.dispose()

    #Tổng kết
    failed_count = print_summary(logger, results, run_id, started_at)
    sys.exit(1 if failed_count else 0)


if __name__ == "__main__":
    main()
