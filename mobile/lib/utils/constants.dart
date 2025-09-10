class Constants {
  // API Configuration
  static const String apiBaseUrl = 'https://yourdomain.com/api';
  static const String websocketUrl = 'wss://yourdomain.com/api/ws';
  
  // For development, use local URLs
  static const String devApiBaseUrl = 'http://localhost:5000/api';
  static const String devWebsocketUrl = 'ws://localhost:5000/api/ws';
  
  // Use development URLs in debug mode
  static String get currentApiBaseUrl => 
      const bool.fromEnvironment('dart.vm.product') ? apiBaseUrl : devApiBaseUrl;
  
  static String get currentWebsocketUrl => 
      const bool.fromEnvironment('dart.vm.product') ? websocketUrl : devWebsocketUrl;
  
  // Audio Configuration
  static const int audioSampleRate = 16000;
  static const int audioChannels = 1;
  static const int audioBitRate = 128000;
  
  // UI Configuration
  static const double defaultPadding = 16.0;
  static const double smallPadding = 8.0;
  static const double largePadding = 24.0;
  
  static const double defaultBorderRadius = 8.0;
  static const double largeBorderRadius = 16.0;
  
  // Animation Durations
  static const Duration shortAnimation = Duration(milliseconds: 200);
  static const Duration mediumAnimation = Duration(milliseconds: 400);
  static const Duration longAnimation = Duration(milliseconds: 600);
  
  // Network Timeouts
  static const Duration networkTimeout = Duration(seconds: 30);
  static const Duration websocketTimeout = Duration(seconds: 10);
}
