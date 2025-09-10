import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:logger/logger.dart';

import '../models/user.dart';
import '../models/channel.dart';
import '../utils/constants.dart';

class WebSocketService extends ChangeNotifier {
  final Logger _logger = Logger();
  
  IO.Socket? _socket;
  bool _isConnected = false;
  Channel? _currentChannel;
  List<OnlineUser> _onlineUsers = [];
  Map<int, bool> _speakingUsers = {};

  // Getters
  bool get isConnected => _isConnected;
  Channel? get currentChannel => _currentChannel;
  List<OnlineUser> get onlineUsers => _onlineUsers;
  Map<int, bool> get speakingUsers => _speakingUsers;

  // Callbacks
  Function(Uint8List audioData, int userId, String username)? onAudioReceived;
  Function(String message)? onError;
  Function(String message)? onInfo;

  // Connect to WebSocket
  Future<void> connect(String accessToken) async {
    if (_isConnected) {
      _logger.w('Already connected to WebSocket');
      return;
    }

    try {
      _socket = IO.io(
        Constants.websocketUrl,
        IO.OptionBuilder()
            .setTransports(['websocket'])
            .enableAutoConnect()
            .setAuth({'token': accessToken})
            .build(),
      );

      _setupEventListeners();
      
      _socket!.connect();
      _logger.i('Connecting to WebSocket...');
      
    } catch (e) {
      _logger.e('WebSocket connection error: $e');
      onError?.call('Failed to connect to server');
    }
  }

  // Disconnect from WebSocket
  void disconnect() {
    if (_socket != null) {
      _socket!.disconnect();
      _socket!.dispose();
      _socket = null;
    }
    
    _isConnected = false;
    _currentChannel = null;
    _onlineUsers.clear();
    _speakingUsers.clear();
    
    notifyListeners();
    _logger.i('Disconnected from WebSocket');
  }

  // Setup event listeners
  void _setupEventListeners() {
    if (_socket == null) return;

    _socket!.onConnect((_) {
      _isConnected = true;
      notifyListeners();
      _logger.i('Connected to WebSocket');
      onInfo?.call('Connected to server');
    });

    _socket!.onDisconnect((_) {
      _isConnected = false;
      _currentChannel = null;
      _onlineUsers.clear();
      _speakingUsers.clear();
      notifyListeners();
      _logger.i('Disconnected from WebSocket');
      onInfo?.call('Disconnected from server');
    });

    _socket!.on('connected', (data) {
      _logger.i('WebSocket authentication successful');
      onInfo?.call('Authentication successful');
    });

    _socket!.on('error', (data) {
      final message = data['message'] ?? 'Unknown error';
      _logger.e('WebSocket error: $message');
      onError?.call(message);
    });

    _socket!.on('channel_state', (data) {
      _handleChannelState(data);
    });

    _socket!.on('user_joined', (data) {
      _handleUserJoined(data);
    });

    _socket!.on('user_left', (data) {
      _handleUserLeft(data);
    });

    _socket!.on('user_speaking', (data) {
      _handleUserSpeaking(data);
    });

    _socket!.on('audio_data', (data) {
      _handleAudioData(data);
    });

    _socket!.onConnectError((error) {
      _logger.e('WebSocket connection error: $error');
      onError?.call('Connection failed');
    });
  }

  // Join a channel
  void joinChannel(int channelId) {
    if (!_isConnected || _socket == null) {
      onError?.call('Not connected to server');
      return;
    }

    _socket!.emit('join_channel', {'channel_id': channelId});
    _logger.i('Joining channel: $channelId');
  }

  // Leave current channel
  void leaveChannel() {
    if (!_isConnected || _socket == null || _currentChannel == null) {
      return;
    }

    _socket!.emit('leave_channel', {});
    _logger.i('Leaving channel: ${_currentChannel!.id}');
  }

  // Start speaking
  void startSpeaking() {
    if (!_isConnected || _socket == null || _currentChannel == null) {
      onError?.call('Not connected to a channel');
      return;
    }

    _socket!.emit('start_speaking', {});
    _logger.i('Started speaking');
  }

