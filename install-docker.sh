#!/bin/bash

# Script to install Docker and Docker Compose on Ubuntu
# Must be run with sudo privileges

# Check if script is run as root
if [ "$EUID" -ne 0 ]
  then echo "Please run as root (with sudo)"
  exit
fi

echo "Starting Docker and Docker Compose installation..."

# Update package index
echo "Updating package index..."
apt-get update

# Install required packages
echo "Installing required packages..."
apt-get install -y \
    ca-certificates \
    curl \
    gnupg \
    lsb-release

# Add Docker's official GPG key
echo "Adding Docker's official GPG key..."
mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg

# Set up Docker repository
echo "Setting up Docker repository..."
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

# Update package index again
echo "Updating package index with Docker repository..."
apt-get update

# Install Docker Engine, containerd, and Docker Compose
echo "Installing Docker Engine, containerd, and Docker Compose..."
apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

# Add current user to docker group
echo "Adding current user to docker group..."
usermod -aG docker $SUDO_USER

# Start and enable Docker service
echo "Starting and enabling Docker service..."
systemctl start docker
systemctl enable docker

# Verify installations
echo "Verifying installations..."
docker --version
docker compose version

echo "Installation complete!"
echo "Please log out and log back in for group changes to take effect."