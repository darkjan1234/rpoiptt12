from flask import request, jsonify, current_app
from flask_jwt_extended import jwt_required, get_jwt_identity
from datetime import datetime
from app.channels import bp
from app.models import Channel, User, ActivityLog, OnlineUser
from app import db

@bp.route('', methods=['GET'])
@jwt_required()
def get_channels():
    """Get list of all channels"""
    try:
        page = request.args.get('page', 1, type=int)
        per_page = request.args.get('per_page', 20, type=int)
        search = request.args.get('search', '')
        
        query = Channel.query.filter_by(is_active=True)
        
        if search:
            query = query.filter(Channel.name.contains(search))
        
        channels = query.paginate(
            page=page, per_page=per_page, error_out=False
        )
        
        channel_list = []
        for channel in channels.items:
            channel_data = channel.to_dict()
            # Add online users count
            online_count = OnlineUser.query.filter_by(channel_id=channel.id).count()
            channel_data['online_users'] = online_count
            channel_list.append(channel_data)
        
        return jsonify({
            'channels': channel_list,
            'total': channels.total,
            'pages': channels.pages,
            'current_page': page
        }), 200
        
    except Exception as e:
        current_app.logger.error(f"Get channels error: {str(e)}")
        return jsonify({'error': 'Internal server error'}), 500

@bp.route('/<int:channel_id>', methods=['GET'])
@jwt_required()
def get_channel(channel_id):
    """Get specific channel details"""
    try:
        channel = Channel.query.get(channel_id)
        if not channel or not channel.is_active:
            return jsonify({'error': 'Channel not found'}), 404
        
        channel_data = channel.to_dict()
        
        # Add online users
        online_users = OnlineUser.query.filter_by(channel_id=channel_id).all()
        channel_data['online_users'] = [ou.to_dict() for ou in online_users]
        
        # Add recent activity
        recent_activity = ActivityLog.query.filter_by(channel_id=channel_id)\
            .order_by(ActivityLog.timestamp.desc())\
            .limit(10).all()
        channel_data['recent_activity'] = [log.to_dict() for log in recent_activity]
        
        return jsonify({'channel': channel_data}), 200
        
    except Exception as e:
        current_app.logger.error(f"Get channel error: {str(e)}")
        return jsonify({'error': 'Internal server error'}), 500

@bp.route('', methods=['POST'])
@jwt_required()
def create_channel():
    """Create a new channel"""
    try:
        current_user_id = get_jwt_identity()
        current_user = User.query.get(current_user_id)
        
        data = request.get_json()
        
        if not data or not data.get('name'):
            return jsonify({'error': 'Channel name is required'}), 400
        
        name = data['name'].strip()
        description = data.get('description', '').strip()
        max_users = data.get('max_users', 50)
        
        # Check if channel name already exists
        if Channel.query.filter_by(name=name).first():
            return jsonify({'error': 'Channel name already exists'}), 409
        
        # Create new channel
        channel = Channel(
            name=name,
            description=description,
            max_users=max_users,
            created_by=current_user_id
        )
        
        db.session.add(channel)
        db.session.commit()
        
        # Add creator to channel members
        channel.members.append(current_user)
        db.session.commit()
        
        return jsonify({
            'message': 'Channel created successfully',
            'channel': channel.to_dict()
        }), 201
        
    except Exception as e:
        current_app.logger.error(f"Create channel error: {str(e)}")
        db.session.rollback()
        return jsonify({'error': 'Internal server error'}), 500

