# PTT System - Quick Start Guide

Get your Push-to-Talk system up and running in minutes!

## 🚀 One-Line Installation (Ubuntu/Debian)

```bash
curl -fsSL https://raw.githubusercontent.com/your-repo/ptt-system/main/deployment/install.sh | bash
```

## 📋 Manual Installation

### Prerequisites
- Ubuntu 20.04+ or Debian 10+
- 2GB+ RAM, 20GB+ storage
- Domain name pointed to your server

### 1. Clone Repository
```bash
git clone https://github.com/your-username/ptt-system.git
cd ptt-system
```

### 2. Configure Environment
```bash
cp .env.example .env
nano .env  # Edit with your domain and settings
```

### 3. Start Services
```bash
docker-compose up -d
```

### 4. Create Admin User
```bash
docker-compose exec backend python -c "
from app import create_app, db
from app.models import User
app = create_app()
with app.app_context():
    admin = User(username='admin', email='admin@yourdomain.com', is_admin=True)
    admin.set_password('admin123')
    db.session.add(admin)
    db.session.commit()
    print('Admin user created!')
"
```

## 🌐 Access Your System

- **Admin Dashboard**: https://yourdomain.com
- **API**: https://yourdomain.com/api
- **WebSocket**: wss://yourdomain.com/api/ws

**Default Login**: admin / admin123 (change immediately!)

## 📱 Mobile App Setup

1. Update `mobile/lib/utils/constants.dart`:
```dart
static const String apiBaseUrl = 'https://yourdomain.com/api';
static const String websocketUrl = 'wss://yourdomain.com/api/ws';
```

2. Build the app:
```bash
cd mobile
flutter build apk --release
```

## 🔧 Development Mode

```bash
# Start development services
docker-compose -f docker-compose.dev.yml up -d

# Access services
# Backend: http://localhost:5000
# Frontend: http://localhost:3000 (if running separately)
```

## 📚 Full Documentation

For complete setup instructions, see [deployment/setup.md](deployment/setup.md)

## 🆘 Quick Troubleshooting

### Services won't start?
```bash
docker-compose logs
```

### Can't connect to WebSocket?
Check your domain DNS and SSL certificate.

### Database issues?
```bash
docker-compose restart postgres
```

### Need to reset everything?
```bash
docker-compose down -v
docker-compose up -d
```

## 🔐 Security Checklist

- [ ] Change default admin password
- [ ] Configure SSL certificate
- [ ] Update environment variables
- [ ] Enable firewall
- [ ] Set up backups

## 📞 Support

- 📖 Documentation: [deployment/setup.md](deployment/setup.md)
- 🐛 Issues: GitHub Issues
- 💬 Discussions: GitHub Discussions

---

**🎉 Congratulations!** Your PTT system is ready to use!
