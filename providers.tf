terraform {
  required_providers {
    databricks = {
      source  = "databricks/databricks"
      version = "1.97.0"
    }
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }

  }
  cloud {
    organization = "multiregion"
    workspaces {
      name = "dev"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}
provider "aws" {
  alias  = "multi"
  region = "us-west-2"
}