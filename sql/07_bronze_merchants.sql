CREATE TABLE IF NOT EXISTS `{{PROJECT_ID}}.bronze_core_banking.merchants`
(
  merchant_id       INT64     OPTIONS(description = 'PK - định danh merchant (source: bigint, NOT NULL)'),
  merchant_code     STRING    OPTIONS(description = 'Mã merchant (source: text, NOT NULL)'),
  merchant_name     STRING    OPTIONS(description = 'Tên merchant (source: text, NOT NULL)'),
  merchant_category STRING    OPTIONS(description = 'Ngành hàng, vd. F&B, Retail (source: text, NOT NULL)'),
  city              STRING    OPTIONS(description = 'Thành phố đặt điểm bán (source: text, NOT NULL)'),
  is_active         BOOL      OPTIONS(description = 'Còn hợp tác hay không (source: boolean, NOT NULL)'),
  created_at        TIMESTAMP OPTIONS(description = 'Thời điểm tạo bản ghi tại source (source: timestamptz, NOT NULL)'),
  updated_at        TIMESTAMP OPTIONS(description = 'Watermark incremental load (source: timestamptz, NOT NULL)'),

  -- ---- Bronze metadata (ingestion lineage) ----
  _ingested_at        TIMESTAMP DEFAULT CURRENT_TIMESTAMP() OPTIONS(description = 'Thời điểm nạp vào Bronze'),
  _source_system      STRING    OPTIONS(description = "Hệ thống nguồn, vd: 'core_banking_postgres'"),
  _ingestion_batch_id STRING    OPTIONS(description = 'Batch/job id của lần ingest')
)
PARTITION BY DATE(_ingested_at)
CLUSTER BY merchant_id
OPTIONS (
  description = 'Bronze - raw copy của bảng core_banking.public.merchants'
);
