CREATE TABLE IF NOT EXISTS `{{PROJECT_ID}}.bronze_core_banking.accounts`
(
  account_id       INT64         OPTIONS(description = 'PK - định danh tài khoản (source: bigint, NOT NULL)'),
  account_number   STRING        OPTIONS(description = 'Số tài khoản hiển thị cho khách (source: text, NOT NULL)'),
  customer_id      INT64         OPTIONS(description = 'FK -> customers.customer_id - chủ tài khoản (source: bigint, NOT NULL)'),
  branch_id        INT64         OPTIONS(description = 'FK -> branches.branch_id - chi nhánh quản lý tài khoản (source: bigint, NOT NULL)'),
  product_id       INT64         OPTIONS(description = 'FK -> products.product_id - sản phẩm áp dụng (source: bigint, NOT NULL)'),
  currency_code    STRING        OPTIONS(description = 'FK -> currencies.currency_code - loại tiền của tài khoản (source: text, NOT NULL)'),
  account_status   STRING        OPTIONS(description = 'Trạng thái tài khoản, vd. ACTIVE/CLOSED (source: text, NOT NULL)'),
  opened_at        TIMESTAMP     OPTIONS(description = 'Thời điểm mở tài khoản (source: timestamptz, NOT NULL)'),
  closed_at        TIMESTAMP     OPTIONS(description = 'Thời điểm đóng tài khoản, trống nếu còn mở (source: timestamptz, NULLABLE)'),
  current_balance  NUMERIC(18,2) OPTIONS(description = 'Số dư hiện tại (source: numeric(18,2), NOT NULL)'),
  created_at       TIMESTAMP     OPTIONS(description = 'Thời điểm tạo bản ghi tại source (source: timestamptz, NOT NULL)'),
  updated_at       TIMESTAMP     OPTIONS(description = 'Watermark incremental load (source: timestamptz, NOT NULL)'),

  -- ---- Bronze metadata (ingestion lineage) ----
  _ingested_at        TIMESTAMP DEFAULT CURRENT_TIMESTAMP() OPTIONS(description = 'Thời điểm nạp vào Bronze'),
  _source_system      STRING    OPTIONS(description = "Hệ thống nguồn, vd: 'core_banking_postgres'"),
  _ingestion_batch_id STRING    OPTIONS(description = 'Batch/job id của lần ingest')
)
PARTITION BY DATE(_ingested_at)
CLUSTER BY account_id
OPTIONS (
  description = 'Bronze - raw copy của bảng core_banking.public.accounts'
);
