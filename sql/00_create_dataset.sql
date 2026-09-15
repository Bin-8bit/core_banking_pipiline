CREATE SCHEMA IF NOT EXISTS `{{PROJECT_ID}}.bronze_core_banking`
OPTIONS (
  location    = '{{LOCATION}}',
  description = 'Bronze layer cho core_banking source system (Postgres). Các bảng giữ nguyên cấu trúc so với source, chỉ bổ sung cột metadata phục vụ lineage (_ingested_at, _source_system, _ingestion_batch_id).'
);
