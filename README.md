# Push-to-Talk (PTT) over Internet System

A complete real-time Push-to-Talk communication system with backend, mobile app, and web admin dashboard.

## 🚀 Quick Start

```bash
# One-line installation (Ubuntu/Debian)
curl -fsSL https://raw.githubusercontent.com/your-repo/ptt-system/main/deployment/install.sh | bash
```

Or see [QUICKSTART.md](QUICKSTART.md) for manual installation.

## 🏗️ System Architecture

### Components

- **Backend**: Python Flask + WebSockets + Redis + PostgreSQL
- **Mobile App**: Flutter with push-to-talk functionality
- **Web Admin**: ReactJS dashboard for monitoring and management
- **Infrastructure**: Docker + Nginx + SSL

### Features

- ✅ Real-time audio streaming over WebSockets
- ✅ User authentication and channel management
- ✅ Scalable architecture with Redis pub/sub
- ✅ Admin dashboard with analytics and monitoring
- ✅ Mobile app with intuitive PTT interface
- ✅ Docker containerization for easy deployment
- ✅ SSL/TLS encryption for secure communication
- ✅ Responsive web admin interface
- ✅ Real-time user presence and speaking indicators

## 📁 Project Structure

```
ptt-system/
├── backend/                 # Python Flask backend
│   ├── app/
│   │   ├── __init__.py     # Flask app factory
│   │   ├── models.py       # Database models
│   │   ├── auth/           # Authentication routes
│   │   ├── users/          # User management routes
│   │   ├── channels/       # Channel management routes
│   │   └── websocket_events.py # WebSocket handlers
│   ├── requirements.txt
│   ├── Dockerfile
│   ├── config.py
│   └── app.py              # Main application entry point
├── mobile/                  # Flutter mobile app
│   ├── lib/
│   │   ├── main.dart       # App entry point
│   │   ├── models/         # Data models
│   │   ├── services/       # API and WebSocket services
│   │   ├── screens/        # UI screens
│   │   ├── widgets/        # Reusable widgets
│   │   └── utils/          # Utilities and constants
│   ├── pubspec.yaml
│   └── android/
├── web-admin/              # React admin dashboard
│   ├── src/
│   │   ├── App.js          # Main app component
│   │   ├── components/     # Reusable components
│   │   ├── pages/          # Page components
│   │   ├── hooks/          # Custom React hooks
│   │   └── services/       # API services
│   ├── package.json
│   ├── Dockerfile
│   └── public/
├── nginx/                  # Nginx configuration
│   ├── nginx.conf          # Main Nginx config
│   └── conf.d/             # Site configurations
├── deployment/             # Deployment scripts and docs
│   ├── setup.md            # Detailed setup guide
│   └── install.sh          # Automated installation script
├── docker-compose.yml      # Production Docker orchestration
├── docker-compose.dev.yml  # Development Docker setup
├── .env.example            # Environment variables template
└── QUICKSTART.md           # Quick start guide
```

## 🌟 Key Features

### Backend (Python Flask)

- RESTful API for user and channel management
- WebSocket support for real-time communication
- JWT-based authentication
- PostgreSQL database with SQLAlchemy ORM
- Redis pub/sub for scalable real-time messaging
- Audio streaming with Opus/PCM support
- Activity logging and analytics

### Mobile App (Flutter)

- Cross-platform (Android/iOS) support
- Intuitive push-to-talk interface
- Real-time audio recording and playback
- WebSocket integration for live communication
- Channel browsing and management
- User presence indicators
- Material Design UI

### Web Admin Dashboard (React)

- Real-time monitoring of users and channels
- User management (create, edit, deactivate)
- Channel management and analytics
- Live speaking indicators
- Usage statistics and charts
- Responsive Material-UI design
- WebSocket integration for live updates

### Infrastructure

- Docker containerization for all services
- Nginx reverse proxy with SSL termination
- PostgreSQL for persistent data storage
- Redis for caching and pub/sub messaging
- Automated SSL certificate management
- Health checks and monitoring
- Backup and update scripts

## 🚀 Deployment Options

### Production Deployment

- **Target**: Namecheap VPS or any Linux server
- **Requirements**: 2GB+ RAM, 20GB+ storage
- **Features**: SSL/TLS, domain setup, automated backups
- **Guide**: [deployment/setup.md](deployment/setup.md)

### Development Setup

```bash
# Start development environment
docker-compose -f docker-compose.dev.yml up -d

# Access services
# Backend: http://localhost:5000
# Admin Dashboard: http://localhost:3000
# Database: localhost:5432
# Redis: localhost:6379
```

## 📱 Mobile App Configuration

Update the Flutter app to connect to your server:

```dart
// mobile/lib/utils/constants.dart
static const String apiBaseUrl = 'https://yourdomain.com/api';
static const String websocketUrl = 'wss://yourdomain.com/api/ws';
```

Build the mobile app:

```bash
cd mobile
flutter build apk --release
```

## 🔧 Development

### Backend Development

```bash
cd backend
pip install -r requirements.txt
python app.py
```

### Frontend Development

```bash
cd web-admin
npm install
npm start
```

### Mobile Development

```bash
cd mobile
flutter pub get
flutter run
```

## 📊 System Requirements

### Server Requirements

- **OS**: Ubuntu 20.04+ / Debian 10+ / CentOS 8+
- **RAM**: 2GB minimum, 4GB recommended
- **Storage**: 20GB minimum, 50GB recommended
- **Network**: Public IP with domain name

### Client Requirements

- **Mobile**: Android 6.0+ / iOS 12.0+
- **Web**: Modern browser with WebSocket support
- **Network**: Stable internet connection for real-time audio

## 🔐 Security Features

- JWT-based authentication with refresh tokens
- HTTPS/WSS encryption for all communications
- CORS protection and security headers
- Rate limiting and DDoS protection
- Input validation and SQL injection prevention
- Secure password hashing with bcrypt
- Admin-only access controls

## 📈 Monitoring & Analytics

- Real-time user presence tracking
- Speaking time analytics per user
- Channel usage statistics
- System health monitoring
- Activity logging and audit trails
- Performance metrics and alerts

## 🆘 Support & Documentation

- 📖 **Setup Guide**: [deployment/setup.md](deployment/setup.md)
- 🚀 **Quick Start**: [QUICKSTART.md](QUICKSTART.md)
- 🐛 **Issues**: GitHub Issues
- 💬 **Discussions**: GitHub Discussions
- 📧 **Contact**: admin@yourdomain.com

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests if applicable
5. Submit a pull request

## 🙏 Acknowledgments

- Flask and Flask-SocketIO for the backend framework
- Flutter team for the mobile development platform
- React and Material-UI for the admin dashboard
- Docker for containerization
- Nginx for reverse proxy and load balancing

---

**🎉 Ready to deploy your PTT system?** Start with the [Quick Start Guide](QUICKSTART.md)!
"# rpoiptt12" 
