# EC2 Instance Outputs

# Primary Region EC2 Outputs
output "ec2_primary_instance_id" {
  description = "ID of the primary EC2 instance"
  value       = { for k, v in module.ec2 : k => v.instance_id }
}

# Removed public IP output - instances are private

output "ec2_primary_private_ip" {
  description = "Private IP addresses of primary EC2 instances"
  value       = { for k, v in module.ec2 : k => v.instance_private_ip }
}

# Removed public DNS output - instances are private

# Secondary Region EC2 Outputs
output "ec2_secondary_instance_id" {
  description = "ID of the secondary EC2 instance"
  value       = { for k, v in module.ec2_secondary : k => v.instance_id }
}

# Removed public IP output - instances are private

output "ec2_secondary_private_ip" {
  description = "Private IP addresses of secondary EC2 instances"
  value       = { for k, v in module.ec2_secondary : k => v.instance_private_ip }
}

# Removed public DNS output - instances are private

# SSH Connection Information (Private IPs)
output "ssh_connection_commands" {
  description = "SSH commands to connect to the private instances (requires bastion host or VPN)"
  value = {
    primary = {
      for k, v in module.ec2 : k => "ssh -i ~/.ssh/demo-key ec2-user@${v.instance_private_ip}"
    }
    secondary = {
      for k, v in module.ec2_secondary : k => "ssh -i ~/.ssh/demo-key ec2-user@${v.instance_private_ip}"
    }
  }
}

# Database Connection Information
output "database_endpoints" {
  description = "Database endpoints for each region"
  value = {
    primary_rds   = { for k, v in module.rds : k => v.db_instance_endpoint }
    secondary_rds = { for k, v in module.rds_read_replica : k => v.read_replica_endpoint }
  }
}

# IAM Information
# output "iam_role_arn" {
#     description = "ARN of the IAM role for Secrets Manager access"
#     value       = aws_iam_role.ec2_secrets_role.arn
# }

# output "iam_instance_profile_arn" {
#     description = "ARN of the IAM instance profile for Secrets Manager access"
#     value       = aws_iam_instance_profile.ec2_secrets_profile.arn
# }

# Secrets Manager Information
output "secrets_manager_arn" {
  description = "ARN of the Secrets Manager secret for RDS credentials"
  value       = { for k, v in module.secrets_manager : k => v.secret_arn }
}

# Quick Connection Guide
output "connection_guide" {
  description = "Quick guide for connecting to databases from private EC2 instances"
  value = {
    instructions = "IMPORTANT: Instances are private - requires bastion host, VPN, or AWS SSM Session Manager to access"
    access_methods = {
      ssm_session_manager = "aws ssm start-session --target <instance-id>"
      bastion_host = "Deploy a bastion host in public subnet and tunnel through it"
      vpn_connection = "Use AWS VPN or Direct Connect for private network access"
    }
    primary_region = {
      ssh_command = "Use SSM or bastion host - see ssh_connection_commands.primary output"
      test_db = "./test-db-connection.sh"
      connect_db = "./connect-db.sh"
      health_check = "./health-check.sh"
    }
    secondary_region = {
      ssh_command = "Use SSM or bastion host - see ssh_connection_commands.secondary output"
      test_db = "./test-db-connection.sh"
      connect_db = "./connect-db.sh"
      health_check = "./health-check.sh"
    }
  }
}