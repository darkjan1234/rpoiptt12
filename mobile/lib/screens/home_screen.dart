import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/auth_service.dart';
import '../services/websocket_service.dart';
import '../services/audio_service.dart';
import '../widgets/channel_list.dart';
import '../widgets/ptt_button.dart';
import '../widgets/online_users_list.dart';
import '../utils/constants.dart';
import 'login_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  int _currentIndex = 0;
  String? _statusMessage;
  bool _isConnecting = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeServices();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final websocketService = Provider.of<WebSocketService>(context, listen: false);
    final authService = Provider.of<AuthService>(context, listen: false);
    
    switch (state) {
      case AppLifecycleState.resumed:
        // Reconnect when app comes to foreground
        if (authService.isAuthenticated && !websocketService.isConnected) {
          _connectWebSocket();
        }
        break;
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
        // Optionally disconnect when app goes to background
        break;
      case AppLifecycleState.detached:
        websocketService.disconnect();
        break;
      case AppLifecycleState.hidden:
        break;
    }
  }

  Future<void> _initializeServices() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final audioService = Provider.of<AudioService>(context, listen: false);
    
    // Request audio permissions
    await audioService.requestPermissions();
    
    // Setup audio service callbacks
    audioService.onError = (message) {
      _showMessage(message, isError: true);
    };
    
    // Connect to WebSocket if authenticated
    if (authService.isAuthenticated) {
      await _connectWebSocket();
    }
  }

  Future<void> _connectWebSocket() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final websocketService = Provider.of<WebSocketService>(context, listen: false);
    final audioService = Provider.of<AudioService>(context, listen: false);
    
    if (_isConnecting || websocketService.isConnected) {
      return;
    }
    
    setState(() {
      _isConnecting = true;
      _statusMessage = 'Connecting to server...';
    });
    
    // Setup WebSocket callbacks
    websocketService.onError = (message) {
      _showMessage(message, isError: true);
    };
    
    websocketService.onInfo = (message) {
      _showMessage(message);
    };
    
    websocketService.onAudioReceived = (audioData, userId, username) {
      // Play received audio
      audioService.playAudioData(audioData);
    };
    
    // Connect to WebSocket
    await websocketService.connect(authService.accessToken!);
    
    setState(() {
      _isConnecting = false;
      _statusMessage = null;
    });
  }

  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) return;
    
    setState(() {
      _statusMessage = message;
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Theme.of(context).colorScheme.error : null,
        duration: const Duration(seconds: 3),
      ),
    );
    
    // Clear status message after a delay
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _statusMessage = null;
        });
      }
    });
  }

  Future<void> _logout() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final websocketService = Provider.of<WebSocketService>(context, listen: false);
    
    // Disconnect WebSocket
    websocketService.disconnect();
    
    // Logout
    await authService.logout();
    
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('PTT Mobile'),
        actions: [
          // Connection status
          Consumer<WebSocketService>(
            builder: (context, websocketService, _) {
              return Container(
                margin: const EdgeInsets.only(right: 8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      websocketService.isConnected 
                          ? Icons.wifi 
                          : _isConnecting 
                              ? Icons.wifi_off 
                              : Icons.wifi_off,
                      color: websocketService.isConnected 
                          ? Colors.green 
                          : _isConnecting 
                              ? Colors.orange 
                              : Colors.red,
                      size: 20,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      websocketService.isConnected 
                          ? 'Online' 
                          : _isConnecting 
                              ? 'Connecting...' 
                              : 'Offline',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              );
            },
          ),
          
          // Menu
          PopupMenuButton<String>(
            onSelected: (value) {
              switch (value) {
                case 'logout':
                  _logout();
                  break;
                case 'reconnect':
                  _connectWebSocket();
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'reconnect',
                child: Row(
                  children: [
                    Icon(Icons.refresh),
                    SizedBox(width: 8),
                    Text('Reconnect'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout),
                    SizedBox(width: 8),
                    Text('Logout'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      
      body: Column(
        children: [
          // Status message
          if (_statusMessage != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(Constants.smallPadding),
              color: Theme.of(context).colorScheme.surfaceVariant,
              child: Text(
                _statusMessage!,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          
          // Main content
          Expanded(
            child: IndexedStack(
              index: _currentIndex,
              children: const [
                ChannelList(),
                OnlineUsersList(),
              ],
            ),
          ),
          
          // PTT Button (always visible)
          const PTTButton(),
        ],
      ),
      
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.chat),
            label: 'Channels',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.people),
            label: 'Users',
          ),
        ],
      ),
    );
  }
}
