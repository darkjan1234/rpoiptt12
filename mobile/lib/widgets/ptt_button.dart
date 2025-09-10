import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../services/websocket_service.dart';
import '../services/audio_service.dart';
import '../utils/constants.dart';

class PTTButton extends StatefulWidget {
  const PTTButton({Key? key}) : super(key: key);

  @override
  State<PTTButton> createState() => _PTTButtonState();
}

class _PTTButtonState extends State<PTTButton> with TickerProviderStateMixin {
  bool _isPressed = false;
  bool _isRecording = false;
  late AnimationController _pulseController;
  late AnimationController _scaleController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    
    // Setup animations
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    
    _scaleController = AnimationController(
      duration: Constants.shortAnimation,
      vsync: this,
    );
    
    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));
    
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.95,
    ).animate(CurvedAnimation(
      parent: _scaleController,
      curve: Curves.easeInOut,
    ));
    
    // Setup audio service callback
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final audioService = Provider.of<AudioService>(context, listen: false);
      audioService.onAudioData = _onAudioData;
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _scaleController.dispose();
    super.dispose();
  }

  void _onAudioData(Uint8List audioData) {
    // Send audio data to WebSocket
    final websocketService = Provider.of<WebSocketService>(context, listen: false);
    websocketService.sendAudioData(audioData);
  }

  Future<void> _startRecording() async {
    final websocketService = Provider.of<WebSocketService>(context, listen: false);
    final audioService = Provider.of<AudioService>(context, listen: false);
    
    // Check if connected to a channel
    if (!websocketService.isConnected || websocketService.currentChannel == null) {
      _showError('Please join a channel first');
      return;
    }
    
    // Check audio permissions
    if (!audioService.hasPermission) {
      final granted = await audioService.requestPermissions();
      if (!granted) {
        _showError('Microphone permission required');
        return;
      }
    }
    
    // Start recording
    final started = await audioService.startRecording();
    if (started) {
      setState(() {
        _isRecording = true;
      });
      
      // Notify server
      websocketService.startSpeaking();
      
      // Start pulse animation
      _pulseController.repeat(reverse: true);
      
      // Haptic feedback
      HapticFeedback.lightImpact();
    } else {
      _showError('Failed to start recording');
    }
  }

  Future<void> _stopRecording() async {
    final websocketService = Provider.of<WebSocketService>(context, listen: false);
    final audioService = Provider.of<AudioService>(context, listen: false);
    
    // Stop recording
    await audioService.stopRecording();
    
    setState(() {
      _isRecording = false;
    });
    
    // Notify server
    websocketService.stopSpeaking();
    
    // Stop pulse animation
    _pulseController.stop();
    _pulseController.reset();
    
    // Haptic feedback
    HapticFeedback.lightImpact();
  }

  void _onPanDown(DragDownDetails details) {
    setState(() {
      _isPressed = true;
    });
    _scaleController.forward();
    _startRecording();
  }

  void _onPanEnd(DragEndDetails details) {
    setState(() {
      _isPressed = false;
    });
    _scaleController.reverse();
    _stopRecording();
  }

  void _onPanCancel() {
    setState(() {
      _isPressed = false;
    });
    _scaleController.reverse();
    _stopRecording();
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Theme.of(context).colorScheme.error,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<WebSocketService, AudioService>(
      builder: (context, websocketService, audioService, _) {
        final isConnected = websocketService.isConnected;
        final hasChannel = websocketService.currentChannel != null;
        final hasPermission = audioService.hasPermission;
        
        return Container(
          padding: const EdgeInsets.all(Constants.defaultPadding),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Channel info
              if (hasChannel)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: Constants.defaultPadding,
                    vertical: Constants.smallPadding,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceVariant,
                    borderRadius: BorderRadius.circular(Constants.defaultBorderRadius),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.chat,
                        size: 16,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        websocketService.currentChannel!.name,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              
              const SizedBox(height: Constants.smallPadding),
              
              // PTT Button
              GestureDetector(
                onPanDown: isConnected && hasChannel && hasPermission ? _onPanDown : null,
                onPanEnd: _onPanEnd,
                onPanCancel: _onPanCancel,
                child: AnimatedBuilder(
                  animation: Listenable.merge([_pulseAnimation, _scaleAnimation]),
                  builder: (context, child) {
                    return Transform.scale(
                      scale: _scaleAnimation.value,
                      child: Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _getButtonColor(isConnected, hasChannel, hasPermission),
                          boxShadow: [
                            BoxShadow(
                              color: _getButtonColor(isConnected, hasChannel, hasPermission)
                                  .withOpacity(0.3),
                              blurRadius: _isRecording ? _pulseAnimation.value * 20 : 10,
                              spreadRadius: _isRecording ? _pulseAnimation.value * 5 : 2,
                            ),
                          ],
                        ),
                        child: Icon(
                          _isRecording ? Icons.mic : Icons.mic_none,
                          size: 48,
                          color: Colors.white,
                        ),
                      ),
                    );
                  },
                ),
              ),
              
              const SizedBox(height: Constants.smallPadding),
              
              // Status text
              Text(
                _getStatusText(isConnected, hasChannel, hasPermission),
                style: Theme.of(context).textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
              
              // Recording indicator
              if (_isRecording)
                Container(
                  margin: const EdgeInsets.only(top: Constants.smallPadding),
                  padding: const EdgeInsets.symmetric(
                    horizontal: Constants.defaultPadding,
                    vertical: Constants.smallPadding,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.errorContainer,
                    borderRadius: BorderRadius.circular(Constants.defaultBorderRadius),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.red,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Recording...',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onErrorContainer,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Color _getButtonColor(bool isConnected, bool hasChannel, bool hasPermission) {
    if (!isConnected) {
      return Colors.grey;
    } else if (!hasChannel) {
      return Colors.orange;
    } else if (!hasPermission) {
      return Colors.red;
    } else if (_isRecording) {
      return Colors.red;
    } else {
      return Theme.of(context).colorScheme.primary;
    }
  }

  String _getStatusText(bool isConnected, bool hasChannel, bool hasPermission) {
    if (!isConnected) {
      return 'Not connected to server';
    } else if (!hasChannel) {
      return 'Join a channel to start talking';
    } else if (!hasPermission) {
      return 'Microphone permission required';
    } else if (_isRecording) {
      return 'Release to stop talking';
    } else {
      return 'Hold to talk';
    }
  }
}
