CREATE TABLE IF NOT EXISTS `{{PROJECT_ID}}.bronze_core_banking.transactions`
(
  transaction_id          INT64         OPTIONS(description = 'PK - định danh giao dịch (source: bigint, NOT NULL)'),
  transaction_reference   STRING        OPTIONS(description = 'Mã tham chiếu giao dịch, hiển thị cho khách (source: text, NOT NULL)'),
  source_account_id       INT64         OPTIONS(description = 'FK -> accounts.account_id - tài khoản nguồn/bên trích tiền (source: bigint, NULLABLE)'),
  destination_account_id  INT64         OPTIONS(description = 'FK -> accounts.account_id - tài khoản đích, chỉ có ở GD chuyển khoản (source: bigint, NULLABLE)'),
  card_id                 INT64         OPTIONS(description = 'FK -> cards.card_id - thẻ dùng để GD, nếu có (source: bigint, NULLABLE)'),
  merchant_id             INT64         OPTIONS(description = 'FK -> merchants.merchant_id - merchant nhận thanh toán, nếu có (source: bigint, NULLABLE)'),
  branch_id               INT64         OPTIONS(description = 'FK -> branches.branch_id - chi nhánh nơi GD phát sinh, khác branch của account (source: bigint, NULLABLE)'),
  channel_id              INT64         OPTIONS(description = 'FK -> channels.channel_id - kênh thực hiện GD (source: bigint, NULLABLE)'),
  transaction_type_id     INT64         OPTIONS(description = 'FK -> transaction_types.transaction_type_id - loại GD (source: bigint, NULLABLE)'),
  currency_code           STRING        OPTIONS(description = 'FK -> currencies.currency_code - loại tiền của GD (source: text, NULLABLE)'),
  amount                  NUMERIC(18,2) OPTIONS(description = 'Số tiền giao dịch (source: numeric(18,2), NULLABLE)'),
  fee_amount              NUMERIC(18,2) OPTIONS(description = 'Phí giao dịch (source: numeric(18,2), NULLABLE)'),
  status                  STRING        OPTIONS(description = 'SUCCESS / PENDING / FAILED (source: text, NULLABLE)'),
  failure_reason          STRING        OPTIONS(description = 'Lý do thất bại, chỉ có khi status = FAILED (source: text, NULLABLE)'),
  transaction_time        TIMESTAMP     OPTIONS(description = 'Thời điểm giao dịch thực tế xảy ra (source: timestamptz, NULLABLE)'),
  created_at              TIMESTAMP     OPTIONS(description = 'Thời điểm tạo bản ghi tại source (source: timestamptz, NOT NULL)'),
  updated_at              TIMESTAMP     OPTIONS(description = 'Watermark incremental load (source: timestamptz, NOT NULL)'),

  -- ---- Bronze metadata (ingestion lineage) ----
  _ingested_at        TIMESTAMP DEFAULT CURRENT_TIMESTAMP() OPTIONS(description = 'Thời điểm nạp vào Bronze'),
  _source_system      STRING    OPTIONS(description = "Hệ thống nguồn, vd: 'core_banking_postgres'"),
  _ingestion_batch_id STRING    OPTIONS(description = 'Batch/job id của lần ingest')
)
PARTITION BY DATE(_ingested_at)
CLUSTER BY source_account_id, transaction_time
OPTIONS (
  description = 'Bronze - raw copy của bảng core_banking.public.transactions (bảng fact trung tâm)'
);
