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

module "security_groups" {
  source   = "git::ssh://git@github.com/deamaya44/aws_modules.git//modules/security_groups?ref=main"
  for_each = local.security_groups

  # Security Group Configuration
  name        = each.value.name
  description = each.value.description
  vpc_id      = each.value.vpc_id

  # Rules Configuration
  ingress_rules = each.value.ingress_rules
  egress_rules  = each.value.egress_rules

  # Common Tags
  common_tags = each.value.tags

  depends_on = [module.vpc, module.vpc2]
}
module "security_groups_2" {
  providers = {
    aws = aws.multi
  }
  source   = "git::ssh://git@github.com/deamaya44/aws_modules.git//modules/security_groups?ref=main"
  for_each = local.security_groups_2

  # Security Group Configuration
  name        = each.value.name
  description = each.value.description
  vpc_id      = each.value.vpc_id

  # Rules Configuration
  ingress_rules = each.value.ingress_rules
  egress_rules  = each.value.egress_rules

  # Common Tags
  common_tags = each.value.tags

  depends_on = [module.vpc, module.vpc2]
}

module "secrets_manager" {
  source   = "git::ssh://git@github.com/deamaya44/aws_modules.git//modules/secrets_manager?ref=main"
  for_each = local.secrets

  # Basic Configuration
  secret_name = each.value.secret_name
  description = each.value.description

  # Secret Content (choose one option)
  secret_string    = lookup(each.value, "secret_string", null)
  secret_key_value = lookup(each.value, "secret_key_value", null)

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
  identifier     = each.value.identifier
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

  depends_on = [module.vpc, module.security_groups, module.secrets_manager]
}
module "rds_read_replica" {
  providers = {
    aws = aws.multi
  }
  source   = "git::ssh://git@github.com/deamaya44/aws_modules.git//modules/rds_read_replica?ref=main"
  for_each = local.rds_read_replicas

  # Basic Configuration
  identifier           = each.value.identifier
  source_db_identifier = each.value.source_db_identifier
  instance_class       = each.value.instance_class

  # Network & Security
  vpc_security_group_ids = each.value.vpc_security_group_ids
  publicly_accessible    = lookup(each.value, "publicly_accessible", false)
  
  # Storage Configuration
  storage_encrypted = lookup(each.value, "storage_encrypted", true)
  
  # Subnet Group Configuration (choose one option)
  create_subnet_group        = lookup(each.value, "create_subnet_group", false)
  subnet_group_name          = lookup(each.value, "subnet_group_name", null)
  subnet_ids                 = lookup(each.value, "subnet_ids", [])
  existing_subnet_group_name = lookup(each.value, "existing_subnet_group_name", null)

  # Common Tags
  common_tags = each.value.tags
  depends_on  = [module.vpc2, module.security_groups_2]
}