CREATE TABLE IF NOT EXISTS `{{PROJECT_ID}}.bronze_core_banking.transaction_status_history`
(
  event_id       INT64     OPTIONS(description = 'PK - định danh sự kiện đổi trạng thái (source: bigint, NOT NULL)'),
  transaction_id INT64     OPTIONS(description = 'FK -> transactions.transaction_id - giao dịch liên quan (source: bigint, NOT NULL)'),
  old_status     STRING    OPTIONS(description = 'Trạng thái trước đó, trống nếu là sự kiện khởi tạo (source: text, NULLABLE)'),
  new_status     STRING    OPTIONS(description = 'Trạng thái mới (source: text, NOT NULL)'),
  event_time     TIMESTAMP OPTIONS(description = 'Thời điểm đổi trạng thái (source: timestamptz, NOT NULL)'),
  source_system  STRING    OPTIONS(description = 'Hệ thống ghi nhận sự kiện (source: text, NOT NULL) -- lưu ý: khác với cột lineage _source_system của Bronze'),
  created_at     TIMESTAMP OPTIONS(description = 'Thời điểm tạo bản ghi tại source (source: timestamptz, NOT NULL)'),
  updated_at     TIMESTAMP OPTIONS(description = 'Watermark incremental load (source: timestamptz, NOT NULL)'),

  -- ---- Bronze metadata (ingestion lineage) ----
  _ingested_at        TIMESTAMP DEFAULT CURRENT_TIMESTAMP() OPTIONS(description = 'Thời điểm nạp vào Bronze'),
  _source_system      STRING    OPTIONS(description = "Hệ thống nguồn của pipeline ingest, vd: 'core_banking_postgres'"),
  _ingestion_batch_id STRING    OPTIONS(description = 'Batch/job id của lần ingest')
)
PARTITION BY DATE(_ingested_at)
CLUSTER BY transaction_id
OPTIONS (
  description = 'Bronze - raw copy của bảng core_banking.public.transaction_status_history'
);
