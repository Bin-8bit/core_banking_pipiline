# Core Banking Pipeline — PostgreSQL → BigQuery

Pipeline ELT nạp 11 bảng của hệ thống `core_banking` từ PostgreSQL lên
BigQuery, tạo tầng **Bronze** trong kiến trúc Medallion.

**Bronze = bản sao thô của source.** Giữ nguyên tên bảng, tên cột, kiểu dữ
liệu; không transform, không join. Mỗi bảng chỉ thêm 3 cột truy vết:
`_ingested_at`, `_source_system`, `_ingestion_batch_id`.

| Bảng | Số dòng |
|---|---:|
| transaction_status_history | 130,126 |
| transactions | 50,000 |
| accounts | 7,000 |
| customers | 5,000 |
| cards | 4,000 |
| merchants | 500 |
| branches | 30 |
| products | 6 |
| channels | 5 |
| transaction_types | 5 |
| currencies | 3 |
| **Tổng** | **196,675** |

## Cấu trúc

```
├── etl/
│   ├── config.py     # Đọc .env, danh sách bảng
│   ├── logger.py     # Ghi log ra console + file
│   ├── extract.py    # Đọc từ PostgreSQL
│   └── load.py       # Tạo bảng + nạp lên BigQuery
├── sql/              # DDL tạo dataset & 11 bảng Bronze
├── logs/             # Log mỗi lần chạy
├── main.py           # Chạy pipeline
└── run.sh            # Script tiện dụng
```

## Cài đặt

Cần **Python 3.9–3.12**

```bash
chmod +x run.sh
./run.sh setup                  # tạo venv, cài thư viện, sinh file .env
cp .env.example .env            # nếu setup chưa tự tạo
```

Điền thông tin thật vào `.env`:

```ini
PG_HOST=...
PG_USER=...
PG_PASSWORD=...
GCP_PROJECT_ID=...
```

Đăng nhập Google Cloud cho thư viện Python:

```bash
gcloud auth application-default login
```

> Lệnh này khác `gcloud auth login`. Pipeline chạy bằng Python nên cần đúng
> lệnh trên.

## Chạy

```bash
./run.sh check     # Thử kết nối + đếm dòng, chưa ghi lên BigQuery
./run.sh run       # Tạo bảng + nạp dữ liệu
./run.sh logs      # Xem log lần chạy gần nhất
```

Chạy lại vài bảng cụ thể:

```bash
./run.sh run --tables accounts,transactions
```

Dùng conda thay vì venv thì gọi thẳng: `python main.py`,
`python main.py --dry-run`, `python main.py --tables ...`

## Kiểm tra kết quả

```sql
SELECT COUNT(*) FROM `<PROJECT_ID>.bronze_core_banking.transactions`;
```

> Tab **Preview** của BigQuery hay hiện "no data" với bảng có partition dù
> dữ liệu đã có. Luôn dùng `COUNT(*)` để kiểm tra.

## Ghi chú

- Mặc định **ghi đè** (`WRITE_TRUNCATE`) nên chạy lại nhiều lần không sinh
  dữ liệu trùng.
- Cột `NUMERIC(18,2)` được ép về `Decimal` trước khi load, tránh lỗi
  `ArrowInvalid` và sai số tiền.
- Bảng lỗi không làm dừng pipeline; phần tổng kết cuối log sẽ chỉ ra bảng nào
  cần chạy lại.
- File `.env` chứa mật khẩu, đã được `.gitignore` loại trừ.

## Lỗi thường gặp

| Lỗi | Cách xử lý |
|---|---|
| Cài thư viện rất lâu | Dùng Python 3.12 thay vì 3.13+ |
| `Thiếu biến môi trường bắt buộc` | Chưa điền `.env` |
| `password authentication failed for user "your_postgres_username"` | `.env` còn giá trị mẫu |
| `DefaultCredentialsError` | Chưa chạy `gcloud auth application-default login` |
| `404 Not found: Table` | Chạy `./run.sh run` để tạo bảng trước |
| `403 Access Denied` | Thiếu quyền BigQuery Data Editor / Job User |

## Tiếp theo

**Silver**: chuẩn hoá kiểu dữ liệu, khử trùng lặp, kiểm tra chất lượng.
**Gold**: bảng nghiệp vụ phục vụ báo cáo.

Muốn chuyển sang incremental load: dùng cột `updated_at` làm watermark và
đổi sang `--write-mode WRITE_APPEND`.