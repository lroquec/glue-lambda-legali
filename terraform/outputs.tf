output "s3_bucket_name" {
  value = aws_s3_bucket.legal_files.bucket
}

output "glue_job_name" {
  value = aws_glue_job.process_logs.name
}

output "glue_database_name" {
  value = aws_glue_catalog_database.connection_tracking.name
}