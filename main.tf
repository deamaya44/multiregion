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

# Security Groups for EC2 instances (Region 1)
module "security_groups_ec2" {
  source   = "git::ssh://git@github.com/deamaya44/aws_modules.git//modules/security_groups?ref=main"
  for_each = local.security_groups_ec2

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

  depends_on = [module.vpc, module.security_groups_ec2]
}
# Security Groups for EC2 instances (Region 2)
module "security_groups_ec2_2" {
  providers = {
    aws = aws.multi
  }
  source   = "git::ssh://git@github.com/deamaya44/aws_modules.git//modules/security_groups?ref=main"
  for_each = local.security_groups_ec2_2

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

  depends_on = [module.vpc2, module.security_groups_ec2_2]
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
  description            = each.value.description
  assume_role_policy     = each.value.assume_role_policy
  create_instance_profile = each.value.create_instance_profile

  # Policies
  custom_policy_arns = each.value.custom_policy_arns
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
  kms_key_id       = lookup(each.value, "kms_key_id", null)
  
  # Subnet Group Configuration (choose one option)
  create_subnet_group        = lookup(each.value, "create_subnet_group", false)
  subnet_group_name          = lookup(each.value, "subnet_group_name", null)
  subnet_ids                 = lookup(each.value, "subnet_ids", [])
  existing_subnet_group_name = lookup(each.value, "existing_subnet_group_name", null)

  # Common Tags
  common_tags = each.value.tags
  depends_on  = [module.vpc2, module.security_groups_rds_2]
}

# EC2 Instances - Primary Region (us-east-1)
module "ec2" {
  source   = "git::ssh://git@github.com/deamaya44/aws_modules.git//modules/ec2?ref=main"
  for_each = local.ec2_instances

  # Basic Configuration
  instance_name = each.key
  instance_type = each.value.instance_type

  # Network Configuration
  subnet_id                    = each.value.subnet_id
  vpc_security_group_ids      = each.value.vpc_security_group_ids
  associate_public_ip_address = each.value.associate_public_ip_address

  # SSH Access
  create_key_pair = each.value.create_key_pair
  key_name       = each.value.key_name
  public_key     = each.value.public_key

  # Storage Configuration
  root_volume_size      = each.value.root_volume_size
  root_volume_type     = each.value.root_volume_type
  root_volume_encrypted = each.value.root_volume_encrypted

  # User Data
  user_data = each.value.user_data

  # IAM Instance Profile
  iam_instance_profile = each.value.iam_instance_profile

  # Common Tags
  common_tags = each.value.tags

  depends_on = [module.vpc, module.security_groups_ec2, module.iam_roles]
}

# EC2 Instances - Secondary Region (us-west-2)
module "ec2_secondary" {
  providers = {
    aws = aws.multi
  }
  source   = "git::ssh://git@github.com/deamaya44/aws_modules.git//modules/ec2?ref=main"
  for_each = local.ec2_instances_2

  # Basic Configuration
  instance_name = each.key
  instance_type = each.value.instance_type

  # Network Configuration
  subnet_id                    = each.value.subnet_id
  vpc_security_group_ids      = each.value.vpc_security_group_ids
  associate_public_ip_address = each.value.associate_public_ip_address

  # SSH Access
  create_key_pair = each.value.create_key_pair
  key_name       = each.value.key_name
  public_key     = each.value.public_key

  # Storage Configuration
  root_volume_size      = each.value.root_volume_size
  root_volume_type     = each.value.root_volume_type
  root_volume_encrypted = each.value.root_volume_encrypted

  # User Data
  user_data = each.value.user_data

  # IAM Instance Profile
  iam_instance_profile = each.value.iam_instance_profile

  # Common Tags
  common_tags = each.value.tags

  depends_on = [module.vpc2, module.security_groups_ec2_2, module.iam_roles]
}

module "s3" {
  source   = "git::ssh://git@github.com/deamaya44/aws_modules.git//modules/s3?ref=main"
  for_each = local.s3_buckets

  name                = each.key
  versioning          = each.value.versioning
  block_public_access = each.value.block_public_access
  policy              = try(each.value.policy, null)
  tags                = each.value.tags
}
module "s3_2" {
  source   = "git::ssh://git@github.com/deamaya44/aws_modules.git//modules/s3?ref=main"
  for_each = local.s3_buckets2
  providers = {
    aws = aws.multi
  }
  name                = each.key
  versioning          = each.value.versioning
  block_public_access = each.value.block_public_access
  policy              = try(each.value.policy, null)
  tags                = each.value.tags
}