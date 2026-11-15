output "instance_id" {
  value = aws_instance.app.id
}

output "records_bucket" {
  value = aws_s3_bucket.records.bucket
}

output "region" {
  value = var.region
}
