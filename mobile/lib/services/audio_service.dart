import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:logger/logger.dart';

class AudioService extends ChangeNotifier {
  final Logger _logger = Logger();
  final AudioRecorder _recorder = AudioRecorder();
  final AudioPlayer _player = AudioPlayer();
  
  bool _isRecording = false;
  bool _isPlaying = false;
  bool _hasPermission = false;
  StreamSubscription<Uint8List>? _recordingSubscription;

  // Callbacks
  Function(Uint8List audioData)? onAudioData;
  Function(String message)? onError;

  // Getters
  bool get isRecording => _isRecording;
  bool get isPlaying => _isPlaying;
  bool get hasPermission => _hasPermission;

  AudioService() {
    _checkPermissions();
  }

  // Check and request audio permissions
  Future<void> _checkPermissions() async {
    final status = await Permission.microphone.status;
    
    if (status.isDenied) {
      final result = await Permission.microphone.request();
      _hasPermission = result.isGranted;
    } else {
      _hasPermission = status.isGranted;
    }
    
    notifyListeners();
    _logger.i('Microphone permission: $_hasPermission');
  }

  // Request permissions
  Future<bool> requestPermissions() async {
    await _checkPermissions();
    return _hasPermission;
  }

  // Start recording audio
  Future<bool> startRecording() async {
    if (_isRecording) {
      _logger.w('Already recording');
      return false;
    }

    if (!_hasPermission) {
      final granted = await requestPermissions();
      if (!granted) {
        onError?.call('Microphone permission required');
        return false;
      }
    }

    try {
      // Check if recorder is available
      if (!await _recorder.hasPermission()) {
        onError?.call('Microphone permission denied');
        return false;
      }

      // Start recording with stream
      final stream = await _recorder.startStream(
        const RecordConfig(
          encoder: AudioEncoder.pcm16bits,
          sampleRate: 16000,
          numChannels: 1,
          bitRate: 128000,
        ),
      );

      _recordingSubscription = stream.listen(
        (audioData) {
          // Send audio data to callback
          onAudioData?.call(audioData);
        },
        onError: (error) {
          _logger.e('Recording stream error: $error');
          onError?.call('Recording error: $error');
          stopRecording();
        },
      );

      _isRecording = true;
      notifyListeners();
      _logger.i('Started recording');
      return true;

    } catch (e) {
      _logger.e('Failed to start recording: $e');
      onError?.call('Failed to start recording');
      return false;
    }
  }

  // Stop recording audio
  Future<void> stopRecording() async {
    if (!_isRecording) {
      return;
    }

    try {
      await _recordingSubscription?.cancel();
      _recordingSubscription = null;
      
      await _recorder.stop();
      
      _isRecording = false;
      notifyListeners();
      _logger.i('Stopped recording');

    } catch (e) {
      _logger.e('Failed to stop recording: $e');
      onError?.call('Failed to stop recording');
    }
  }

  // Play audio data
  Future<void> playAudioData(Uint8List audioData) async {
    try {
      // Stop any current playback
      await _player.stop();
      
      _isPlaying = true;
      notifyListeners();

      // Play audio from bytes
      await _player.play(BytesSource(audioData));
      
      // Listen for completion
      _player.onPlayerComplete.listen((_) {
        _isPlaying = false;
        notifyListeners();
      });

    } catch (e) {
      _logger.e('Failed to play audio: $e');
      onError?.call('Failed to play audio');
      _isPlaying = false;
      notifyListeners();
    }
  }

  // Stop audio playback
  Future<void> stopPlayback() async {
    try {
      await _player.stop();
      _isPlaying = false;
      notifyListeners();
    } catch (e) {
      _logger.e('Failed to stop playback: $e');
    }
  }

  // Dispose resources
  @override
  void dispose() {
    _recordingSubscription?.cancel();
    _recorder.dispose();
    _player.dispose();
    super.dispose();
  }
}
