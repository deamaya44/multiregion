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
  region = local.region_values_maps["region1"].region
}
provider "aws" {
  alias  = "multi"
  region = local.region_values_maps["region2"].region
}