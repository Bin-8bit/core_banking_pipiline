CREATE TABLE IF NOT EXISTS `{{PROJECT_ID}}.bronze_core_banking.cards`
(
  card_id             INT64     OPTIONS(description = 'PK - định danh thẻ (source: bigint, NOT NULL)'),
  masked_card_number  STRING    OPTIONS(description = 'Số thẻ đã che, không lưu số đầy đủ (source: text, NOT NULL)'),
  account_id          INT64     OPTIONS(description = 'FK -> accounts.account_id - tài khoản gắn với thẻ (source: bigint, NOT NULL)'),
  card_type           STRING    OPTIONS(description = 'Loại thẻ: DEBIT/CREDIT... (source: text, NOT NULL)'),
  card_status         STRING    OPTIONS(description = 'Trạng thái thẻ: ACTIVE/BLOCKED... (source: text, NOT NULL)'),
  issued_at           TIMESTAMP OPTIONS(description = 'Ngày phát hành thẻ (source: timestamptz, NOT NULL)'),
  expired_at          TIMESTAMP OPTIONS(description = 'Ngày hết hạn thẻ (source: timestamptz, NOT NULL)'),
  created_at          TIMESTAMP OPTIONS(description = 'Thời điểm tạo bản ghi tại source (source: timestamptz, NOT NULL)'),
  updated_at          TIMESTAMP OPTIONS(description = 'Watermark incremental load (source: timestamptz, NOT NULL)'),

  -- ---- Bronze metadata (ingestion lineage) ----
  _ingested_at        TIMESTAMP DEFAULT CURRENT_TIMESTAMP() OPTIONS(description = 'Thời điểm nạp vào Bronze'),
  _source_system      STRING    OPTIONS(description = "Hệ thống nguồn, vd: 'core_banking_postgres'"),
  _ingestion_batch_id STRING    OPTIONS(description = 'Batch/job id của lần ingest')
)
PARTITION BY DATE(_ingested_at)
CLUSTER BY account_id
OPTIONS (
  description = 'Bronze - raw copy của bảng core_banking.public.cards'
);
