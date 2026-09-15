CREATE TABLE IF NOT EXISTS `{{PROJECT_ID}}.bronze_core_banking.branches`
(
  branch_id   INT64     OPTIONS(description = 'PK - định danh chi nhánh (source: bigint, NOT NULL)'),
  branch_code STRING    OPTIONS(description = 'Mã chi nhánh (source: text, NOT NULL)'),
  branch_name STRING    OPTIONS(description = 'Tên chi nhánh (source: text, NOT NULL)'),
  city        STRING    OPTIONS(description = 'Thành phố (source: text, NOT NULL)'),
  region      STRING    OPTIONS(description = 'Vùng/miền quản lý (source: text, NOT NULL)'),
  opened_date DATE      OPTIONS(description = 'Ngày khai trương chi nhánh (source: date, NOT NULL)'),
  is_active   BOOL      OPTIONS(description = 'Còn hoạt động hay đã đóng (source: boolean, NOT NULL)'),
  created_at  TIMESTAMP OPTIONS(description = 'Thời điểm tạo bản ghi tại source (source: timestamptz, NOT NULL)'),
  updated_at  TIMESTAMP OPTIONS(description = 'Watermark incremental load (source: timestamptz, NOT NULL)'),

  -- ---- Bronze metadata (ingestion lineage) ----
  _ingested_at        TIMESTAMP DEFAULT CURRENT_TIMESTAMP() OPTIONS(description = 'Thời điểm nạp vào Bronze'),
  _source_system      STRING    OPTIONS(description = "Hệ thống nguồn, vd: 'core_banking_postgres'"),
  _ingestion_batch_id STRING    OPTIONS(description = 'Batch/job id của lần ingest')
)
PARTITION BY DATE(_ingested_at)
CLUSTER BY branch_id
OPTIONS (
  description = 'Bronze - raw copy của bảng core_banking.public.branches'
);
