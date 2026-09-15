# Core Banking Pipeline — PostgreSQL → BigQuery (Bronze Layer)

Pipeline ELT full-load đưa toàn bộ 11 bảng của hệ thống `core_banking`
từ PostgreSQL sang BigQuery, tạo thành tầng **Bronze** trong kiến trúc
Medallion (Bronze → Silver → Gold).

## Kiến trúc

```
   PostgreSQL (core_banking)                BigQuery (bronze_core_banking)
   ─────────────────────────                ──────────────────────────────
   currencies                     3
   channels                       5
   transaction_types              5
   branches                      30              cùng 11 bảng
   products                       6   EXTRACT    cùng tên cột
   merchants                    500  ─────────►  cùng kiểu dữ liệu
   customers                  5,000    LOAD      + 3 cột lineage
   accounts                   7,000
   cards                      4,000
   transactions              50,000
   transaction_status_history 130,126
   ─────────────────────────
   Tổng: 196,675 dòng
```

**Nguyên tắc tầng Bronze:** dữ liệu giữ nguyên cấu trúc so với source,
không transform, không join. Mỗi bảng chỉ được bổ sung 3 cột metadata
phục vụ truy vết:

| Cột | Ý nghĩa |
|---|---|
| `_ingested_at` | Thời điểm nạp vào Bronze (cũng là cột partition) |
| `_source_system` | Định danh hệ nguồn (`core_banking_postgres`) |
| `_ingestion_batch_id` | UUID của lần chạy pipeline — truy vết record thuộc batch nào |

## Cấu trúc project

```
core_banking_pipeline/
├── etl/                       # Package chính
│   ├── __init__.py
│   ├── config.py              # Đọc .env, danh sách bảng, validate cấu hình
│   ├── logger.py              # Thiết lập log ra console + file
│   ├── extract.py             # Đọc dữ liệu từ PostgreSQL
│   └── load.py                # Tạo bảng + nạp dữ liệu lên BigQuery
├── sql/                       # DDL tạo dataset & 11 bảng Bronze
│   ├── 00_create_dataset.sql
│   ├── 01_bronze_accounts.sql
│   ├── ...
│   └── 11_bronze_transactions.sql
├── logs/                      # Log mỗi lần chạy (không commit lên git)
├── main.py                    # Điểm chạy chính
├── run.sh                     # Script setup & chạy nhanh
├── requirements.txt
├── .env.example               # Mẫu cấu hình — copy thành .env
├── .gitignore
└── README.md
```

## Yêu cầu

- **Python 3.9 – 3.12** (khuyến nghị 3.12)
- Google Cloud CLI (`gcloud`)
- Quyền `BigQuery Data Editor` + `BigQuery Job User` trên GCP project
- Thông tin đăng nhập PostgreSQL nguồn

> **Lưu ý về phiên bản Python:** Python 3.13/3.14 hiện chưa có bản wheel
> biên dịch sẵn cho `pyarrow`, `pandas`, `psycopg2-binary`. Cài trên các
> phiên bản này sẽ khiến pip phải build từ source — rất lâu và thường lỗi.
> Kiểm tra bằng `python3 --version` trước khi setup.

## Cài đặt

### Cách 1 — dùng venv (mặc định)

```bash
cd core_banking_pipeline
chmod +x run.sh
./run.sh setup
```

Nếu `python3` trên máy là 3.13+, chỉ định phiên bản khác:

```bash
PYTHON_BIN=python3.12 ./run.sh setup
```

### Cách 2 — dùng conda

```bash
conda create -n banking python=3.12 -y
conda activate banking
pip install -r requirements.txt
cp .env.example .env
```

Với conda thì gọi thẳng `python main.py ...` thay cho `./run.sh ...`
(xem bảng đối chiếu ở mục Sử dụng).

### Điền cấu hình

M�� file `.env` vừa tạo và điền giá trị thật — **không để nguyên giá trị mẫu**:

```ini
PG_HOST=<địa chỉ server postgres>
PG_PORT=<cổng>
PG_USER=<tên đăng nhập>
PG_PASSWORD=<mật khẩu>
GCP_PROJECT_ID=<id project trên GCP>
```

File `.env` đã được `.gitignore` loại trừ nên sẽ không bị commit lên git.

### Đăng nhập Google Cloud

```bash
gcloud auth application-default login
```

