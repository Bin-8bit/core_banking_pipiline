CREATE TABLE IF NOT EXISTS `{{PROJECT_ID}}.bronze_core_banking.channels`
(
  channel_id   INT64     OPTIONS(description = 'PK - định danh kênh (source: bigint, NOT NULL)'),
  channel_code STRING    OPTIONS(description = "Mã kênh, vd. MOBILE_BANKING (source: text, NOT NULL)"),
  channel_name STRING    OPTIONS(description = 'Tên kênh hiển thị (source: text, NOT NULL)'),
  is_active    BOOL      OPTIONS(description = 'Còn hoạt động hay không (source: boolean, NOT NULL)'),
  created_at   TIMESTAMP OPTIONS(description = 'Thời điểm tạo bản ghi tại source (source: timestamptz, NOT NULL)'),
  updated_at   TIMESTAMP OPTIONS(description = 'Watermark incremental load (source: timestamptz, NOT NULL)'),

  -- ---- Bronze metadata (ingestion lineage) ----
  _ingested_at        TIMESTAMP DEFAULT CURRENT_TIMESTAMP() OPTIONS(description = 'Thời điểm nạp vào Bronze'),
  _source_system      STRING    OPTIONS(description = "Hệ thống nguồn, vd: 'core_banking_postgres'"),
  _ingestion_batch_id STRING    OPTIONS(description = 'Batch/job id của lần ingest')
)
PARTITION BY DATE(_ingested_at)
OPTIONS (
  description = 'Bronze - raw copy của bảng core_banking.public.channels'
);
