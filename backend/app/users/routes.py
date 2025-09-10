from flask import request, jsonify, current_app
from flask_jwt_extended import jwt_required, get_jwt_identity
from datetime import datetime
from app.users import bp
from app.models import User, ActivityLog
from app import db

def require_admin():
    """Decorator to require admin privileges"""
    current_user_id = get_jwt_identity()
    user = User.query.get(current_user_id)
    if not user or not user.is_admin:
        return jsonify({'error': 'Admin privileges required'}), 403
    return None

@bp.route('', methods=['GET'])
@jwt_required()
def get_users():
    """Get list of all users"""
    try:
        # Check if user is admin for full details
        current_user_id = get_jwt_identity()
        current_user = User.query.get(current_user_id)
        
        page = request.args.get('page', 1, type=int)
        per_page = request.args.get('per_page', 20, type=int)
        search = request.args.get('search', '')
        
        query = User.query
        
        if search:
            query = query.filter(User.username.contains(search))
        
        users = query.paginate(
            page=page, per_page=per_page, error_out=False
        )
        
        # Return limited info for non-admin users
        if not current_user.is_admin:
            user_list = [{'id': u.id, 'username': u.username} for u in users.items]
        else:
            user_list = [u.to_dict() for u in users.items]
        
        return jsonify({
            'users': user_list,
            'total': users.total,
            'pages': users.pages,
            'current_page': page
        }), 200
        
    except Exception as e:
        current_app.logger.error(f"Get users error: {str(e)}")
        return jsonify({'error': 'Internal server error'}), 500

@bp.route('/<int:user_id>', methods=['GET'])
@jwt_required()
def get_user(user_id):
    """Get specific user details"""
    try:
        current_user_id = get_jwt_identity()
        current_user = User.query.get(current_user_id)
        
        user = User.query.get(user_id)
        if not user:
            return jsonify({'error': 'User not found'}), 404
        
        # Users can view their own profile, admins can view any profile
        if current_user_id != user_id and not current_user.is_admin:
            return jsonify({'error': 'Access denied'}), 403
        
        user_data = user.to_dict()
        
        # Add statistics for admin or own profile
        if current_user.is_admin or current_user_id == user_id:
            # Get talk time statistics
            talk_logs = ActivityLog.query.filter_by(
                user_id=user_id, 
                action='speak_end'
            ).all()
            
            total_talk_time = sum(log.duration or 0 for log in talk_logs)
            user_data['total_talk_time'] = total_talk_time
            user_data['total_sessions'] = len(talk_logs)
        
        return jsonify({'user': user_data}), 200
        
    except Exception as e:
        current_app.logger.error(f"Get user error: {str(e)}")
        return jsonify({'error': 'Internal server error'}), 500

@bp.route('', methods=['POST'])
@jwt_required()
def create_user():
    """Create a new user (admin only)"""
    try:
        admin_check = require_admin()
        if admin_check:
            return admin_check
        
        data = request.get_json()
        
        if not data or not data.get('username') or not data.get('password'):
            return jsonify({'error': 'Username and password are required'}), 400
        
        username = data['username'].strip()
        password = data['password']
        email = data.get('email', '').strip() or None
        is_admin = data.get('is_admin', False)
        
        # Check if username already exists
        if User.query.filter_by(username=username).first():
            return jsonify({'error': 'Username already exists'}), 409
        
        # Check if email already exists (if provided)
        if email and User.query.filter_by(email=email).first():
            return jsonify({'error': 'Email already exists'}), 409
        
        # Create new user
        user = User(username=username, email=email, is_admin=is_admin)
        user.set_password(password)
        
        db.session.add(user)
        db.session.commit()
        
        return jsonify({
            'message': 'User created successfully',
            'user': user.to_dict()
        }), 201
        
    except Exception as e:
        current_app.logger.error(f"Create user error: {str(e)}")
        db.session.rollback()
        return jsonify({'error': 'Internal server error'}), 500

@bp.route('/<int:user_id>', methods=['PUT'])
@jwt_required()
def update_user(user_id):
    """Update user details"""
    try:
        current_user_id = get_jwt_identity()
        current_user = User.query.get(current_user_id)
        
        user = User.query.get(user_id)
        if not user:
            return jsonify({'error': 'User not found'}), 404
        
        # Users can update their own profile, admins can update any profile
        if current_user_id != user_id and not current_user.is_admin:
            return jsonify({'error': 'Access denied'}), 403
        
        data = request.get_json()
        if not data:
            return jsonify({'error': 'No data provided'}), 400
        
        # Update allowed fields
        if 'email' in data:
            email = data['email'].strip() or None
            if email and email != user.email:
                if User.query.filter_by(email=email).first():
                    return jsonify({'error': 'Email already exists'}), 409
                user.email = email
        
        if 'password' in data and data['password']:
            user.set_password(data['password'])
        
        # Only admins can change admin status and active status
        if current_user.is_admin:
            if 'is_admin' in data:
                user.is_admin = bool(data['is_admin'])
            if 'is_active' in data:
                user.is_active = bool(data['is_active'])
        
        db.session.commit()
        
        return jsonify({
            'message': 'User updated successfully',
            'user': user.to_dict()
        }), 200
        
    except Exception as e:
        current_app.logger.error(f"Update user error: {str(e)}")
        db.session.rollback()
        return jsonify({'error': 'Internal server error'}), 500

@bp.route('/<int:user_id>', methods=['DELETE'])
@jwt_required()
def delete_user(user_id):
    """Delete user (admin only)"""
    try:
        admin_check = require_admin()
        if admin_check:
            return admin_check
        
        current_user_id = get_jwt_identity()
        
        # Prevent self-deletion
        if current_user_id == user_id:
            return jsonify({'error': 'Cannot delete your own account'}), 400
        
        user = User.query.get(user_id)
        if not user:
            return jsonify({'error': 'User not found'}), 404
        
        # Soft delete by deactivating
        user.is_active = False
        db.session.commit()
        
        return jsonify({'message': 'User deactivated successfully'}), 200
        
    except Exception as e:
        current_app.logger.error(f"Delete user error: {str(e)}")
        db.session.rollback()
        return jsonify({'error': 'Internal server error'}), 500
