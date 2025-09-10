import json
import base64
from datetime import datetime
from flask import current_app
from flask_socketio import emit, join_room, leave_room, disconnect
from flask_jwt_extended import decode_token, get_jwt_identity
from app import socketio, db, get_redis_client
from app.models import User, Channel, OnlineUser, ActivityLog

# Store active connections
active_connections = {}

def authenticate_socket(token):
    """Authenticate WebSocket connection using JWT token"""
    try:
        decoded_token = decode_token(token)
        user_id = decoded_token['sub']
        user = User.query.get(user_id)
        if user and user.is_active:
            return user
        return None
    except Exception as e:
        current_app.logger.error(f"Socket authentication error: {str(e)}")
        return None

@socketio.on('connect')
def handle_connect(auth):
    """Handle client connection"""
    try:
        # Authenticate user
        token = auth.get('token') if auth else None
        if not token:
            current_app.logger.warning("Connection attempt without token")
            disconnect()
            return False
        
        user = authenticate_socket(token)
        if not user:
            current_app.logger.warning("Connection attempt with invalid token")
            disconnect()
            return False
        
        # Store connection info
        from flask import request
        socket_id = request.sid
        active_connections[socket_id] = {
            'user_id': user.id,
            'user': user,
            'channel_id': None,
            'is_speaking': False,
            'connected_at': datetime.utcnow()
        }
        
        # Update user's last seen
        user.last_seen = datetime.utcnow()
        db.session.commit()
        
        current_app.logger.info(f"User {user.username} connected with socket {socket_id}")
        emit('connected', {'message': 'Connected successfully', 'user': user.to_dict()})
        
        return True
        
    except Exception as e:
        current_app.logger.error(f"Connection error: {str(e)}")
        disconnect()
        return False

@socketio.on('disconnect')
def handle_disconnect():
    """Handle client disconnection"""
    try:
        from flask import request
        socket_id = request.sid
        
        if socket_id in active_connections:
            connection = active_connections[socket_id]
            user = connection['user']
            channel_id = connection['channel_id']
            
            # Leave channel if connected
            if channel_id:
                handle_leave_channel_internal(socket_id, channel_id)
            
            # Remove from active connections
            del active_connections[socket_id]
            
            # Remove from online users table
            OnlineUser.query.filter_by(socket_id=socket_id).delete()
            db.session.commit()
            
            current_app.logger.info(f"User {user.username} disconnected")
        
    except Exception as e:
        current_app.logger.error(f"Disconnect error: {str(e)}")

@socketio.on('join_channel')
def handle_join_channel(data):
    """Handle user joining a channel"""
    try:
        from flask import request
        socket_id = request.sid
        
        if socket_id not in active_connections:
            emit('error', {'message': 'Not authenticated'})
            return
        
        connection = active_connections[socket_id]
        user = connection['user']
        channel_id = data.get('channel_id')
        
        if not channel_id:
            emit('error', {'message': 'Channel ID required'})
            return
        
        channel = Channel.query.get(channel_id)
        if not channel or not channel.is_active:
            emit('error', {'message': 'Channel not found'})
            return
        
        # Check if user is a member of the channel
        if user not in channel.members:
            emit('error', {'message': 'Not a member of this channel'})
            return
        
        # Leave previous channel if any
        if connection['channel_id']:
            handle_leave_channel_internal(socket_id, connection['channel_id'])
        
        # Join new channel
        join_room(f"channel_{channel_id}")
        connection['channel_id'] = channel_id
        
        # Add to online users
        online_user = OnlineUser(
            user_id=user.id,
            channel_id=channel_id,
            socket_id=socket_id
        )
        db.session.add(online_user)
        
        # Log activity
        activity = ActivityLog(
            user_id=user.id,
            channel_id=channel_id,
            action='join'
        )
        db.session.add(activity)
        db.session.commit()
        
        # Notify channel members
        emit('user_joined', {
            'user': user.to_dict(),
            'channel_id': channel_id
        }, room=f"channel_{channel_id}")
        
        # Send current channel state to user
        online_users = OnlineUser.query.filter_by(channel_id=channel_id).all()
        emit('channel_state', {
            'channel': channel.to_dict(),
            'online_users': [ou.to_dict() for ou in online_users]
        })
        
        current_app.logger.info(f"User {user.username} joined channel {channel.name}")
        
    except Exception as e:
        current_app.logger.error(f"Join channel error: {str(e)}")
        emit('error', {'message': 'Failed to join channel'})

@socketio.on('leave_channel')
def handle_leave_channel(data):
    """Handle user leaving a channel"""
    try:
        from flask import request
        socket_id = request.sid
        
        if socket_id not in active_connections:
            emit('error', {'message': 'Not authenticated'})
            return
        
        connection = active_connections[socket_id]
        channel_id = connection['channel_id']
        
        if not channel_id:
            emit('error', {'message': 'Not in any channel'})
            return
        
        handle_leave_channel_internal(socket_id, channel_id)
        emit('left_channel', {'channel_id': channel_id})
        
    except Exception as e:
        current_app.logger.error(f"Leave channel error: {str(e)}")
        emit('error', {'message': 'Failed to leave channel'})

def handle_leave_channel_internal(socket_id, channel_id):
    """Internal function to handle leaving a channel"""
    try:
        connection = active_connections[socket_id]
        user = connection['user']
        
        # Leave room
        leave_room(f"channel_{channel_id}")
        connection['channel_id'] = None
        connection['is_speaking'] = False
        
        # Remove from online users
        OnlineUser.query.filter_by(socket_id=socket_id, channel_id=channel_id).delete()
        
        # Log activity
        activity = ActivityLog(
            user_id=user.id,
            channel_id=channel_id,
            action='leave'
        )
        db.session.add(activity)
        db.session.commit()
        
        # Notify channel members
        emit('user_left', {
            'user': user.to_dict(),
            'channel_id': channel_id
        }, room=f"channel_{channel_id}")
        
    except Exception as e:
        current_app.logger.error(f"Leave channel internal error: {str(e)}")

