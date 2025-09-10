# PTT System Deployment Guide

This guide provides step-by-step instructions for deploying the Push-to-Talk (PTT) system on a Namecheap VPS with Docker and Nginx.

## Prerequisites

- Namecheap VPS with Ubuntu 20.04+ or CentOS 8+
- Domain name pointed to your VPS IP
- Root or sudo access to the server
- At least 2GB RAM and 20GB storage

## Server Setup

### 1. Initial Server Configuration

```bash
# Update system packages
sudo apt update && sudo apt upgrade -y

# Install required packages
sudo apt install -y curl wget git ufw fail2ban

# Configure firewall
sudo ufw allow ssh
sudo ufw allow 80
sudo ufw allow 443
sudo ufw enable

# Create a non-root user (optional but recommended)
sudo adduser pttuser
sudo usermod -aG sudo pttuser
```

### 2. Install Docker and Docker Compose

```bash
# Install Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh

# Add user to docker group
sudo usermod -aG docker $USER

# Install Docker Compose
sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

# Verify installation
docker --version
docker-compose --version
```

### 3. Clone the Repository

```bash
# Clone the PTT system repository
git clone <your-repository-url> /opt/ptt-system
cd /opt/ptt-system

# Set proper permissions
sudo chown -R $USER:$USER /opt/ptt-system
```

## Configuration

### 1. Environment Variables

```bash
# Copy environment template
cp .env.example .env

# Edit environment variables
nano .env
```

Update the following variables in `.env`:

```env
# Replace with your domain
DOMAIN=yourdomain.com
EMAIL=admin@yourdomain.com

# Generate secure secrets
JWT_SECRET_KEY=$(openssl rand -base64 32)
SECRET_KEY=$(openssl rand -base64 32)

# Database password
POSTGRES_PASSWORD=$(openssl rand -base64 16)

# CORS origins
CORS_ORIGINS=https://yourdomain.com,https://www.yourdomain.com

# API URLs
REACT_APP_API_URL=https://yourdomain.com/api
REACT_APP_WS_URL=wss://yourdomain.com/api/ws
```

### 2. Domain Configuration

Update the Nginx configuration with your domain:

```bash
# Edit Nginx configuration
nano nginx/conf.d/default.conf

# Replace 'yourdomain.com' with your actual domain
sed -i 's/yourdomain.com/your-actual-domain.com/g' nginx/conf.d/default.conf
```

## SSL Certificate Setup

### Option 1: Let's Encrypt (Recommended)

```bash
# Install Certbot
sudo apt install -y certbot python3-certbot-nginx

# Stop any running services
docker-compose down

# Obtain SSL certificate
sudo certbot certonly --standalone -d yourdomain.com -d www.yourdomain.com --email admin@yourdomain.com --agree-tos --non-interactive

# Copy certificates to nginx directory
sudo mkdir -p nginx/ssl
sudo cp /etc/letsencrypt/live/yourdomain.com/fullchain.pem nginx/ssl/
sudo cp /etc/letsencrypt/live/yourdomain.com/privkey.pem nginx/ssl/
sudo chown -R $USER:$USER nginx/ssl/

# Set up auto-renewal
echo "0 12 * * * /usr/bin/certbot renew --quiet && docker-compose restart nginx" | sudo crontab -
```

### Option 2: Self-Signed Certificate (Development)

```bash
# Generate self-signed certificate
mkdir -p nginx/ssl
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout nginx/ssl/privkey.pem \
    -out nginx/ssl/fullchain.pem \
    -subj "/C=US/ST=State/L=City/O=Organization/CN=yourdomain.com"
```

## Deployment

### 1. Build and Start Services

```bash
# Build and start all services
docker-compose up -d

# Check service status
docker-compose ps

# View logs
docker-compose logs -f
```

### 2. Initialize Database

```bash
# Wait for database to be ready
sleep 30

# Create initial admin user
docker-compose exec backend python -c "
from app import create_app, db
from app.models import User

app = create_app()
with app.app_context():
    # Create admin user
    admin = User(username='admin', email='admin@yourdomain.com', is_admin=True)
    admin.set_password('admin123')  # Change this password!
    db.session.add(admin)
    db.session.commit()
    print('Admin user created: admin / admin123')
"
```

### 3. Create Default Channel

```bash
# Create a default channel
docker-compose exec backend python -c "
from app import create_app, db
from app.models import User, Channel

app = create_app()
with app.app_context():
    admin = User.query.filter_by(username='admin').first()
    if admin:
        channel = Channel(
            name='General',
            description='Default channel for general communication',
            created_by=admin.id,
            max_users=50
        )
        db.session.add(channel)
        db.session.commit()
        print('Default channel created: General')
"
```

