CREATE TABLE IF NOT EXISTS `{{PROJECT_ID}}.bronze_core_banking.customers`
(
  customer_id       INT64     OPTIONS(description = 'PK - định danh khách hàng (source: bigint, NOT NULL)'),
  customer_code     STRING    OPTIONS(description = 'Mã khách hàng nghiệp vụ, hiển thị cho GDV (source: text, NOT NULL)'),
  full_name         STRING    OPTIONS(description = 'Họ tên đầy đủ (source: text, NOT NULL)'),
  date_of_birth     DATE      OPTIONS(description = 'Ngày sinh (source: date, NOT NULL)'),
  gender            STRING    OPTIONS(description = 'Giới tính (source: text, NOT NULL)'),
  phone_number      STRING    OPTIONS(description = 'Số điện thoại liên hệ (source: text, NULLABLE)'),
  email             STRING    OPTIONS(description = 'Email liên hệ (source: text, NULLABLE)'),
  city              STRING    OPTIONS(description = 'Thành phố cư trú (source: text, NOT NULL)'),
  customer_segment  STRING    OPTIONS(description = 'Phân khúc khách hàng, vd. RETAIL/VIP (source: text, NOT NULL)'),
  kyc_status        STRING    OPTIONS(description = 'Trạng thái định danh khách hàng (source: text, NOT NULL)'),
  created_at        TIMESTAMP OPTIONS(description = 'Thời điểm tạo bản ghi tại source (source: timestamptz, NOT NULL)'),
  updated_at        TIMESTAMP OPTIONS(description = 'Watermark incremental load (source: timestamptz, NOT NULL)'),

  -- ---- Bronze metadata (ingestion lineage) ----
  _ingested_at        TIMESTAMP DEFAULT CURRENT_TIMESTAMP() OPTIONS(description = 'Thời điểm nạp vào Bronze'),
  _source_system      STRING    OPTIONS(description = "Hệ thống nguồn, vd: 'core_banking_postgres'"),
  _ingestion_batch_id STRING    OPTIONS(description = 'Batch/job id của lần ingest')
)
PARTITION BY DATE(_ingested_at)
CLUSTER BY customer_id
OPTIONS (
  description = 'Bronze - raw copy của bảng core_banking.public.customers'
);