@socketio.on('start_speaking')
def handle_start_speaking():
    """Handle user starting to speak"""
    try:
        from flask import request
        socket_id = request.sid
        
        if socket_id not in active_connections:
            emit('error', {'message': 'Not authenticated'})
            return
        
        connection = active_connections[socket_id]
        user = connection['user']
        channel_id = connection['channel_id']
        
        if not channel_id:
            emit('error', {'message': 'Not in any channel'})
            return
        
        # Update speaking status
        connection['is_speaking'] = True
        connection['speak_start_time'] = datetime.utcnow()
        
        # Update database
        online_user = OnlineUser.query.filter_by(socket_id=socket_id).first()
        if online_user:
            online_user.is_speaking = True
            online_user.last_activity = datetime.utcnow()
        
        # Log activity
        activity = ActivityLog(
            user_id=user.id,
            channel_id=channel_id,
            action='speak_start'
        )
        db.session.add(activity)
        db.session.commit()
        
        # Notify channel members
        emit('user_speaking', {
            'user_id': user.id,
            'username': user.username,
            'is_speaking': True
        }, room=f"channel_{channel_id}")
        
        # Publish to Redis for scaling (if available)
        redis_client = get_redis_client()
        if redis_client:
            try:
                redis_client.publish(f"channel_{channel_id}_speaking", json.dumps({
                    'user_id': user.id,
                    'username': user.username,
                    'is_speaking': True,
                    'socket_id': socket_id
                }))
            except Exception as e:
                current_app.logger.warning(f"Redis publish failed: {e}")
        
        current_app.logger.info(f"User {user.username} started speaking in channel {channel_id}")
        
    except Exception as e:
        current_app.logger.error(f"Start speaking error: {str(e)}")
        emit('error', {'message': 'Failed to start speaking'})

@socketio.on('stop_speaking')
def handle_stop_speaking():
    """Handle user stopping to speak"""
    try:
        from flask import request
        socket_id = request.sid
        
        if socket_id not in active_connections:
            emit('error', {'message': 'Not authenticated'})
            return
        
        connection = active_connections[socket_id]
        user = connection['user']
        channel_id = connection['channel_id']
        
        if not channel_id or not connection['is_speaking']:
            return
        
        # Calculate speak duration
        speak_duration = None
        if 'speak_start_time' in connection:
            speak_duration = (datetime.utcnow() - connection['speak_start_time']).total_seconds()
        
        # Update speaking status
        connection['is_speaking'] = False
        if 'speak_start_time' in connection:
            del connection['speak_start_time']
        
        # Update database
        online_user = OnlineUser.query.filter_by(socket_id=socket_id).first()
        if online_user:
            online_user.is_speaking = False
            online_user.last_activity = datetime.utcnow()
        
        # Log activity
        activity = ActivityLog(
            user_id=user.id,
            channel_id=channel_id,
            action='speak_end',
            duration=speak_duration
        )
        db.session.add(activity)
        db.session.commit()
        
        # Notify channel members
        emit('user_speaking', {
            'user_id': user.id,
            'username': user.username,
            'is_speaking': False
        }, room=f"channel_{channel_id}")
        
        # Publish to Redis for scaling (if available)
        redis_client = get_redis_client()
        if redis_client:
            try:
                redis_client.publish(f"channel_{channel_id}_speaking", json.dumps({
                    'user_id': user.id,
                    'username': user.username,
                    'is_speaking': False,
                    'socket_id': socket_id
                }))
            except Exception as e:
                current_app.logger.warning(f"Redis publish failed: {e}")
        
        current_app.logger.info(f"User {user.username} stopped speaking in channel {channel_id}")
        
    except Exception as e:
        current_app.logger.error(f"Stop speaking error: {str(e)}")
        emit('error', {'message': 'Failed to stop speaking'})

@socketio.on('audio_data')
def handle_audio_data(data):
    """Handle incoming audio data"""
    try:
        from flask import request
        socket_id = request.sid
        
        if socket_id not in active_connections:
            emit('error', {'message': 'Not authenticated'})
            return
        
        connection = active_connections[socket_id]
        user = connection['user']
        channel_id = connection['channel_id']
        
        if not channel_id or not connection['is_speaking']:
            return
        
        # Validate audio data
        audio_data = data.get('audio')
        if not audio_data:
            return
        
        # Relay audio to other users in the channel (excluding sender)
        emit('audio_data', {
            'user_id': user.id,
            'username': user.username,
            'audio': audio_data,
            'timestamp': datetime.utcnow().isoformat()
        }, room=f"channel_{channel_id}", include_self=False)
        
        # Publish to Redis for scaling across multiple backend instances (if available)
        redis_client = get_redis_client()
        if redis_client:
            try:
                redis_client.publish(f"channel_{channel_id}_audio", json.dumps({
                    'user_id': user.id,
                    'username': user.username,
                    'audio': audio_data,
                    'timestamp': datetime.utcnow().isoformat(),
                    'sender_socket': socket_id
                }))
            except Exception as e:
                current_app.logger.warning(f"Redis publish failed: {e}")
        
    except Exception as e:
        current_app.logger.error(f"Audio data error: {str(e)}")
        emit('error', {'message': 'Failed to process audio data'})
