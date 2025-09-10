import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:logger/logger.dart';

import '../models/user.dart';
import '../utils/constants.dart';

class AuthService extends ChangeNotifier {
  final SharedPreferences _prefs;
  final Logger _logger = Logger();
  
  User? _currentUser;
  String? _accessToken;
  String? _refreshToken;
  bool _isLoading = false;

  AuthService(this._prefs) {
    _loadTokensFromStorage();
  }

  // Getters
  User? get currentUser => _currentUser;
  String? get accessToken => _accessToken;
  bool get isAuthenticated => _accessToken != null && _currentUser != null;
  bool get isLoading => _isLoading;

  // Load tokens from storage
  void _loadTokensFromStorage() {
    _accessToken = _prefs.getString('access_token');
    _refreshToken = _prefs.getString('refresh_token');
    
    final userJson = _prefs.getString('current_user');
    if (userJson != null) {
      try {
        _currentUser = User.fromJson(json.decode(userJson));
      } catch (e) {
        _logger.e('Error loading user from storage: $e');
        _clearTokens();
      }
    }
    
    if (_accessToken != null && _currentUser != null) {
      _validateToken();
    }
  }

  // Save tokens to storage
  Future<void> _saveTokensToStorage() async {
    if (_accessToken != null) {
      await _prefs.setString('access_token', _accessToken!);
    }
    if (_refreshToken != null) {
      await _prefs.setString('refresh_token', _refreshToken!);
    }
    if (_currentUser != null) {
      await _prefs.setString('current_user', json.encode(_currentUser!.toJson()));
    }
  }

  // Clear tokens from storage
  Future<void> _clearTokens() async {
    _accessToken = null;
    _refreshToken = null;
    _currentUser = null;
    
    await _prefs.remove('access_token');
    await _prefs.remove('refresh_token');
    await _prefs.remove('current_user');
    
    notifyListeners();
  }

  // Login
  Future<bool> login(String username, String password) async {
    _isLoading = true;
    notifyListeners();

    try {
      final response = await http.post(
        Uri.parse('${Constants.apiBaseUrl}/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'username': username,
          'password': password,
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        _accessToken = data['access_token'];
        _refreshToken = data['refresh_token'];
        _currentUser = User.fromJson(data['user']);
        
        await _saveTokensToStorage();
        
        _logger.i('Login successful for user: ${_currentUser!.username}');
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        final error = json.decode(response.body);
        _logger.e('Login failed: ${error['error']}');
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _logger.e('Login error: $e');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Logout
  Future<void> logout() async {
    try {
      if (_accessToken != null) {
        await http.post(
          Uri.parse('${Constants.apiBaseUrl}/auth/logout'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $_accessToken',
          },
        );
      }
    } catch (e) {
      _logger.e('Logout error: $e');
    } finally {
      await _clearTokens();
    }
  }

  // Refresh token
  Future<bool> refreshToken() async {
    if (_refreshToken == null) {
      await _clearTokens();
      return false;
    }

    try {
      final response = await http.post(
        Uri.parse('${Constants.apiBaseUrl}/auth/refresh'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_refreshToken',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        _accessToken = data['access_token'];
        await _saveTokensToStorage();
        notifyListeners();
        return true;
      } else {
        await _clearTokens();
        return false;
      }
    } catch (e) {
      _logger.e('Token refresh error: $e');
      await _clearTokens();
      return false;
    }
  }

  // Validate current token
  Future<void> _validateToken() async {
    if (_accessToken == null) return;

    try {
      final response = await http.get(
        Uri.parse('${Constants.apiBaseUrl}/auth/me'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_accessToken',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        _currentUser = User.fromJson(data['user']);
        await _saveTokensToStorage();
        notifyListeners();
      } else if (response.statusCode == 401) {
        // Token expired, try to refresh
        final refreshed = await refreshToken();
        if (!refreshed) {
          await _clearTokens();
        }
      }
    } catch (e) {
      _logger.e('Token validation error: $e');
    }
  }

  // Get authorization headers
  Map<String, String> getAuthHeaders() {
    return {
      'Content-Type': 'application/json',
      if (_accessToken != null) 'Authorization': 'Bearer $_accessToken',
    };
  }
}
