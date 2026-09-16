import os
from pathlib import Path

from dotenv import load_dotenv

# Thư mục gốc của project
BASE_DIR = Path(__file__).resolve().parent.parent
SQL_DIR = BASE_DIR / "sql"
LOG_DIR = BASE_DIR / "logs"

# Nạp biến môi trường từ .env ở thư mục gốc project
load_dotenv(BASE_DIR / ".env")

# ---------------------------------------------------------------------------
# PostgreSQL
# ---------------------------------------------------------------------------
PG_HOST = os.getenv("PG_HOST")
PG_PORT = os.getenv("PG_PORT", "5432")
PG_DB = os.getenv("PG_DB", "core_banking")
PG_USER = os.getenv("PG_USER")
PG_PASSWORD = os.getenv("PG_PASSWORD")
PG_SCHEMA = os.getenv("PG_SCHEMA", "public")

# ---------------------------------------------------------------------------
# BigQuery
# ---------------------------------------------------------------------------
GCP_PROJECT_ID = os.getenv("GCP_PROJECT_ID")
BQ_DATASET = os.getenv("BQ_DATASET", "bronze_core_banking")
BQ_LOCATION = os.getenv("BQ_LOCATION", "asia-southeast1")

# Đường dẫn tới service account key
GOOGLE_APPLICATION_CREDENTIALS = os.getenv("GOOGLE_APPLICATION_CREDENTIALS")

# ---------------------------------------------------------------------------
# Pipeline
# ---------------------------------------------------------------------------
SOURCE_SYSTEM = os.getenv("SOURCE_SYSTEM", "core_banking_postgres")

# Số dòng đọc mỗi lần từ Postgres
CHUNK_SIZE = int(os.getenv("CHUNK_SIZE", "50000"))

# Thứ tự migrate
TABLES = [
    "currencies",
    "channels",
    "transaction_types",
    "branches",
    "products",
    "merchants",
    "customers",
    "accounts",
    "cards",
    "transactions",
    "transaction_status_history",
]

#Trả về connection URI của Postgres cho SQLAlchemy
def get_pg_uri() -> str:
    return (
        f"postgresql+psycopg2://{PG_USER}:{PG_PASSWORD}"
        f"@{PG_HOST}:{PG_PORT}/{PG_DB}"
    )

#Kiểm tra các biến bắt buộc đã được khai báo trong .env chưa
def validate() -> None:
    missing = []
    if not PG_HOST:
        missing.append("PG_HOST")
    if not PG_USER:
        missing.append("PG_USER")
    if not PG_PASSWORD:
        missing.append("PG_PASSWORD")
    if not GCP_PROJECT_ID:
        missing.append("GCP_PROJECT_ID")

    if missing:
        raise ValueError(
            f"Thiếu biến môi trường bắt buộc: {', '.join(missing)}. "
            f"Hãy kiểm tra file .env tại {BASE_DIR / '.env'} "
            f"(tham khảo .env.example)."
        )