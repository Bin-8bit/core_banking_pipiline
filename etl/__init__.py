"""
ETL package cho pipeline core_banking: PostgreSQL -> BigQuery (Bronze layer).

Modules:
    config   — cấu hình đọc từ .env, danh sách bảng
    logger   — thiết lập logging ra console + file
    extract  — đọc dữ liệu từ PostgreSQL
    load     — tạo bảng và nạp dữ liệu lên BigQuery
"""

__version__ = "1.0.0"