@bp.route('/<int:channel_id>', methods=['PUT'])
@jwt_required()
def update_channel(channel_id):
    """Update channel details"""
    try:
        current_user_id = get_jwt_identity()
        current_user = User.query.get(current_user_id)
        
        channel = Channel.query.get(channel_id)
        if not channel:
            return jsonify({'error': 'Channel not found'}), 404
        
        # Only channel creator or admin can update
        if channel.created_by != current_user_id and not current_user.is_admin:
            return jsonify({'error': 'Access denied'}), 403
        
        data = request.get_json()
        if not data:
            return jsonify({'error': 'No data provided'}), 400
        
        # Update allowed fields
        if 'name' in data:
            name = data['name'].strip()
            if name != channel.name:
                if Channel.query.filter_by(name=name).first():
                    return jsonify({'error': 'Channel name already exists'}), 409
                channel.name = name
        
        if 'description' in data:
            channel.description = data['description'].strip()
        
        if 'max_users' in data:
            channel.max_users = max(1, int(data['max_users']))
        
        # Only admins can change active status
        if current_user.is_admin and 'is_active' in data:
            channel.is_active = bool(data['is_active'])
        
        db.session.commit()
        
        return jsonify({
            'message': 'Channel updated successfully',
            'channel': channel.to_dict()
        }), 200
        
    except Exception as e:
        current_app.logger.error(f"Update channel error: {str(e)}")
        db.session.rollback()
        return jsonify({'error': 'Internal server error'}), 500

@bp.route('/<int:channel_id>', methods=['DELETE'])
@jwt_required()
def delete_channel(channel_id):
    """Delete channel"""
    try:
        current_user_id = get_jwt_identity()
        current_user = User.query.get(current_user_id)
        
        channel = Channel.query.get(channel_id)
        if not channel:
            return jsonify({'error': 'Channel not found'}), 404
        
        # Only channel creator or admin can delete
        if channel.created_by != current_user_id and not current_user.is_admin:
            return jsonify({'error': 'Access denied'}), 403
        
        # Soft delete by deactivating
        channel.is_active = False
        db.session.commit()
        
        return jsonify({'message': 'Channel deactivated successfully'}), 200
        
    except Exception as e:
        current_app.logger.error(f"Delete channel error: {str(e)}")
        db.session.rollback()
        return jsonify({'error': 'Internal server error'}), 500

@bp.route('/<int:channel_id>/join', methods=['POST'])
@jwt_required()
def join_channel(channel_id):
    """Join a channel"""
    try:
        current_user_id = get_jwt_identity()
        current_user = User.query.get(current_user_id)
        
        channel = Channel.query.get(channel_id)
        if not channel or not channel.is_active:
            return jsonify({'error': 'Channel not found'}), 404
        
        # Check if already a member
        if current_user in channel.members:
            return jsonify({'message': 'Already a member of this channel'}), 200
        
        # Check channel capacity
        if len(channel.members) >= channel.max_users:
            return jsonify({'error': 'Channel is full'}), 409
        
        # Add user to channel
        channel.members.append(current_user)
        
        # Log activity
        activity = ActivityLog(
            user_id=current_user_id,
            channel_id=channel_id,
            action='join'
        )
        db.session.add(activity)
        db.session.commit()
        
        return jsonify({'message': 'Successfully joined channel'}), 200
        
    except Exception as e:
        current_app.logger.error(f"Join channel error: {str(e)}")
        db.session.rollback()
        return jsonify({'error': 'Internal server error'}), 500

@bp.route('/<int:channel_id>/leave', methods=['POST'])
@jwt_required()
def leave_channel(channel_id):
    """Leave a channel"""
    try:
        current_user_id = get_jwt_identity()
        current_user = User.query.get(current_user_id)
        
        channel = Channel.query.get(channel_id)
        if not channel:
            return jsonify({'error': 'Channel not found'}), 404
        
        # Check if user is a member
        if current_user not in channel.members:
            return jsonify({'message': 'Not a member of this channel'}), 200
        
        # Remove user from channel
        channel.members.remove(current_user)
        
        # Log activity
        activity = ActivityLog(
            user_id=current_user_id,
            channel_id=channel_id,
            action='leave'
        )
        db.session.add(activity)
        db.session.commit()
        
        return jsonify({'message': 'Successfully left channel'}), 200
        
    except Exception as e:
        current_app.logger.error(f"Leave channel error: {str(e)}")
        db.session.rollback()
        return jsonify({'error': 'Internal server error'}), 500
