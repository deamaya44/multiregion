module "vpc" {
  source   = "git::ssh://git@github.com/deamaya44/aws_modules.git//modules/vpc?ref=main"
  for_each = local.vpc
  # VPC Configuration
  vpc_name             = each.key
  vpc_cidr             = each.value.vpc_cidr
  enable_dns_hostnames = each.value.enable_dns_hostnames
  enable_dns_support   = each.value.enable_dns_support

  # Internet Gateway
  create_igw = each.value.create_igw

  # Subnets
  public_subnet_cidrs     = try(each.value.public_subnet_cidrs, null)
  private_subnet_cidrs    = each.value.private_subnet_cidrs
  availability_zones      = each.value.availability_zones
  map_public_ip_on_launch = each.value.map_public_ip_on_launch

  # NAT Gateway
  create_nat_gateway              = each.value.create_nat_gateway
  create_s3_endpoint              = each.value.create_s3_endpoint
  create_sts_endpoint             = each.value.create_sts_endpoint
  create_kinesis_endpoint         = each.value.create_kinesis_endpoint
  vpc_endpoint_security_group_ids = each.value.vpc_endpoint_security_group_ids

  # Common Tags
  common_tags = each.value.tags
}
module "vpc2" {
  providers = {
    aws = aws.multi
  }
  source   = "git::ssh://git@github.com/deamaya44/aws_modules.git//modules/vpc?ref=main"
  for_each = local.vpc2
  # VPC Configuration
  vpc_name             = each.key
  vpc_cidr             = each.value.vpc_cidr
  enable_dns_hostnames = each.value.enable_dns_hostnames
  enable_dns_support   = each.value.enable_dns_support

  # Internet Gateway
  create_igw = each.value.create_igw

  # Subnets
  public_subnet_cidrs     = try(each.value.public_subnet_cidrs, null)
  private_subnet_cidrs    = each.value.private_subnet_cidrs
  availability_zones      = each.value.availability_zones
  map_public_ip_on_launch = each.value.map_public_ip_on_launch

  # NAT Gateway
  create_nat_gateway              = each.value.create_nat_gateway
  create_s3_endpoint              = each.value.create_s3_endpoint
  create_sts_endpoint             = each.value.create_sts_endpoint
  create_kinesis_endpoint         = each.value.create_kinesis_endpoint
  vpc_endpoint_security_group_ids = each.value.vpc_endpoint_security_group_ids

  # Common Tags
  common_tags = each.value.tags
}

# Security Groups for RDS (Region 1)
module "security_groups_rds" {
  source   = "git::ssh://git@github.com/deamaya44/aws_modules.git//modules/security_groups?ref=main"
  for_each = local.security_groups_rds

  # Security Group Configuration
  name        = each.key
  description = each.value.description
  vpc_id      = each.value.vpc_id

  # Rules Configuration
  ingress_rules = each.value.ingress_rules
  egress_rules  = each.value.egress_rules

  # Common Tags
  common_tags = each.value.tags

  depends_on = [module.vpc]
}

# Security Groups for RDS (Region 2)
module "security_groups_rds_2" {
  providers = {
    aws = aws.multi
  }
  source   = "git::ssh://git@github.com/deamaya44/aws_modules.git//modules/security_groups?ref=main"
  for_each = local.security_groups_rds_2

  # Security Group Configuration
  name        = each.key
  description = each.value.description
  vpc_id      = each.value.vpc_id

  # Rules Configuration
  ingress_rules = each.value.ingress_rules
  egress_rules  = each.value.egress_rules

  # Common Tags
  common_tags = each.value.tags

  depends_on = [module.vpc2]
}

module "secrets_manager" {
  source   = "git::ssh://git@github.com/deamaya44/aws_modules.git//modules/secrets_manager?ref=main"
  for_each = local.secrets

  # Basic Configuration
  secret_name = each.key
  description = each.value.description

  # Secret Content (choose one option)
  secret_string    = lookup(each.value, "secret_string", null)
  secret_key_value = lookup(each.value, "secret_key_value", null)
  replica_regions  = lookup(each.value, "replica_regions", [])

  # Random Password Generation (optional)
  generate_random_password = lookup(each.value, "generate_random_password", false)
  password_length          = lookup(each.value, "password_length", 32)

  # Security
  kms_key_id = lookup(each.value, "kms_key_id", null)

  # Common Tags
  common_tags = each.value.tags
}

module "rds" {
  source   = "git::ssh://git@github.com/deamaya44/aws_modules.git//modules/rds?ref=main"
  for_each = local.rds_instances

  # Basic Configuration
  identifier     = each.key
  engine         = each.value.engine
  engine_version = each.value.engine_version
  instance_class = each.value.instance_class

  # Database Configuration
  db_name  = lookup(each.value, "db_name", null)
  username = each.value.username
  password = each.value.password

