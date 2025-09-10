import os
from flask import Flask
from flask_sqlalchemy import SQLAlchemy
from flask_jwt_extended import JWTManager
from flask_cors import CORS
from flask_socketio import SocketIO
from flask_migrate import Migrate
import redis
from config import config

# Initialize extensions
db = SQLAlchemy()
jwt = JWTManager()
socketio = SocketIO()
migrate = Migrate()
redis_client = None

def create_app(config_name=None):
    if config_name is None:
        config_name = os.environ.get('FLASK_ENV', 'default')
    
    app = Flask(__name__)
    app.config.from_object(config[config_name])
    
    # Initialize extensions
    db.init_app(app)
    jwt.init_app(app)
    migrate.init_app(app, db)
    
    # Initialize CORS
    CORS(app, origins=app.config['CORS_ORIGINS'])
    
    # Initialize SocketIO
    socketio.init_app(
        app,
        cors_allowed_origins=app.config['SOCKETIO_CORS_ALLOWED_ORIGINS'],
        async_mode=app.config['SOCKETIO_ASYNC_MODE'],
        logger=True,
        engineio_logger=True
    )
    
    # Initialize Redis (optional for development)
    global redis_client
    try:
        if app.config.get('REDIS_URL'):
            redis_client = redis.from_url(app.config['REDIS_URL'])
            # Test connection
            redis_client.ping()
            app.logger.info("Redis connected successfully")
        else:
            redis_client = None
            app.logger.info("Redis disabled for development")
    except Exception as e:
        app.logger.warning(f"Redis connection failed: {e}. Running without Redis.")
        redis_client = None
    
    # Register blueprints
    from app.auth import bp as auth_bp
    app.register_blueprint(auth_bp, url_prefix='/api/auth')
    
    from app.users import bp as users_bp
    app.register_blueprint(users_bp, url_prefix='/api/users')
    
    from app.channels import bp as channels_bp
    app.register_blueprint(channels_bp, url_prefix='/api/channels')
    
    # Register WebSocket events
    from app import websocket_events
    
    # Create database tables
    with app.app_context():
        db.create_all()
    
    return app

def get_redis_client():
    return redis_client