> `gcloud auth login` (dùng cho CLI) **khác** với
> `gcloud auth application-default login` (dùng cho thư viện Python).
> Pipeline này chạy bằng Python nên cần lệnh thứ hai.

## Sử dụng

| Lệnh `run.sh` | Tương đương khi dùng conda | Tác dụng |
|---|---|---|
| `./run.sh check` | `python main.py --dry-run` | Kiểm tra kết nối + đếm dòng, KHÔNG ghi lên BQ |
| `./run.sh tables` | `python main.py --create-tables-only` | Chỉ tạo dataset + 11 bảng Bronze |
| `./run.sh run` | `python main.py` | Tạo bảng + full load dữ liệu |
| `./run.sh logs` | `cat logs/$(ls -t logs \| head -1)` | Xem log lần chạy gần nhất |
| `./run.sh clean` | — | Xoá venv và cache Python |

Tham số bổ sung được truyền thẳng qua `run.sh run`:

```bash
./run.sh run --tables accounts,transactions   # chỉ xử lý vài bảng
./run.sh run --skip-create-tables             # bỏ qua bước tạo bảng
./run.sh run --write-mode WRITE_APPEND        # ghi thêm thay vì ghi đè
```

## Quy trình lần chạy đầu

```bash
./run.sh setup     # 1. Setup môi trường
                   # 2. Điền .env + gcloud auth application-default login
./run.sh check     # 3. Xác nhận kết nối 2 đầu đều OK
./run.sh run       # 4. Tạo bảng + load dữ liệu thật
./run.sh logs      # 5. Kiểm tra kết quả
```

## Kiểm chứng sau khi load

Chạy query sau trên BigQuery Console để đối chiếu số dòng:

```sql
SELECT 'accounts' AS table_name, COUNT(*) AS row_count
FROM `<PROJECT_ID>.bronze_core_banking.accounts`
UNION ALL SELECT 'branches', COUNT(*) FROM `<PROJECT_ID>.bronze_core_banking.branches`
UNION ALL SELECT 'cards', COUNT(*) FROM `<PROJECT_ID>.bronze_core_banking.cards`
UNION ALL SELECT 'channels', COUNT(*) FROM `<PROJECT_ID>.bronze_core_banking.channels`
UNION ALL SELECT 'currencies', COUNT(*) FROM `<PROJECT_ID>.bronze_core_banking.currencies`
UNION ALL SELECT 'customers', COUNT(*) FROM `<PROJECT_ID>.bronze_core_banking.customers`
UNION ALL SELECT 'merchants', COUNT(*) FROM `<PROJECT_ID>.bronze_core_banking.merchants`
UNION ALL SELECT 'products', COUNT(*) FROM `<PROJECT_ID>.bronze_core_banking.products`
UNION ALL SELECT 'transaction_status_history', COUNT(*) FROM `<PROJECT_ID>.bronze_core_banking.transaction_status_history`
UNION ALL SELECT 'transaction_types', COUNT(*) FROM `<PROJECT_ID>.bronze_core_banking.transaction_types`
UNION ALL SELECT 'transactions', COUNT(*) FROM `<PROJECT_ID>.bronze_core_banking.transactions`
ORDER BY row_count DESC;
```

Số dòng kỳ vọng: 130,126 / 50,000 / 7,000 / 5,000 / 4,000 / 500 / 30 / 6 / 5 / 5 / 3.

Kiểm tra thêm độ chính xác số tiền bằng cách so tổng số dư ở hai đầu:

```sql
-- BigQuery
SELECT SUM(current_balance) FROM `<PROJECT_ID>.bronze_core_banking.accounts`;
-- PostgreSQL (DBeaver) — kết quả phải khớp
SELECT SUM(current_balance) FROM public.accounts;
```

> **Lưu ý về tab Preview trên BigQuery:** các bảng đều có partition
> (`PARTITION BY DATE(_ingested_at)`), nên tab Preview đôi khi hiển thị
> "There is no data to display" dù dữ liệu đã có. Luôn dùng `COUNT(*)`
> để kiểm tra thay vì tin vào Preview.

## Log

M��i lần chạy sinh 1 file log riêng: `logs/pipeline_YYYYmmdd_HHMMSS.log`,
ghi lại số dòng từng bảng ở source, số dòng đã load lên BigQuery, thời gian
xử lý, cảnh báo chênh lệch số dòng, và bảng tổng kết cuối cùng.