  // Stop speaking
  void stopSpeaking() {
    if (!_isConnected || _socket == null) {
      return;
    }

    _socket!.emit('stop_speaking', {});
    _logger.i('Stopped speaking');
  }

  // Send audio data
  void sendAudioData(Uint8List audioData) {
    if (!_isConnected || _socket == null || _currentChannel == null) {
      return;
    }

    // Convert audio data to base64 for transmission
    final base64Audio = base64Encode(audioData);
    
    _socket!.emit('audio_data', {
      'audio': base64Audio,
    });
  }

  // Handle channel state
  void _handleChannelState(dynamic data) {
    try {
      _currentChannel = Channel.fromJson(data['channel']);
      
      final onlineUsersData = data['online_users'] as List;
      _onlineUsers = onlineUsersData
          .map((userData) => OnlineUser.fromJson(userData))
          .toList();
      
      // Update speaking users map
      _speakingUsers.clear();
      for (final user in _onlineUsers) {
        _speakingUsers[user.userId] = user.isSpeaking;
      }
      
      notifyListeners();
      _logger.i('Channel state updated: ${_currentChannel!.name}');
      onInfo?.call('Joined channel: ${_currentChannel!.name}');
      
    } catch (e) {
      _logger.e('Error handling channel state: $e');
    }
  }

  // Handle user joined
  void _handleUserJoined(dynamic data) {
    try {
      final user = User.fromJson(data['user']);
      _logger.i('User joined: ${user.username}');
      onInfo?.call('${user.username} joined the channel');
      
      // Refresh channel state would be handled by the server
      // sending updated online users list
      
    } catch (e) {
      _logger.e('Error handling user joined: $e');
    }
  }

  // Handle user left
  void _handleUserLeft(dynamic data) {
    try {
      final user = User.fromJson(data['user']);
      _logger.i('User left: ${user.username}');
      onInfo?.call('${user.username} left the channel');
      
      // Remove from online users
      _onlineUsers.removeWhere((ou) => ou.userId == user.id);
      _speakingUsers.remove(user.id);
      
      notifyListeners();
      
    } catch (e) {
      _logger.e('Error handling user left: $e');
    }
  }

  // Handle user speaking status
  void _handleUserSpeaking(dynamic data) {
    try {
      final userId = data['user_id'] as int;
      final username = data['username'] as String;
      final isSpeaking = data['is_speaking'] as bool;
      
      _speakingUsers[userId] = isSpeaking;
      
      // Update online user speaking status
      final userIndex = _onlineUsers.indexWhere((ou) => ou.userId == userId);
      if (userIndex != -1) {
        // Create new OnlineUser with updated speaking status
        final oldUser = _onlineUsers[userIndex];
        _onlineUsers[userIndex] = OnlineUser(
          id: oldUser.id,
          userId: oldUser.userId,
          channelId: oldUser.channelId,
          socketId: oldUser.socketId,
          isSpeaking: isSpeaking,
          joinedAt: oldUser.joinedAt,
          lastActivity: DateTime.now(),
          user: oldUser.user,
        );
      }
      
      notifyListeners();
      
      if (isSpeaking) {
        _logger.i('$username started speaking');
        onInfo?.call('$username is speaking');
      } else {
        _logger.i('$username stopped speaking');
      }
      
    } catch (e) {
      _logger.e('Error handling user speaking: $e');
    }
  }

  // Handle incoming audio data
  void _handleAudioData(dynamic data) {
    try {
      final userId = data['user_id'] as int;
      final username = data['username'] as String;
      final audioBase64 = data['audio'] as String;
      
      // Decode base64 audio data
      final audioData = base64Decode(audioBase64);
      
      // Call the audio received callback
      onAudioReceived?.call(audioData, userId, username);
      
    } catch (e) {
      _logger.e('Error handling audio data: $e');
    }
  }
}
