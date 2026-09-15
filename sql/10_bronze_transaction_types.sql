CREATE TABLE IF NOT EXISTS `{{PROJECT_ID}}.bronze_core_banking.transaction_types`
(
  transaction_type_id   INT64     OPTIONS(description = 'PK - định danh loại giao dịch (source: bigint, NOT NULL)'),
  transaction_type_code STRING    OPTIONS(description = 'Mã loại, vd. TRANSFER (source: text, NOT NULL)'),
  transaction_type_name STRING    OPTIONS(description = 'Tên loại hiển thị (source: text, NOT NULL)'),
  is_active             BOOL      OPTIONS(description = 'Còn được sử dụng hay không (source: boolean, NOT NULL)'),
  created_at            TIMESTAMP OPTIONS(description = 'Thời điểm tạo bản ghi tại source (source: timestamptz, NOT NULL)'),
  updated_at            TIMESTAMP OPTIONS(description = 'Watermark incremental load (source: timestamptz, NOT NULL)'),

  -- ---- Bronze metadata (ingestion lineage) ----
  _ingested_at        TIMESTAMP DEFAULT CURRENT_TIMESTAMP() OPTIONS(description = 'Thời điểm nạp vào Bronze'),
  _source_system      STRING    OPTIONS(description = "Hệ thống nguồn, vd: 'core_banking_postgres'"),
  _ingestion_batch_id STRING    OPTIONS(description = 'Batch/job id của lần ingest')
)
PARTITION BY DATE(_ingested_at)
OPTIONS (
  description = 'Bronze - raw copy của bảng core_banking.public.transaction_types'
);
