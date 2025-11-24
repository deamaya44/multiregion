#!/bin/bash
# Database Client Setup Script for PostgreSQL
# This script configures an EC2 instance to connect to RDS PostgreSQL using AWS Secrets Manager

# Log all output
exec > >(tee -a /var/log/db-client-setup.log) 2>&1
echo "Starting database client setup at $(date)"

# Update system
yum update -y

# Install PostgreSQL client and tools
yum install -y postgresql15 postgresql15-contrib

# Install additional useful tools
yum install -y htop wget curl unzip jq

# Install AWS CLI v2
cd /tmp
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
./aws/install

# Configure environment variables (without sensitive data)
cat > /etc/environment << EOF
DB_HOST=${db_endpoint}
DB_NAME=${db_name}
DB_PORT=${db_port}
REGION=${region}
SECRET_ARN=${secret_arn}
EOF

# Function to get credentials from Secrets Manager
get_db_credentials() {
    aws secretsmanager get-secret-value \
        --secret-id "${secret_arn}" \
        --region "${region}" \
        --query SecretString \
        --output text
}

# Create database connection script that fetches credentials securely
cat > /home/ec2-user/connect-db.sh << 'EOF'
#!/bin/bash
# Database connection script using AWS Secrets Manager
source /etc/environment

echo "=== Database Connection Script ==="
echo "Fetching credentials from AWS Secrets Manager..."

# Get credentials from Secrets Manager
SECRET_JSON=$(aws secretsmanager get-secret-value \
    --secret-id "$SECRET_ARN" \
    --region "$REGION" \
    --query SecretString \
    --output text 2>/dev/null)

if [ $? -eq 0 ]; then
    # Parse JSON to get password
    DB_PASSWORD=$(echo "$SECRET_JSON" | jq -r '.password // .Password // empty' 2>/dev/null)
    DB_USERNAME=$(echo "$SECRET_JSON" | jq -r '.username // .Username // empty' 2>/dev/null)
    
    if [ -n "$DB_PASSWORD" ] && [ -n "$DB_USERNAME" ]; then
        echo "✅ Credentials retrieved successfully"
        echo "Host: $DB_HOST"
        echo "Database: $DB_NAME"
        echo "User: $DB_USERNAME"
        echo "Port: $DB_PORT"
        echo "Region: $REGION"
        echo ""
        echo "Connecting to PostgreSQL database..."
        
        # Set PGPASSWORD environment variable and connect
        export PGPASSWORD="$DB_PASSWORD"
        psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USERNAME" -d "$DB_NAME"
        
        # Clear password from environment
        unset PGPASSWORD
    else
        echo "❌ Unable to parse credentials from secret"
        echo "Secret format should be: {\"username\": \"user\", \"password\": \"pass\"}"
    fi
else
    echo "❌ Failed to retrieve credentials from Secrets Manager"
    echo "Make sure the EC2 instance has proper IAM permissions"
    echo "Manual connection (you'll be prompted for password):"
    echo "psql -h $DB_HOST -p $DB_PORT -U [username] -d $DB_NAME"
fi
EOF

chmod +x /home/ec2-user/connect-db.sh
chown ec2-user:ec2-user /home/ec2-user/connect-db.sh

# Create test connection script (no actual connection, just test)
cat > /home/ec2-user/test-db-connection.sh << 'EOF'
#!/bin/bash
# Test database connectivity without credentials
source /etc/environment

echo "=== Database Connection Test ==="
echo "Testing network connectivity to: $DB_HOST:$DB_PORT"

# Test network connectivity
timeout 5 bash -c "cat < /dev/null > /dev/tcp/$DB_HOST/$DB_PORT" 2>/dev/null
if [ $? -eq 0 ]; then
    echo "✅ Network connection to database: OK"
else
    echo "❌ Network connection to database: FAILED"
fi

# Test AWS CLI and Secrets Manager access
echo "Testing AWS Secrets Manager access..."
aws secretsmanager describe-secret --secret-id "$SECRET_ARN" --region "$REGION" >/dev/null 2>&1
if [ $? -eq 0 ]; then
    echo "✅ AWS Secrets Manager access: OK"
else
    echo "❌ AWS Secrets Manager access: FAILED"
    echo "Check IAM permissions for secretsmanager:GetSecretValue"
fi
EOF

chmod +x /home/ec2-user/test-db-connection.sh
chown ec2-user:ec2-user /home/ec2-user/test-db-connection.sh

# Create a comprehensive health check script
cat > /home/ec2-user/health-check.sh << 'EOF'
#!/bin/bash
# System and database health check script
source /etc/environment

echo "=== System Health Check ==="
echo "Date: $(date)"
echo "Uptime: $(uptime)"
echo "Region: $REGION"
echo "Database Host: $DB_HOST"
echo "Secret ARN: $SECRET_ARN"
echo ""

echo "=== Network Information ==="
curl -s http://169.254.169.254/latest/meta-data/local-ipv4 2>/dev/null | xargs echo "Private IP:" || echo "Private IP: N/A"
curl -s http://169.254.169.254/latest/meta-data/public-ipv4 2>/dev/null | xargs echo "Public IP:" || echo "Public IP: N/A"
curl -s http://169.254.169.254/latest/meta-data/placement/availability-zone 2>/dev/null | xargs echo "AZ:" || echo "AZ: N/A"
echo ""

# Run connection tests
/home/ec2-user/test-db-connection.sh
EOF

chmod +x /home/ec2-user/health-check.sh
chown ec2-user:ec2-user /home/ec2-user/health-check.sh

# Create welcome message
cat > /etc/motd << EOF
===========================================
  Database Client Server - ${region}
===========================================

Database Connection Info:
- Host: ${db_endpoint}
- Database: ${db_name}
- Port: ${db_port}
- Credentials: Retrieved from AWS Secrets Manager

Useful Commands:
- ./connect-db.sh           - Connect to database (with credentials from Secrets Manager)
- ./test-db-connection.sh   - Test connectivity without connecting
- ./health-check.sh         - Run comprehensive health check

Security Note:
- Database credentials are stored securely in AWS Secrets Manager
- No hardcoded passwords in this instance

===========================================
EOF

# Set up log rotation for application logs
cat > /etc/logrotate.d/dbclient << EOF
/var/log/dbclient/*.log {
    daily
    rotate 7
    compress
    delaycompress
    missingok
    create 644 ec2-user ec2-user
}
EOF

# Create log directory
mkdir -p /var/log/dbclient
chown ec2-user:ec2-user /var/log/dbclient

# Log the completion
echo "$(date): Database client setup completed for region ${region}" | tee -a /var/log/dbclient/setup.log

# Run initial health check
echo "Running initial health check..." | tee -a /var/log/dbclient/setup.log
/home/ec2-user/health-check.sh | tee -a /var/log/dbclient/setup.log

echo "Setup completed successfully at $(date)" | tee -a /var/log/dbclient/setup.log