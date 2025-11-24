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
    region1 = {
      region = "us-east-1"
      vpc_cidr = "192.168.0"
    }
    region2 = {
      region = "us-west-2"
      vpc_cidr = "192.168.1"
    }
  }
  #   multiregion_enabled = true

  region1 = local.region_values_maps["region1"]
  region2 = local.region_values_maps["region2"]
  vpc = {
    # VPC Configuration
    "multiregion-${local.environment}-vpc" = {
      vpc_cidr             = "${local.region1.vpc_cidr}.0/24"
      enable_dns_hostnames = true
      enable_dns_support   = true

      # Internet Gateway
      create_igw = true

      # Subnets
      public_subnet_cidrs     = ["${local.region1.vpc_cidr}.0/26"] #It's mandatory for use NAT Gateway.
      private_subnet_cidrs    = ["${local.region1.vpc_cidr}.64/26", "${local.region1.vpc_cidr}.128/26"]
      availability_zones      = ["${local.region1.region}a", "${local.region1.region}b"]
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
      vpc_cidr             = "${local.region2.vpc_cidr}.0/24"
      enable_dns_hostnames = true
      enable_dns_support   = true

      # Internet Gateway
      create_igw = true

      # Subnets
      public_subnet_cidrs     = ["${local.region2.vpc_cidr}.0/26"] #It's mandatory for use NAT Gateway.
      private_subnet_cidrs    = ["${local.region2.vpc_cidr}.64/26", "${local.region2.vpc_cidr}.128/26"]
      availability_zones      = ["${local.region2.region}a", "${local.region2.region}b"]
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
      description = "Security group for EC2 instances with SSH and database access in ${local.environment} environment"
      vpc_id      = module.vpc["multiregion-${local.environment}-vpc"].vpc_id

      ingress_rules = [
        {
          from_port   = 22
          to_port     = 22
          protocol    = "tcp"
          cidr_blocks = ["0.0.0.0/0"]  # Consider restricting to your IP
        },
        {
          from_port   = 80
          to_port     = 80
          protocol    = "tcp"
          cidr_blocks = ["0.0.0.0/0"]
        },
        {
          from_port   = 443
          to_port     = 443
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
    },
    "multiregion-${local.environment}-ec2-sg2" = {
      name        = "multiregion-${local.environment}-ec2-sg2"
      description = "Security group for EC2 instances with SSH and database access in ${local.environment} environment (us-west-2)"
      vpc_id      = module.vpc2["multiregion-${local.environment}-vpc"].vpc_id

      ingress_rules = [
        {
          from_port   = 22
          to_port     = 22
          protocol    = "tcp"
          cidr_blocks = ["0.0.0.0/0"]  # Consider restricting to your IP
        },
        {
          from_port   = 80
          to_port     = 80
          protocol    = "tcp"
          cidr_blocks = ["0.0.0.0/0"]
        },
        {
          from_port   = 443
          to_port     = 443
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
  
  # IAM Policies Configuration
  iam_policies = {
    "ec2-secrets-manager-policy-${local.environment}" = {
      policy_name = "ec2-secrets-manager-policy-${local.environment}"
      description = "Policy to allow EC2 instances to read RDS credentials from Secrets Manager"
      policy_document = file("${path.root}/policies/ec2-secrets-manager-policy.json")
      tags = local.common_tags
    }
  }
  
  # IAM Roles Configuration
  iam_roles = {
    "ec2-secrets-role-${local.environment}" = {
      role_name = "ec2-secrets-manager-role-${local.environment}"
      description = "Role for EC2 instances to access Secrets Manager for RDS credentials"
      assume_role_policy = file("${path.root}/policies/ec2-assume-role-policy.json")
      create_instance_profile = true
      custom_policy_arns = [module.iam_policies["ec2-secrets-manager-policy-${local.environment}"].policy_arn]
      tags = local.common_tags
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
      kms_key_id            = data.aws_kms_key.rds_primary.arn
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
      kms_key_id            = data.aws_kms_key.rds_replica.arn  # AWS managed key in target region
      
      tags = local.common_tags
    }
  }
  
  # EC2 Instances Configuration
  ec2_instances = {
    # Primary region EC2 instance (us-east-1)
    "multiregion-${local.environment}-ec2-primary" = {
      instance_name = "multiregion-${local.environment}-ec2-primary"
      instance_type = "t3.micro"
      
      # Network Configuration
      subnet_id                    = module.vpc["multiregion-${local.environment}-vpc"].private_subnet_ids[0]
      vpc_security_group_ids      = [module.security_groups["multiregion-${local.environment}-ec2-sg"].security_group_id]
      associate_public_ip_address = false
      
      # SSH Access using templatefile
      create_key_pair = true
      key_name       = "multiregion-${local.environment}-primary-key"
      public_key     = file("${path.root}/templates/demo-ssh-key.pub")
      
      # IAM Instance Profile for Secrets Manager access
      iam_instance_profile = module.iam_roles["ec2-secrets-role-${local.environment}"].instance_profile_name
      
      # Storage Configuration
      root_volume_size      = 10
      root_volume_type     = "gp3"
      root_volume_encrypted = true
      
      # User Data for database client setup
      user_data = base64encode(templatefile("${path.root}/scripts/db-client-setup.sh", {
        db_endpoint = module.rds["multiregion-${local.environment}-rds"].db_instance_endpoint
        db_name     = "postgres"
        db_port     = "5432"
        region      = "us-east-1"
        secret_arn  = module.secrets_manager["rds_admin_password"].secret_arn
      }))
      
      tags = merge(local.common_tags, {
        Region = "primary"
        Role   = "database-client"
      })
    }
  }
  
  # EC2 Instances for secondary region (us-west-2)
  ec2_instances_2 = {
    "multiregion-${local.environment}-ec2-secondary" = {
      instance_name = "multiregion-${local.environment}-ec2-secondary"
      instance_type = "t3.micro"
      
      # Network Configuration
      subnet_id                    = module.vpc2["multiregion-${local.environment}-vpc"].private_subnet_ids[0]
      vpc_security_group_ids      = [module.security_groups_2["multiregion-${local.environment}-ec2-sg2"].security_group_id]
      associate_public_ip_address = false
      
      # SSH Access using templatefile
      create_key_pair = true
      key_name       = "multiregion-${local.environment}-secondary-key"
      public_key     = file("${path.root}/templates/demo-ssh-key.pub")
      
      # IAM Instance Profile for Secrets Manager access
      iam_instance_profile = module.iam_roles["ec2-secrets-role-${local.environment}"].instance_profile_name
      
      # Storage Configuration
      root_volume_size      = 10
      root_volume_type     = "gp3"
      root_volume_encrypted = true
      
      # User Data for database client setup (connecting to read replica)
      user_data = base64encode(templatefile("${path.root}/scripts/db-client-setup.sh", {
        db_endpoint = module.rds_read_replica["multiregion-${local.environment}-rds-replica"].read_replica_endpoint
        db_name     = "postgres"
        db_port     = "5432"
        region      = "us-west-2"
        secret_arn  = module.secrets_manager["rds_admin_password"].secret_arn
      }))
      
      tags = merge(local.common_tags, {
        Region = "secondary"
        Role   = "database-client"
      })
    }
  }
}