  # Storage Configuration
  allocated_storage = each.value.allocated_storage
  storage_encrypted = lookup(each.value, "storage_encrypted", true)

  # Network & Security
  subnet_ids             = each.value.subnet_ids
  vpc_security_group_ids = each.value.vpc_security_group_ids

  # Backup & Maintenance
  backup_retention_period = lookup(each.value, "backup_retention_period", 7)
  skip_final_snapshot     = lookup(each.value, "skip_final_snapshot", false)

  # High Availability
  multi_az = lookup(each.value, "multi_az", false)

  # Common Tags
  common_tags = each.value.tags

  depends_on = [module.vpc, module.secrets_manager]
}

# IAM Policies Module
module "iam_policies" {
  source   = "git::ssh://git@github.com/deamaya44/aws_modules.git//modules/iam/policies?ref=main"
  for_each = local.iam_policies

  # Policy Configuration
  policy_name     = each.key
  description     = each.value.description
  policy_document = each.value.policy_document

  # Common Tags
  common_tags = each.value.tags

  depends_on = [module.secrets_manager]
}

# IAM Roles Module
module "iam_roles" {
  source   = "git::ssh://git@github.com/deamaya44/aws_modules.git//modules/iam/roles?ref=main"
  for_each = local.iam_roles

  # Role Configuration
  role_name               = each.key
  description             = each.value.description
  assume_role_policy      = each.value.assume_role_policy
  create_instance_profile = each.value.create_instance_profile

  # Policies
  custom_policy_arns      = each.value.custom_policy_arns
  aws_managed_policy_arns = lookup(each.value, "aws_managed_policy_arns", [])

  # Common Tags
  common_tags = each.value.tags

  depends_on = [module.iam_policies]
}

module "rds_read_replica" {
  providers = {
    aws = aws.multi
  }
  source   = "git::ssh://git@github.com/deamaya44/aws_modules.git//modules/rds_read_replica?ref=main"
  for_each = local.rds_read_replicas

  # Basic Configuration
  identifier           = each.key
  source_db_identifier = each.value.source_db_identifier
  instance_class       = each.value.instance_class

  # Network & Security
  vpc_security_group_ids = each.value.vpc_security_group_ids
  publicly_accessible    = lookup(each.value, "publicly_accessible", false)

  # Storage Configuration
  storage_encrypted = lookup(each.value, "storage_encrypted", true)
  kms_key_id        = lookup(each.value, "kms_key_id", null)

  # Subnet Group Configuration (choose one option)
  create_subnet_group        = lookup(each.value, "create_subnet_group", false)
  subnet_group_name          = lookup(each.value, "subnet_group_name", null)
  subnet_ids                 = lookup(each.value, "subnet_ids", [])
  existing_subnet_group_name = lookup(each.value, "existing_subnet_group_name", null)

  # Common Tags
  common_tags = each.value.tags
  depends_on  = [module.vpc2, module.security_groups_rds_2]
}

module "s3" {
  source   = "git::ssh://git@github.com/deamaya44/aws_modules.git//modules/s3/bucket?ref=main"
  for_each = local.s3_buckets

  name                   = each.key
  versioning             = each.value.versioning
  acl_enabled            = try(each.value.acl_enabled, false)
  acl                    = try(each.value.acl, "private")
  replication_enabled    = try(each.value.replication_enabled, false)
  role_arn               = try(each.value.role_arn, null)
  bucket_id              = each.key
  destination_bucket_arn = try(each.value.destination_bucket_arn, null)
  storage_class          = try(each.value.storage_class, "STANDARD")
  block_public_access    = each.value.block_public_access
  # policy              = try(each.value.policy, null)
  tags = each.value.tags
}
module "s3_2" {
  source   = "git::ssh://git@github.com/deamaya44/aws_modules.git//modules/s3/bucket?ref=main"
  for_each = local.s3_buckets2
  providers = {
    aws = aws.multi
  }
  name       = each.key
  versioning = each.value.versioning
  # replication_enabled    = try(each.value.replication_enabled, false)
  # role_arn               = try(each.value.replication_enabled, false) ? module.iam_roles["s3-crr-role-${local.environment}"].role_arn : null
  # bucket_id              = each.key
  # destination_bucket_arn = try(each.value.destination_bucket_arn, null)
  # storage_class          = try(each.value.storage_class, "STANDARD")
  block_public_access = each.value.block_public_access
  # policy                 = try(each.value.policy, null)
  tags = each.value.tags

  depends_on = [module.iam_roles]
}
# S3 bucket for Frontend
# Security Groups for Lambda (Region 1)
module "security_groups_lambda" {
  source   = "git::ssh://git@github.com/deamaya44/aws_modules.git//modules/security_groups?ref=main"
  for_each = local.security_groups_lambda