Nếu một bảng lỗi, pipeline vẫn chạy tiếp các bảng còn lại rồi báo cáo ở
phần tổng kết, kèm gợi ý lệnh chạy lại riêng bảng đó.

Thư mục `logs/` được `.gitignore` loại trừ nội dung (chỉ giữ `.gitkeep`).

## Ghi chú thiết kế

- **`WRITE_TRUNCATE` mặc định** — ghi đè toàn bộ bảng đích. Phù hợp với
  full load một lần và giúp chạy lại nhiều lần vẫn cho kết quả giống nhau
  (idempotent), không sinh dữ liệu trùng.
- **Không dùng autodetect schema** — pipeline lấy schema thật của bảng đích
  trên BigQuery để truyền vào job load, tránh việc BigQuery suy ra sai kiểu
  dữ liệu.
- **Ép kiểu cột NUMERIC** — pandas thường đọc cột `NUMERIC(18,2)` của Postgres
  thành `float64` (8 byte), trong khi pyarrow cần `decimal128` (16 byte) để
  khớp kiểu NUMERIC của BigQuery; không xử lý sẽ gặp lỗi
  `ArrowInvalid: Got bytestring of length 8 (expected 16)`. Hàm
  `coerce_numeric_columns()` trong `etl/load.py` ép các cột này về
  `Decimal` đúng scale trước khi load — ảnh hưởng tới `accounts.current_balance`,
  `transactions.amount` và `transactions.fee_amount`.
- **Đọc theo chunk** — bảng `transaction_status_history` có ~130K dòng;
  `CHUNK_SIZE` trong `.env` kiểm soát số dòng đọc mỗi lượt để tránh tràn RAM.
- **Thứ tự bảng** — dimension nhỏ chạy trước, fact lớn chạy sau. BigQuery
  không enforce khóa ngoại nên thứ tự chỉ giúp log dễ theo dõi và phát hiện
  lỗi sớm trên bảng nhỏ.
- **Partition + cluster** — mọi bảng `PARTITION BY DATE(_ingested_at)` để
  tiết kiệm chi phí quét và dễ quản lý retention; các bảng lớn thêm
  `CLUSTER BY` trên cột khóa hay dùng để lọc/join.

## Bước tiếp theo

Pipeline này dừng ở tầng Bronze. Các tầng sau:

- **Silver**: chuẩn hoá kiểu dữ liệu, khử trùng lặp, kiểm tra chất lượng
  dữ liệu, xử lý SCD.
- **Gold**: bảng nghiệp vụ/mart phục vụ BI và analytics.

Nếu sau này cần chuyển sang **incremental load**, cột `updated_at` ở source
đã được thiết kế sẵn làm watermark: đổi câu extract thành
`WHERE updated_at > <watermark_cuối>`, đổi sang `--write-mode WRITE_APPEND`,
và lưu lại watermark sau mỗi lần chạy thành công.

## Xử lý lỗi thường gặp

| Lỗi | Nguyên nhân & cách xử lý |
|---|---|
| Cài dependencies rất lâu / lỗi build | Python 3.13+ chưa có wheel sẵn — dùng Python 3.12 |
| `Thiếu biến môi trường bắt buộc` | Chưa điền `.env` — kiểm tra `PG_HOST`, `PG_USER`, `PG_PASSWORD`, `GCP_PROJECT_ID` |
| `password authentication failed for user "your_postgres_username"` | `.env` vẫn còn giá trị mẫu, chưa điền giá trị thật |
| `DefaultCredentialsError` | Chưa chạy `gcloud auth application-default login` |
| `404 Not found: Table` | Bảng Bronze chưa tồn tại — chạy `./run.sh tables` |
| `ArrowInvalid: Got bytestring of length 8 (expected 16)` | Cột NUMERIC chưa được ép về Decimal — cập nhật `etl/load.py` lên bản mới nhất |
| `could not connect to server` | Sai `PG_HOST`/`PG_PORT`, hoặc firewall/VPN chặn kết nối |
| `403 Access Denied` | Tài khoản thiếu quyền BigQuery Data Editor / Job User |
| Preview trống dù đã load xong | Hành vi bình thường của bảng partition — kiểm tra bằng `COUNT(*)` |