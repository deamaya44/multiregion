locals {

  account_id_map = {
    dev  = "356491328040"
    qa   = "" #Pending
    uat  = "" #Pending
    prod = "356491328040"
  }

  environmentMap = {
    dev  = "dev"
    qa   = "qa"
    prod = "prod"
  }

  environment = local.environmentMap[terraform.workspace]
  account_id  = local.account_id_map[terraform.workspace]

  common_tags = {
    Environment = local.environment
    Project     = "multicloud"
    Terraform   = "true"
    Owner       = "deamaya44"
  }

  region_values_maps = {
    us_east_1 = {
      vpc_cidr = "192.168.0"
    }
    us_west_2 = {
      vpc_cidr = "192.168.1"
    }
  }
  #   multiregion_enabled = true

  vpc = {
    # VPC Configuration
    "multiregion-${local.environment}-vpc" = {
      vpc_cidr             = "${local.region_values_maps["us_east_1"].vpc_cidr}.0/24"
      enable_dns_hostnames = true
      enable_dns_support   = true

      # Internet Gateway
      create_igw = true

      # Subnets
      public_subnet_cidrs     = ["${local.region_values_maps["us_east_1"].vpc_cidr}.0/26"] #It's mandatory for use NAT Gateway.
      private_subnet_cidrs    = ["${local.region_values_maps["us_east_1"].vpc_cidr}.64/26", "${local.region_values_maps["us_east_1"].vpc_cidr}.128/26"]
      availability_zones      = ["us-east-1a", "us-east-1b"]
      map_public_ip_on_launch = true

      # NAT Gateway
      create_nat_gateway              = true
      create_s3_endpoint              = false
      create_sts_endpoint             = false
      create_kinesis_endpoint         = false
      vpc_endpoint_security_group_ids = [] # Add security group IDs if needed

      # Common Tags
      tags = local.common_tags

    }
  }
  vpc2 = {
    # VPC Configuration
    "multiregion-${local.environment}-vpc" = {
      vpc_cidr             = "${local.region_values_maps["us_west_2"].vpc_cidr}.0/24"
      enable_dns_hostnames = true
      enable_dns_support   = true

      # Internet Gateway
      create_igw = true

      # Subnets
      public_subnet_cidrs     = ["${local.region_values_maps["us_west_2"].vpc_cidr}.0/26"] #It's mandatory for use NAT Gateway.
      private_subnet_cidrs    = ["${local.region_values_maps["us_west_2"].vpc_cidr}.64/26", "${local.region_values_maps["us_west_2"].vpc_cidr}.128/26"]
      availability_zones      = ["us-west-2a", "us-west-2b"]
      map_public_ip_on_launch = true

      # NAT Gateway
      create_nat_gateway              = true
      create_s3_endpoint              = false
      create_sts_endpoint             = false
      create_kinesis_endpoint         = false
      vpc_endpoint_security_group_ids = [] # Add security group IDs if needed

      # Common Tags
      tags = local.common_tags

    }
  }
  security_groups = {
    "multiregion-${local.environment}-rds-sg" = {
      name        = "multiregion-${local.environment}-rds-sg"
      description = "Security group for RDS instance in ${local.environment} environment"
      vpc_id      = module.vpc["multiregion-${local.environment}-vpc"].vpc_id

      ingress_rules = [
        {
          from_port   = 5432
          to_port     = 5432
          protocol    = "tcp"
          cidr_blocks = ["0.0.0.0/0"]
        }
      ]

      egress_rules = [
        {
          from_port   = 0
          to_port     = 0
          protocol    = "-1"
          cidr_blocks = ["0.0.0.0/0"]
        }
      ]

      tags = local.common_tags
    }
    "multiregion-${local.environment}-ec2-sg" = {
      name        = "multiregion-${local.environment}-ec2-sg"
      description = "Security group for EC2 SSH access in ${local.environment} environment"
      vpc_id      = module.vpc["multiregion-${local.environment}-vpc"].vpc_id

      ingress_rules = [
        {
          from_port   = 22
          to_port     = 22
          protocol    = "tcp"
          cidr_blocks = ["0.0.0.0/0"]
        }
      ]

      egress_rules = [
        {
          from_port   = 0
          to_port     = 0
          protocol    = "-1"
          cidr_blocks = ["0.0.0.0/0"]
        }
      ]

      tags = local.common_tags
    }
  }
  security_groups_2 = {
    "multiregion-${local.environment}-rds-sg2" = {
      name        = "multiregion-${local.environment}-rds-sg2"
      description = "Security group for RDS instance in ${local.environment} environment"
      vpc_id      = module.vpc2["multiregion-${local.environment}-vpc"].vpc_id

      ingress_rules = [
        {
          from_port   = 5432
          to_port     = 5432
          protocol    = "tcp"
          cidr_blocks = ["0.0.0.0/0"]
        }
      ]

      egress_rules = [
        {
          from_port   = 0
          to_port     = 0
          protocol    = "-1"
          cidr_blocks = ["0.0.0.0/0"]
        }
      ]

      tags = local.common_tags
    }
  }
  secrets = {
    "rds_admin_password" = {
      secret_name              = "rds_admin_password_${local.environment}"
      description              = "RDS Admin Password for ${local.environment} environment"
      generate_random_password = true
      password_length          = 16
      tags                     = local.common_tags
    }
  }
  rds_instances = {
    "multiregion-${local.environment}-rds" = {
      identifier             = "multiregion-${local.environment}-rds"
      engine                 = "postgres"
      engine_version         = "18"
      instance_class         = "db.t3.micro"
      allocated_storage      = 20
      storage_encrypted      = true  # Explicit encryption
      username               = "postgres_admin"
      password               = module.secrets_manager["rds_admin_password"].secret_arn
      port                   = 5432
      vpc_security_group_ids = [module.security_groups["multiregion-${local.environment}-rds-sg"].security_group_id] # Add security group IDs if needed
      subnet_ids             = module.vpc["multiregion-${local.environment}-vpc"].private_subnet_ids
      publicly_accessible    = false
      tags                   = local.common_tags
    }
  }
  rds_read_replicas = {
    "multiregion-${local.environment}-rds-replica" = {
      identifier             = "multiregion-${local.environment}-rds-replica"
      source_db_identifier   = module.rds["multiregion-${local.environment}-rds"].db_instance_arn
      instance_class         = "db.t3.micro"
      vpc_security_group_ids = [module.security_groups_2["multiregion-${local.environment}-rds-sg2"].security_group_id]
      publicly_accessible    = false
      subnet_ids             = module.vpc2["multiregion-${local.environment}-vpc"].private_subnet_ids
      create_subnet_group    = true
      subnet_group_name      = "multiregion-${local.environment}-rds-replica-subnet-group"
      
      # Storage Configuration - REQUIRED for cross-region encrypted replicas
      storage_encrypted      = true
      
      tags = local.common_tags
    }
  }
}