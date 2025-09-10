from datetime import datetime
from flask_sqlalchemy import SQLAlchemy
from werkzeug.security import generate_password_hash, check_password_hash
from app import db

# Association table for many-to-many relationship between users and channels
user_channels = db.Table('user_channels',
    db.Column('user_id', db.Integer, db.ForeignKey('users.id'), primary_key=True),
    db.Column('channel_id', db.Integer, db.ForeignKey('channels.id'), primary_key=True),
    db.Column('joined_at', db.DateTime, default=datetime.utcnow)
)

class User(db.Model):
    __tablename__ = 'users'
    
    id = db.Column(db.Integer, primary_key=True)
    username = db.Column(db.String(80), unique=True, nullable=False, index=True)
    email = db.Column(db.String(120), unique=True, nullable=True)
    password_hash = db.Column(db.String(255), nullable=False)
    is_admin = db.Column(db.Boolean, default=False)
    is_active = db.Column(db.Boolean, default=True)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    last_seen = db.Column(db.DateTime, default=datetime.utcnow)
    
    # Relationships
    channels = db.relationship('Channel', secondary=user_channels, backref='members')
    activity_logs = db.relationship('ActivityLog', backref='user', lazy='dynamic')
    
    def set_password(self, password):
        self.password_hash = generate_password_hash(password)
    
    def check_password(self, password):
        return check_password_hash(self.password_hash, password)
    
    def to_dict(self):
        return {
            'id': self.id,
            'username': self.username,
            'email': self.email,
            'is_admin': self.is_admin,
            'is_active': self.is_active,
            'created_at': self.created_at.isoformat(),
            'last_seen': self.last_seen.isoformat() if self.last_seen else None
        }

class Channel(db.Model):
    __tablename__ = 'channels'
    
    id = db.Column(db.Integer, primary_key=True)
    name = db.Column(db.String(100), unique=True, nullable=False, index=True)
    description = db.Column(db.Text)
    is_active = db.Column(db.Boolean, default=True)
    max_users = db.Column(db.Integer, default=50)
    created_by = db.Column(db.Integer, db.ForeignKey('users.id'), nullable=False)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    
    # Relationships
    creator = db.relationship('User', backref='created_channels')
    activity_logs = db.relationship('ActivityLog', backref='channel', lazy='dynamic')
    
    def to_dict(self):
        return {
            'id': self.id,
            'name': self.name,
            'description': self.description,
            'is_active': self.is_active,
            'max_users': self.max_users,
            'created_by': self.created_by,
            'created_at': self.created_at.isoformat(),
            'member_count': len(self.members)
        }

class ActivityLog(db.Model):
    __tablename__ = 'activity_logs'
    
    id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(db.Integer, db.ForeignKey('users.id'), nullable=False)
    channel_id = db.Column(db.Integer, db.ForeignKey('channels.id'), nullable=False)
    action = db.Column(db.String(50), nullable=False)  # 'join', 'leave', 'speak_start', 'speak_end'
    duration = db.Column(db.Float)  # For speak actions, duration in seconds
    timestamp = db.Column(db.DateTime, default=datetime.utcnow, index=True)
    extra_data = db.Column(db.JSON)  # Additional data like audio quality, etc.
    
    def to_dict(self):
        return {
            'id': self.id,
            'user_id': self.user_id,
            'channel_id': self.channel_id,
            'action': self.action,
            'duration': self.duration,
            'timestamp': self.timestamp.isoformat(),
            'extra_data': self.extra_data
        }

class OnlineUser(db.Model):
    __tablename__ = 'online_users'
    
    id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(db.Integer, db.ForeignKey('users.id'), nullable=False)
    channel_id = db.Column(db.Integer, db.ForeignKey('channels.id'), nullable=True)
    socket_id = db.Column(db.String(100), nullable=False, unique=True)
    is_speaking = db.Column(db.Boolean, default=False)
    joined_at = db.Column(db.DateTime, default=datetime.utcnow)
    last_activity = db.Column(db.DateTime, default=datetime.utcnow)
    
    # Relationships
    user = db.relationship('User', backref='online_sessions')
    channel = db.relationship('Channel', backref='online_users')
    
    def to_dict(self):
        return {
            'id': self.id,
            'user_id': self.user_id,
            'channel_id': self.channel_id,
            'socket_id': self.socket_id,
            'is_speaking': self.is_speaking,
            'joined_at': self.joined_at.isoformat(),
            'last_activity': self.last_activity.isoformat(),
            'user': self.user.to_dict() if self.user else None
        }
