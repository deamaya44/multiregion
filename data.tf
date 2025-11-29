# KMS Key for RDS in us-east-1 (primary region)
data "aws_kms_key" "rds_primary" {
  key_id = "alias/aws/rds"
}

# KMS Key for RDS in us-west-2 (replica region)
data "aws_kms_key" "rds_replica" {
  provider = aws.multi
  key_id   = "alias/aws/rds"
}
# KMS Key for Secrets Manager in us-east-1 (primary region)
data "aws_kms_key" "secrets_primary" {
  key_id = "alias/aws/secretsmanager"
}

# KMS Key for Secrets Manager in us-west-2 (replica region)
data "aws_kms_key" "secrets_replica" {
  provider = aws.multi
  key_id   = "alias/aws/secretsmanager"
}