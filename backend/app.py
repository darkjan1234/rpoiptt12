#!/usr/bin/env python3
"""
Push-to-Talk Backend Server
Main application entry point
"""

import os
import sys
from flask import Flask, jsonify
from app import create_app, socketio

# Create Flask application
app = create_app()

@app.route('/api/health', methods=['GET'])
def health_check():
    """Health check endpoint"""
    return jsonify({
        'status': 'healthy',
        'service': 'ptt-backend',
        'version': '1.0.0'
    }), 200

@app.route('/api', methods=['GET'])
def api_info():
    """API information endpoint"""
    return jsonify({
        'service': 'Push-to-Talk Backend API',
        'version': '1.0.0',
        'endpoints': {
            'auth': '/api/auth',
            'users': '/api/users',
            'channels': '/api/channels',
            'websocket': '/api/ws'
        }
    }), 200

if __name__ == '__main__':
    # Development server
    port = int(os.environ.get('PORT', 5000))
    debug = os.environ.get('FLASK_ENV') == 'development'
    
    print(f"Starting PTT Backend Server on port {port}")
    print(f"Debug mode: {debug}")
    
    socketio.run(
        app,
        host='0.0.0.0',
        port=port,
        debug=debug,
        use_reloader=debug
    )
