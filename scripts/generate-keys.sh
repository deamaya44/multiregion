#!/bin/bash
set -e

# Create templates directory if it doesn't exist
mkdir -p "$(dirname "$0")/../templates"

# Generate SSH key pair if it doesn't exist
if [ ! -f "$(dirname "$0")/../templates/demo-ssh-key" ]; then
	ssh-keygen -t rsa -b 2048 -f "$(dirname "$0")/../templates/demo-ssh-key" -N "" -C "demo-ssh-key"
	echo "SSH key pair generated successfully"
else
	echo "SSH key pair already exists"
fi
