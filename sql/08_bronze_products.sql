CREATE TABLE IF NOT EXISTS `{{PROJECT_ID}}.bronze_core_banking.products`
(
  product_id     INT64     OPTIONS(description = 'PK - định danh sản phẩm (source: bigint, NOT NULL)'),
  product_code   STRING    OPTIONS(description = 'Mã sản phẩm, vd. SAV_USD (source: text, NOT NULL)'),
  product_name   STRING    OPTIONS(description = 'Tên sản phẩm hiển thị (source: text, NOT NULL)'),
  product_type   STRING    OPTIONS(description = 'CURRENT_ACCOUNT / SAVINGS_ACCOUNT / CREDIT_ACCOUNT (source: text, NOT NULL)'),
  currency_code  STRING    OPTIONS(description = 'FK -> currencies.currency_code - loại tiền của sản phẩm (source: text, NOT NULL)'),
  is_active      BOOL      OPTIONS(description = 'Còn được bán hay đã ngừng (source: boolean, NOT NULL)'),
  created_at     TIMESTAMP OPTIONS(description = 'Thời điểm tạo bản ghi tại source (source: timestamptz, NOT NULL)'),
  updated_at     TIMESTAMP OPTIONS(description = 'Watermark incremental load (source: timestamptz, NOT NULL)'),

  -- ---- Bronze metadata (ingestion lineage) ----
  _ingested_at        TIMESTAMP DEFAULT CURRENT_TIMESTAMP() OPTIONS(description = 'Thời điểm nạp vào Bronze'),
  _source_system      STRING    OPTIONS(description = "Hệ thống nguồn, vd: 'core_banking_postgres'"),
  _ingestion_batch_id STRING    OPTIONS(description = 'Batch/job id của lần ingest')
)
PARTITION BY DATE(_ingested_at)
CLUSTER BY product_id
OPTIONS (
  description = 'Bronze - raw copy của bảng core_banking.public.products'
);
