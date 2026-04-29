// lib/chat_page/services/announcement_service.dart
import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/semantics.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// Dedicated voice announcement service with its own TTS engine.
/// Completely independent from the AI response TTS to avoid conflicts.
class AnnouncementService {
  static AnnouncementService? _instance;
  static AnnouncementService get instance =>
      _instance ??= AnnouncementService._();
  AnnouncementService._();

  // Own dedicated TTS — never shared with AI responses
  final FlutterTts _tts = FlutterTts();
  bool _initialized = false;
  bool _enabled = true;

  // Simple queue
  final List<String> _queue = [];
  bool _speaking = false;

  /// Call once at app start
  Future<void> initialize() async {
    if (_initialized) return;
    try {
      await _tts.setVolume(1.0);
      await _tts.setSpeechRate(0.45);
      await _tts.setPitch(1.0);
      await _tts.setLanguage('en-US');
      await _tts.awaitSpeakCompletion(true);
      _initialized = true;

      _tts.setCompletionHandler(() {
        _speaking = false;
        _processQueue();
      });

      _tts.setErrorHandler((msg) {
        _speaking = false;
        _processQueue();
      });
    } catch (e) {
      _initialized = true; // Still mark initialized to avoid retry loops
    }
  }

  void setEnabled(bool v) => _enabled = v;

  // ── Announcements ────────────────────────────────────────────────────────

  Future<void> announceReady() =>
      _speak('SuperVision is ready. You can start messaging.', priority: true);

  Future<void> announceNewChat() =>
      _speak('New chat started. You can start messaging.');

  Future<void> announceSettingsOpened() =>
      _speak('Settings opened. Swipe to navigate options.');

  Future<void> announceSettingsClosed() =>
      _speak('Settings closed. Back to chat.');

  Future<void> announceMessagesShown() =>
      _speak('Messages visible. Swipe up to read conversation.');

  Future<void> announceMessagesHidden() =>
      _speak('Messages hidden.');

  Future<void> announceListening() =>
      _speak('Listening. Speak now.', priority: true);

  Future<void> announceStoppedListening() =>
      _speak('Voice input stopped.');

  Future<void> announceMessageSent() =>
      _speak('Message sent. Waiting for response.');

  Future<void> announcePhotoSent() =>
      _speak('Photo captured and sent. Generating response.');

  Future<void> announceResponseReady() =>
      _speak('Response ready.');

  Future<void> announceDownloadStarted() =>
      _speak('Downloading AI model. This may take a few minutes.',
          priority: true);

  Future<void> announceDownloadProgress(int percent) {
    if (percent == 25 || percent == 50 || percent == 75) {
      return _speak('Download $percent percent complete.');
    }
    return Future.value();
  }

  Future<void> announceDownloadComplete() =>
      _speak('Download complete. Setting up SuperVision.', priority: true);

  Future<void> announceError(String msg) =>
      _speak('Error: $msg. Please try again.', priority: true);

  Future<void> announce(String msg) => _speak(msg);

  Future<void> stop() async {
    _queue.clear();
    _speaking = false;
    try { await _tts.stop(); } catch (_) {}
  }

  // ── Internal ─────────────────────────────────────────────────────────────

  Future<void> _speak(String message, {bool priority = false}) async {
    if (!_enabled || message.trim().isEmpty) return;
    if (!_initialized) await initialize();

    if (priority) {
      _queue.clear();
      try { await _tts.stop(); } catch (_) {}
      _speaking = false;
      _queue.insert(0, message);
    } else {
      _queue.add(message);
    }

    _processQueue();
  }

  void _processQueue() {
    if (_speaking || _queue.isEmpty) return;
    final next = _queue.removeAt(0);
    _speaking = true;

    // Speak via dedicated TTS
    _tts.speak(next).catchError((_) {
      _speaking = false;
      _processQueue();
    });

    // Also use system accessibility announcements as backup
    try {
      if (Platform.isAndroid) {
        SemanticsService.announce(next, ui.TextDirection.ltr);
      }
    } catch (_) {}
  }

  void dispose() {
    _queue.clear();
    _tts.stop();
    _instance = null;
  }
}
