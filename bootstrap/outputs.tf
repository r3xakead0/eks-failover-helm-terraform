output "bucket" { value = aws_s3_bucket.tf_state.bucket }
output "table" { value = aws_dynamodb_table.tf_lock.name }