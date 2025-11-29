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

  # Security Groups for RDS (Region 1) - Allow access from private subnets
  security_groups_rds = {
    "multiregion-${local.environment}-rds-sg" = {
      description = "Security group for RDS instance - access from private subnets"
      vpc_id      = module.vpc["multiregion-${local.environment}-vpc"].vpc_id

      ingress_rules = [
        {
          from_port   = 5432
          to_port     = 5432
          protocol    = "tcp"
          cidr_blocks = ["${local.region1.vpc_cidr}.0/24"]
        }
      ]

      egress_rules = []

      tags = local.common_tags
    }
  }

  # Security Groups for RDS (Region 2) - Allow access from private subnets  
  security_groups_rds_2 = {
    "multiregion-${local.environment}-rds-sg2" = {
      description = "Security group for RDS replica - access from private subnets"
      vpc_id      = module.vpc2["multiregion-${local.environment}-vpc"].vpc_id

      ingress_rules = [
        {
          from_port   = 5432
          to_port     = 5432
          protocol    = "tcp"
          cidr_blocks = ["${local.region2.vpc_cidr}.0/24"]
        }
      ]

      egress_rules = []

      tags = local.common_tags
    }
  }
  secrets = {
    "rds_admin_password_${local.environment}_2" = {
      description              = "RDS Admin Password for ${local.environment} environment"
      generate_random_password = true
      password_length          = 16
      tags                     = local.common_tags
    }
  }
  
  # IAM Policies Configuration
  iam_policies = {
    "s3-crr-policy-${local.environment}" = {
      description     = "Policy for S3 Cross-Region Replication"
      policy_document = file("${path.root}/policies/s3-crr-policy.json")
      tags            = local.common_tags
    }
    "lambda-execution-policy-${local.environment}" = {
      description = "Policy for Lambda execution"
      policy_document = templatefile("${path.root}/policies/lambda-execution-policy.json.tpl", {
        secret_arn = module.secrets_manager["rds_admin_password_${local.environment}_2"].secret_arn
      })
      tags = local.common_tags
    }
  }
  
  # IAM Roles Configuration
  iam_roles = {
    "s3-crr-role-${local.environment}" = {
      description             = "Role for S3 Cross-Region Replication"
      assume_role_policy      = file("${path.root}/policies/s3-crr-assume-role-policy.json")
      create_instance_profile = false
      custom_policy_arns      = [module.iam_policies["s3-crr-policy-${local.environment}"].policy_arn]
      aws_managed_policy_arns = []
      tags                    = local.common_tags
    }
    "lambda-execution-role-${local.environment}" = {
      description             = "Role for Lambda execution"
      assume_role_policy      = file("${path.root}/policies/lambda-assume-role-policy.json")
      create_instance_profile = false
      custom_policy_arns      = [module.iam_policies["lambda-execution-policy-${local.environment}"].policy_arn]
      aws_managed_policy_arns = [
        "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
      ]
      tags = local.common_tags
    }
  }
  rds_instances = {
    "multiregion-${local.environment}-rds" = {
      engine                 = "postgres"
      engine_version         = "18"
      instance_class         = "db.t3.micro"
      allocated_storage      = 20
      storage_encrypted      = true  # Explicit encryption
      kms_key_id            = data.aws_kms_key.rds_primary.arn
      username               = "postgres_admin"
      password               = module.secrets_manager["rds_admin_password_${local.environment}_2"].secret_arn
      port                   = 5432
      vpc_security_group_ids = [module.security_groups_rds["multiregion-${local.environment}-rds-sg"].security_group_id] # Add security group IDs if needed
      subnet_ids             = module.vpc["multiregion-${local.environment}-vpc"].private_subnet_ids
      publicly_accessible    = false
      tags                   = local.common_tags
    }
  }
  rds_read_replicas = {
    "multiregion-${local.environment}-rds-replica" = {
      source_db_identifier   = module.rds["multiregion-${local.environment}-rds"].db_instance_arn
      instance_class         = "db.t3.micro"
      vpc_security_group_ids = [module.security_groups_rds_2["multiregion-${local.environment}-rds-sg2"].security_group_id]
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

  s3_buckets = {
  "multiregion-${local.account_id}-${local.region1["region"]}-${local.environment}-data" = {
    tags                  = local.common_tags
    acl_enabled        = true
    acl                = "private"
    versioning            = true
    block_public_access   = true
    policy                = null
    replication_enabled    = true
    role_arn              = module.iam_roles["s3-crr-role-${local.environment}"].role_arn
    # bucket_id             = local.s3_buckets2[0]
    destination_bucket_arn = module.s3_2["multiregion-${local.account_id}-${local.region2["region"]}-${local.environment}-data"].bucket_arn
    storage_class         = "INTELLIGENT_TIERING"
  }
  }
  s3_buckets2 = {
  "multiregion-${local.account_id}-${local.region2["region"]}-${local.environment}-data" = {
    tags                   = local.common_tags
    versioning             = true
    block_public_access    = true
    policy                 = null

  }
  }

  # Security Groups for Lambda (Region 1)
  security_groups_lambda = {
    "multiregion-${local.environment}-lambda-sg" = {
      description = "Security group for Lambda function - access to RDS"
      vpc_id      = module.vpc["multiregion-${local.environment}-vpc"].vpc_id

      ingress_rules = []

      egress_rules = [
        {
          from_port   = 5432
          to_port     = 5432
          protocol    = "tcp"
          cidr_blocks = ["${local.region1.vpc_cidr}.0/24"]
        },
        {
          from_port   = 443
          to_port     = 443
          protocol    = "tcp"
          cidr_blocks = ["0.0.0.0/0"]
        }
      ]

      tags = local.common_tags
    }
  }

  # Security Groups for Lambda (Region 2)
  security_groups_lambda_2 = {
    "multiregion-${local.environment}-lambda-sg2" = {
      description = "Security group for Lambda function - access to RDS replica"
      vpc_id      = module.vpc2["multiregion-${local.environment}-vpc"].vpc_id

      ingress_rules = []

      egress_rules = [
        {
          from_port   = 5432
          to_port     = 5432
          protocol    = "tcp"
          cidr_blocks = ["${local.region2.vpc_cidr}.0/24"]
        },
        {
          from_port   = 443
          to_port     = 443
          protocol    = "tcp"
          cidr_blocks = ["0.0.0.0/0"]
        }
      ]

      tags = local.common_tags
    }
  }

  # Lambda Functions
  lambda_functions = {
    "multiregion-${local.environment}-api" = {
      function_name = "multiregion-${local.environment}-api"
      role_arn      = module.iam_roles["lambda-execution-role-${local.environment}"].role_arn
      handler       = "lambda_function.handler"
      runtime       = "python3.11"
      timeout       = 30
      memory_size   = 256
      filename      = "${path.root}/lambda_function.zip"

      environment_variables = {
        DB_HOST       = module.rds["multiregion-${local.environment}-rds"].db_instance_endpoint
        DB_NAME       = "postgres"
        DB_USER       = "postgres_admin"
        DB_SECRET_ARN = module.secrets_manager["rds_admin_password_${local.environment}_2"].secret_arn
        DB_PORT       = "5432"
      }

      subnet_ids         = module.vpc["multiregion-${local.environment}-vpc"].private_subnet_ids
      security_group_ids = [module.security_groups_lambda["multiregion-${local.environment}-lambda-sg"].security_group_id]

      create_function_url = true
      function_url_auth_type = "NONE"
      function_url_cors = {
        allow_credentials = false
        allow_origins = ["*"]
        allow_methods = ["*"]
        allow_headers = ["*"]
        expose_headers = []
        max_age       = 86400
      }

      create_log_group   = true
      log_retention_days = 7

      tags = local.common_tags
    }
  }

  # Lambda Functions for Region 2
  lambda_functions_2 = {
    "multiregion-${local.environment}-api-2" = {
      function_name = "multiregion-${local.environment}-api-2"
      role_arn      = module.iam_roles["lambda-execution-role-${local.environment}"].role_arn
      handler       = "lambda_function.handler"
      runtime       = "python3.11"
      timeout       = 30
      memory_size   = 256
      filename      = "${path.root}/lambda_function.zip"

      environment_variables = {
        DB_HOST       = module.rds_read_replica["multiregion-${local.environment}-rds-replica"].read_replica_endpoint
        DB_NAME       = "postgres"
        DB_USER       = "postgres_admin"
        DB_SECRET_ARN = module.secrets_manager["rds_admin_password_${local.environment}_2"].secret_arn
        DB_PORT       = "5432"
      }

      subnet_ids         = module.vpc2["multiregion-${local.environment}-vpc"].private_subnet_ids
      security_group_ids = [module.security_groups_lambda_2["multiregion-${local.environment}-lambda-sg2"].security_group_id]

      create_function_url = true
      function_url_auth_type = "NONE"
      function_url_cors = {
        allow_credentials = false
        allow_origins = ["*"]
        allow_methods = ["*"]
        allow_headers = ["*"]
        expose_headers = []
        max_age       = 86400
      }

      create_log_group   = true
      log_retention_days = 7

      tags = local.common_tags
    }
  }

  # CloudFront Distribution
  cloudfront_distributions = {
    "multiregion-${local.environment}-frontend" = {
      comment             = "Multi-Region Frontend Distribution"
      default_root_object = "index.html"
      price_class         = "PriceClass_100"
      enabled             = true

      origins = [
        {
          domain_name = module.s3["multiregion-${local.account_id}-${local.region1["region"]}-${local.environment}-data"].bucket_regional_domain_name
          origin_id   = "S3-primary"
          s3_origin_config = {}
        },
        {
          domain_name = module.s3_2["multiregion-${local.account_id}-${local.region2["region"]}-${local.environment}-data"].bucket_regional_domain_name
          origin_id   = "S3-secondary"
          s3_origin_config = {}
        }
      ]

      default_cache_behavior = {
        allowed_methods  = ["GET", "HEAD", "OPTIONS"]
        cached_methods   = ["GET", "HEAD"]
        target_origin_id = "S3-primary"

        forwarded_values = {
          query_string = false
          cookies = {
            forward = "none"
          }
        }

        viewer_protocol_policy = "redirect-to-https"
        min_ttl                = 0
        default_ttl            = 3600
        max_ttl                = 86400
        compress               = true
      }

      custom_error_responses = [
        {
          error_code         = 404
          response_code      = 200
          response_page_path = "/index.html"
        },
        {
          error_code         = 403
          response_code      = 200
          response_page_path = "/index.html"
        }
      ]

      tags = local.common_tags
    }
  }
}