## Verification

### 1. Check Services

```bash
# Verify all containers are running
docker-compose ps

# Check service health
curl -f http://localhost:5000/api/health
curl -f http://localhost:3000

# Test HTTPS (if SSL is configured)
curl -f https://yourdomain.com/api/health
```

### 2. Access the System

- **Admin Dashboard**: https://yourdomain.com
- **API Documentation**: https://yourdomain.com/api
- **WebSocket Endpoint**: wss://yourdomain.com/api/ws

Default admin credentials:
- Username: `admin`
- Password: `admin123` (change immediately!)

## Mobile App Configuration

Update the Flutter app configuration to connect to your server:

```dart
// mobile/lib/utils/constants.dart
static const String apiBaseUrl = 'https://yourdomain.com/api';
static const String websocketUrl = 'wss://yourdomain.com/api/ws';
```

Build and distribute the mobile app:

```bash
cd mobile
flutter build apk --release
# The APK will be in build/app/outputs/flutter-apk/app-release.apk
```

## Monitoring and Maintenance

### 1. Log Management

```bash
# View logs
docker-compose logs -f backend
docker-compose logs -f web-admin
docker-compose logs -f nginx

# Log rotation (add to crontab)
echo "0 2 * * * docker system prune -f" | crontab -
```

### 2. Backup

```bash
# Create backup script
cat > /opt/ptt-system/backup.sh << 'EOF'
#!/bin/bash
BACKUP_DIR="/opt/backups/ptt-$(date +%Y%m%d_%H%M%S)"
mkdir -p $BACKUP_DIR

# Backup database
docker-compose exec -T postgres pg_dump -U ptt_user ptt_db > $BACKUP_DIR/database.sql

# Backup configuration
cp -r /opt/ptt-system/.env $BACKUP_DIR/
cp -r /opt/ptt-system/nginx/ssl $BACKUP_DIR/

# Compress backup
tar -czf $BACKUP_DIR.tar.gz -C /opt/backups $(basename $BACKUP_DIR)
rm -rf $BACKUP_DIR

# Keep only last 7 days of backups
find /opt/backups -name "ptt-*.tar.gz" -mtime +7 -delete
EOF

chmod +x /opt/ptt-system/backup.sh

# Schedule daily backups
echo "0 3 * * * /opt/ptt-system/backup.sh" | crontab -
```

### 3. Updates

```bash
# Update the system
cd /opt/ptt-system
git pull origin main

# Rebuild and restart services
docker-compose down
docker-compose build --no-cache
docker-compose up -d
```

## Troubleshooting

### Common Issues

1. **Services won't start**
   ```bash
   # Check logs
   docker-compose logs
   
   # Check disk space
   df -h
   
   # Check memory
   free -h
   ```

2. **SSL certificate issues**
   ```bash
   # Renew certificate manually
   sudo certbot renew
   
   # Copy new certificates
   sudo cp /etc/letsencrypt/live/yourdomain.com/* nginx/ssl/
   docker-compose restart nginx
   ```

3. **Database connection issues**
   ```bash
   # Check database status
   docker-compose exec postgres pg_isready -U ptt_user
   
   # Reset database (WARNING: This will delete all data)
   docker-compose down -v
   docker-compose up -d
   ```

4. **WebSocket connection issues**
   ```bash
   # Check if WebSocket port is accessible
   telnet yourdomain.com 443
   
   # Verify Nginx WebSocket configuration
   docker-compose exec nginx nginx -t
   ```

## Security Considerations

1. **Change default passwords immediately**
2. **Keep system updated**: `sudo apt update && sudo apt upgrade`
3. **Monitor logs regularly**: `docker-compose logs`
4. **Use strong SSL configuration**
5. **Enable fail2ban**: `sudo systemctl enable fail2ban`
6. **Regular backups**
7. **Monitor resource usage**: `htop`, `docker stats`

## Performance Optimization

1. **Increase worker processes** in Nginx configuration
2. **Tune PostgreSQL** settings for your hardware
3. **Enable Redis persistence** for better reliability
4. **Use CDN** for static assets in production
5. **Monitor and scale** based on usage patterns

## Support

For issues and support:
1. Check the logs: `docker-compose logs`
2. Review this documentation
3. Check the GitHub repository for updates
4. Contact system administrator

---

**Important**: Always test the deployment in a staging environment before deploying to production!
