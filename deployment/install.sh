#!/bin/bash

# PTT System Installation Script for Ubuntu/Debian
# Run with: curl -fsSL https://raw.githubusercontent.com/your-repo/ptt-system/main/deployment/install.sh | bash

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if running as root
if [[ $EUID -eq 0 ]]; then
   log_error "This script should not be run as root. Please run as a regular user with sudo privileges."
   exit 1
fi

# Check OS
if [[ ! -f /etc/os-release ]]; then
    log_error "Cannot determine OS. This script supports Ubuntu/Debian only."
    exit 1
fi

source /etc/os-release
if [[ "$ID" != "ubuntu" && "$ID" != "debian" ]]; then
    log_error "This script supports Ubuntu/Debian only. Detected: $ID"
    exit 1
fi

log_info "Starting PTT System installation on $PRETTY_NAME"

# Update system
log_info "Updating system packages..."
sudo apt update && sudo apt upgrade -y

# Install required packages
log_info "Installing required packages..."
sudo apt install -y curl wget git ufw fail2ban htop

# Configure firewall
log_info "Configuring firewall..."
sudo ufw --force reset
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow ssh
sudo ufw allow 80
sudo ufw allow 443
sudo ufw --force enable

# Install Docker
log_info "Installing Docker..."
if ! command -v docker &> /dev/null; then
    curl -fsSL https://get.docker.com -o get-docker.sh
    sudo sh get-docker.sh
    sudo usermod -aG docker $USER
    rm get-docker.sh
    log_info "Docker installed successfully"
else
    log_info "Docker is already installed"
fi

# Install Docker Compose
log_info "Installing Docker Compose..."
if ! command -v docker-compose &> /dev/null; then
    sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    sudo chmod +x /usr/local/bin/docker-compose
    log_info "Docker Compose installed successfully"
else
    log_info "Docker Compose is already installed"
fi

# Verify installations
log_info "Verifying installations..."
docker --version
docker-compose --version

# Create installation directory
INSTALL_DIR="/opt/ptt-system"
log_info "Creating installation directory: $INSTALL_DIR"
sudo mkdir -p $INSTALL_DIR
sudo chown -R $USER:$USER $INSTALL_DIR

# Clone repository (if not already present)
if [[ ! -d "$INSTALL_DIR/.git" ]]; then
    log_info "Cloning PTT System repository..."
    # Replace with your actual repository URL
    git clone https://github.com/your-username/ptt-system.git $INSTALL_DIR
else
    log_info "Repository already exists, pulling latest changes..."
    cd $INSTALL_DIR
    git pull origin main
fi

cd $INSTALL_DIR

# Create environment file
if [[ ! -f .env ]]; then
    log_info "Creating environment configuration..."
    cp .env.example .env
    
    # Generate secure secrets
    JWT_SECRET=$(openssl rand -base64 32)
    SECRET_KEY=$(openssl rand -base64 32)
    DB_PASSWORD=$(openssl rand -base64 16)
    
    # Update .env file
    sed -i "s/your-super-secret-jwt-key-change-in-production/$JWT_SECRET/" .env
    sed -i "s/your-super-secret-key-change-in-production/$SECRET_KEY/" .env
    sed -i "s/ptt_password/$DB_PASSWORD/" .env
    
    log_warn "Please edit .env file to configure your domain and other settings:"
    log_warn "nano $INSTALL_DIR/.env"
else
    log_info "Environment file already exists"
fi

# Install Certbot for SSL
log_info "Installing Certbot for SSL certificates..."
sudo apt install -y certbot python3-certbot-nginx

# Create backup script
log_info "Creating backup script..."
cat > backup.sh << 'EOF'
#!/bin/bash
BACKUP_DIR="/opt/backups/ptt-$(date +%Y%m%d_%H%M%S)"
mkdir -p $BACKUP_DIR

# Backup database
docker-compose exec -T postgres pg_dump -U ptt_user ptt_db > $BACKUP_DIR/database.sql

# Backup configuration
cp -r /opt/ptt-system/.env $BACKUP_DIR/
cp -r /opt/ptt-system/nginx/ssl $BACKUP_DIR/ 2>/dev/null || true

# Compress backup
tar -czf $BACKUP_DIR.tar.gz -C /opt/backups $(basename $BACKUP_DIR)
rm -rf $BACKUP_DIR

# Keep only last 7 days of backups
find /opt/backups -name "ptt-*.tar.gz" -mtime +7 -delete
EOF

chmod +x backup.sh

# Create update script
log_info "Creating update script..."
cat > update.sh << 'EOF'
#!/bin/bash
cd /opt/ptt-system

echo "Pulling latest changes..."
git pull origin main

echo "Stopping services..."
docker-compose down

echo "Building updated images..."
docker-compose build --no-cache

echo "Starting services..."
docker-compose up -d

echo "Cleaning up old images..."
docker image prune -f

echo "Update completed!"
EOF

chmod +x update.sh

# Create systemd service for auto-start
log_info "Creating systemd service..."
sudo tee /etc/systemd/system/ptt-system.service > /dev/null << EOF
[Unit]
Description=PTT System
Requires=docker.service
After=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=$INSTALL_DIR
ExecStart=/usr/local/bin/docker-compose up -d
ExecStop=/usr/local/bin/docker-compose down
TimeoutStartSec=0

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable ptt-system

log_info "Installation completed successfully!"
log_warn ""
log_warn "Next steps:"
log_warn "1. Edit the environment file: nano $INSTALL_DIR/.env"
log_warn "2. Configure your domain in nginx/conf.d/default.conf"
log_warn "3. Set up SSL certificates (see deployment/setup.md)"
log_warn "4. Start the system: cd $INSTALL_DIR && docker-compose up -d"
log_warn ""
log_warn "For detailed instructions, see: $INSTALL_DIR/deployment/setup.md"
log_warn ""
log_warn "Note: You may need to log out and back in for Docker group membership to take effect."