  name        = each.key
  description = each.value.description
  vpc_id      = each.value.vpc_id

  ingress_rules = each.value.ingress_rules
  egress_rules  = each.value.egress_rules

  common_tags = each.value.tags

  depends_on = [module.vpc]
}

# Security Groups for Lambda (Region 2)
module "security_groups_lambda_2" {
  providers = {
    aws = aws.multi
  }
  source   = "git::ssh://git@github.com/deamaya44/aws_modules.git//modules/security_groups?ref=main"
  for_each = local.security_groups_lambda_2

  name        = each.key
  description = each.value.description
  vpc_id      = each.value.vpc_id

  ingress_rules = each.value.ingress_rules
  egress_rules  = each.value.egress_rules

  common_tags = each.value.tags

  depends_on = [module.vpc2]
}

# Lambda Functions (Region 1)
module "lambda" {
  source   = "git::ssh://git@github.com/deamaya44/aws_modules.git//modules/lambda?ref=main"
  for_each = local.lambda_functions

  function_name = each.value.function_name
  role_arn      = each.value.role_arn
  handler       = each.value.handler
  runtime       = each.value.runtime
  timeout       = each.value.timeout
  memory_size   = each.value.memory_size

  filename = each.value.filename

  environment_variables = each.value.environment_variables

  subnet_ids         = each.value.subnet_ids
  security_group_ids = each.value.security_group_ids

  create_function_url    = each.value.create_function_url
  function_url_auth_type = each.value.function_url_auth_type
  function_url_cors      = each.value.function_url_cors

  create_log_group   = each.value.create_log_group
  log_retention_days = each.value.log_retention_days

  common_tags = each.value.tags

  depends_on = [
    module.vpc,
    module.security_groups_lambda,
    module.iam_roles,
    module.rds
  ]
}

# Lambda Functions (Region 2)
module "lambda_2" {
  providers = {
    aws = aws.multi
  }
  source   = "git::ssh://git@github.com/deamaya44/aws_modules.git//modules/lambda?ref=main"
  for_each = local.lambda_functions_2

  function_name = each.value.function_name
  role_arn      = each.value.role_arn
  handler       = each.value.handler
  runtime       = each.value.runtime
  timeout       = each.value.timeout
  memory_size   = each.value.memory_size

  filename = each.value.filename

  environment_variables = each.value.environment_variables

  subnet_ids         = each.value.subnet_ids
  security_group_ids = each.value.security_group_ids

  create_function_url    = each.value.create_function_url
  function_url_auth_type = each.value.function_url_auth_type
  function_url_cors      = each.value.function_url_cors

  create_log_group   = each.value.create_log_group
  log_retention_days = each.value.log_retention_days

  common_tags = each.value.tags

  depends_on = [
    module.vpc2,
    module.security_groups_lambda_2,
    module.iam_roles,
    module.rds_read_replica
  ]
}

# CloudFront Distribution
module "cloudfront" {
  source   = "git::ssh://git@github.com/deamaya44/aws_modules.git//modules/cloudfront?ref=main"
  for_each = local.cloudfront_distributions

  comment             = each.value.comment
  default_root_object = each.value.default_root_object
  price_class         = each.value.price_class
  enabled             = each.value.enabled
  is_ipv6_enabled     = each.value.is_ipv6_enabled

  origins = each.value.origins

  default_cache_behavior = each.value.default_cache_behavior

  custom_error_responses = each.value.custom_error_responses

  common_tags = each.value.tags

  depends_on = [module.s3, module.s3_2]
}

# S3 Bucket Policies for CloudFront OAI
resource "aws_s3_bucket_policy" "cloudfront_primary" {
  bucket = "multiregion-${local.account_id}-${local.region1["region"]}-${local.environment}-data"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowCloudFrontOAI"
        Effect = "Allow"
        Principal = {
          AWS = module.cloudfront["multiregion-${local.environment}-frontend"].oai_iam_arn
        }
        Action   = "s3:GetObject"
        Resource = "arn:aws:s3:::multiregion-${local.account_id}-${local.region1["region"]}-${local.environment}-data/*"
      }
    ]
  })

  depends_on = [module.cloudfront, module.s3]
}

resource "aws_s3_bucket_policy" "cloudfront_secondary" {
  provider = aws.multi
  bucket   = "multiregion-${local.account_id}-${local.region2["region"]}-${local.environment}-data"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowCloudFrontOAI"
        Effect = "Allow"
        Principal = {
          AWS = module.cloudfront["multiregion-${local.environment}-frontend"].oai_iam_arn
        }
        Action   = "s3:GetObject"
        Resource = "arn:aws:s3:::multiregion-${local.account_id}-${local.region2["region"]}-${local.environment}-data/*"
      }
    ]
  })

  depends_on = [module.cloudfront, module.s3_2]
}
