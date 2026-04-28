// lib/chat_page/handlers/keyboard_handler.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import '../widgets/prompt_bar.dart';
import '../widgets/semantic_button_registry.dart';

/// Custom intent for function key shortcuts that bypass text field focus
class GameIntent extends Intent {
  const GameIntent(this.key);
  final LogicalKeyboardKey key;
}

/// 8BitDo Micro gamepad button → SuperVision action mapping:
///
///  Gamepad Button  │  F-Key  │  SuperVision Action
/// ─────────────────┼─────────┼─────────────────────
///  R1              │  F1     │  Send with photo
///  R2              │  F2     │  Toggle voice input
///  Start           │  F3     │  New chat
///  X               │  F4     │  What is this?
///  A               │  F5     │  Describe room
///  Y               │  F6     │  Read text
///  B               │  F7     │  Tell me what you see
///  Select          │  F8     │  Toggle settings
///  L1              │  F9     │  Send text only
///  L2              │  F10    │  Toggle messages
///
/// Cross-platform keyboard handler with accessibility support for blind users.
/// Handles F-key / gamepad shortcuts, arrow navigation, and platform-specific
/// activation patterns.
class KeyboardHandler {
  final BuildContext _context;
  final GlobalKey<PromptBarState> _promptBarKey;
  final VoidCallback _onToggleMessages;
  final VoidCallback _onToggleSettings;
  final VoidCallback _onNewChat;
  final VoidCallback _onQuickAction1;
  final VoidCallback _onQuickAction2;
  final VoidCallback _onQuickAction3;
  final VoidCallback _onQuickAction4;
  final VoidCallback _onToggleVoice;

  /// Prevent duplicate key event processing
  final Set<LogicalKeyboardKey> _pressedKeys = <LogicalKeyboardKey>{};

  /// Platform-specific behavior flags
  bool get _isIOS => !kIsWeb && Platform.isIOS;

  KeyboardHandler({
    required BuildContext context,
    required GlobalKey<PromptBarState> promptBarKey,
    required VoidCallback onToggleMessages,
    required VoidCallback onToggleCamera,
    required VoidCallback onToggleSettings,
    required VoidCallback onNewChat,
    required VoidCallback onQuickAction1,
    required VoidCallback onQuickAction2,
    required VoidCallback onQuickAction3,
    required VoidCallback onQuickAction4,
    required VoidCallback onToggleVoice,
  }) : _context = context,
        _promptBarKey = promptBarKey,
        _onToggleMessages = onToggleMessages,
        _onToggleSettings = onToggleSettings,
        _onNewChat = onNewChat,
        _onQuickAction1 = onQuickAction1,
        _onQuickAction2 = onQuickAction2,
        _onQuickAction3 = onQuickAction3,
        _onQuickAction4 = onQuickAction4,
        _onToggleVoice = onToggleVoice;

  /// Process keyboard / gamepad shortcuts with ghost event prevention
  void onShortcut(LogicalKeyboardKey key) {
    // Prevent processing ghost events (key not actually pressed)
    if (!HardwareKeyboard.instance.logicalKeysPressed.contains(key)) {
      debugPrint('KeyboardHandler: Ignoring ghost key event for $key');
      return;
    }

    // Debounce: prevent rapid duplicate key processing
    if (_pressedKeys.contains(key)) {
      debugPrint('KeyboardHandler: Key $key already being processed');
      return;
    }

    _pressedKeys.add(key);

    try {
      switch (key) {
      // ── R1 ──────────────────────────────────────────────────────────────
        case LogicalKeyboardKey.f1:
          _promptBarKey.currentState?.sendWithPhoto(); // Send with photo
          break;

      // ── R2 ──────────────────────────────────────────────────────────────
        case LogicalKeyboardKey.f2:
          _onToggleVoice(); // Toggle voice input
          break;

      // ── Start ────────────────────────────────────────────────────────────
        case LogicalKeyboardKey.f3:
          _onNewChat(); // New chat
          break;

      // ── X ────────────────────────────────────────────────────────────────
        case LogicalKeyboardKey.f4:
          _onQuickAction3(); // What is this?
          break;

      // ── A ────────────────────────────────────────────────────────────────
        case LogicalKeyboardKey.f5:
          _onQuickAction1(); // Describe room
          break;

      // ── Y ────────────────────────────────────────────────────────────────
        case LogicalKeyboardKey.f6:
          _onQuickAction4(); // Read text
          break;

      // ── B ────────────────────────────────────────────────────────────────
        case LogicalKeyboardKey.f7:
          _onQuickAction2(); // Tell me what you see
          break;

      // ── Select ───────────────────────────────────────────────────────────
        case LogicalKeyboardKey.f8:
          _onToggleSettings(); // Toggle settings
          break;

      // ── L1 ───────────────────────────────────────────────────────────────
        case LogicalKeyboardKey.f9:
          _promptBarKey.currentState?.sendTextOnly(); // Send text only
          break;

      // ── L2 ───────────────────────────────────────────────────────────────
        case LogicalKeyboardKey.f10:
          _onToggleMessages(); // Toggle messages
          break;

      // ── Accessibility navigation ─────────────────────────────────────────
        case LogicalKeyboardKey.arrowUp:
        case LogicalKeyboardKey.arrowLeft:
          FocusScope.of(_context).previousFocus();
          break;
        case LogicalKeyboardKey.arrowDown:
        case LogicalKeyboardKey.arrowRight:
          FocusScope.of(_context).nextFocus();
          break;
        case LogicalKeyboardKey.enter:
        case LogicalKeyboardKey.select:
        case LogicalKeyboardKey.space:
          if (_shouldActivateButton()) {
            _activateCurrentButton();
          }
          break;
      }
    } finally {
      // Debounce cleanup: allow key to be processed again after delay
      Future.delayed(const Duration(milliseconds: 100), () {
        _pressedKeys.remove(key);
      });
    }
  }

  /// Platform-specific button activation logic (iOS VoiceOver vs Android TalkBack)
  bool _shouldActivateButton() {
    if (_isIOS) {
      // iOS VoiceOver requires Ctrl + Alt + Space for activation
      return HardwareKeyboard.instance.isControlPressed &&
          HardwareKeyboard.instance.isAltPressed;
    } else {
      // Android TalkBack: Enter, Space, or Select activate buttons
      return true;
    }
  }

  /// Activate currently focused semantic button
  void _activateCurrentButton() {
    SemanticButtonRegistry.invokeCurrentSemanticTap();
  }

  /// Create validated action handler with error handling
  CallbackAction<GameIntent> _createGameAction() {
    return CallbackAction<GameIntent>(
      onInvoke: (intent) {
        try {
          final key = intent.key;

          // Double-check key validity at action level
          if (!HardwareKeyboard.instance.logicalKeysPressed.contains(key)) {
            debugPrint('GameIntent: Ignoring invalid key event for $key');
            return null;
          }

          onShortcut(key);
          return null;
        } catch (e) {
          debugPrint('GameIntent error: $e');
          return null;
        }
      },
    );
  }

  /// Platform-specific keyboard shortcut mappings
  Map<LogicalKeySet, Intent> get shortcuts => {
    if (_isIOS) ...{
      // iOS: VoiceOver-specific navigation shortcuts
      LogicalKeySet(LogicalKeyboardKey.arrowDown): const NextFocusIntent(),
      LogicalKeySet(LogicalKeyboardKey.arrowRight): const NextFocusIntent(),
      LogicalKeySet(LogicalKeyboardKey.arrowUp): const PreviousFocusIntent(),
      LogicalKeySet(LogicalKeyboardKey.arrowLeft): const PreviousFocusIntent(),
      LogicalKeySet(
        LogicalKeyboardKey.control,
        LogicalKeyboardKey.alt,
        LogicalKeyboardKey.space,
      ): const ActivateIntent(),
    } else ...{
      // Android: TalkBack-compatible navigation
      LogicalKeySet(LogicalKeyboardKey.arrowDown): const NextFocusIntent(),
      LogicalKeySet(LogicalKeyboardKey.arrowRight): const NextFocusIntent(),
      LogicalKeySet(LogicalKeyboardKey.arrowUp): const PreviousFocusIntent(),
      LogicalKeySet(LogicalKeyboardKey.arrowLeft): const PreviousFocusIntent(),
      LogicalKeySet(LogicalKeyboardKey.enter): const ActivateIntent(),
      LogicalKeySet(LogicalKeyboardKey.select): const ActivateIntent(),
      LogicalKeySet(LogicalKeyboardKey.space): const ActivateIntent(),
    },

    // 8BitDo Micro gamepad button shortcuts (cross-platform)
    LogicalKeySet(LogicalKeyboardKey.f1):  const GameIntent(LogicalKeyboardKey.f1),  // R1  → Send with photo
    LogicalKeySet(LogicalKeyboardKey.f2):  const GameIntent(LogicalKeyboardKey.f2),  // R2  → Toggle voice
    LogicalKeySet(LogicalKeyboardKey.f3):  const GameIntent(LogicalKeyboardKey.f3),  // Start → New chat
    LogicalKeySet(LogicalKeyboardKey.f4):  const GameIntent(LogicalKeyboardKey.f4),  // X   → What is this?
    LogicalKeySet(LogicalKeyboardKey.f5):  const GameIntent(LogicalKeyboardKey.f5),  // A   → Describe room
    LogicalKeySet(LogicalKeyboardKey.f6):  const GameIntent(LogicalKeyboardKey.f6),  // Y   → Read text
    LogicalKeySet(LogicalKeyboardKey.f7):  const GameIntent(LogicalKeyboardKey.f7),  // B   → Tell me what you see
    LogicalKeySet(LogicalKeyboardKey.f8):  const GameIntent(LogicalKeyboardKey.f8),  // Select → Toggle settings
    LogicalKeySet(LogicalKeyboardKey.f9):  const GameIntent(LogicalKeyboardKey.f9),  // L1  → Send text only
    LogicalKeySet(LogicalKeyboardKey.f10): const GameIntent(LogicalKeyboardKey.f10), // L2  → Toggle messages
  };

  /// Platform-specific action handlers with accessibility integration
  Map<Type, Action<Intent>> get actions => {
    if (_isIOS)
      ActivateIntent: CallbackAction<ActivateIntent>(
        onInvoke: (_) {
          try {
            SemanticButtonRegistry.invokeCurrentSemanticTap();
          } catch (e) {
            debugPrint('ActivateIntent error: $e');
          }
          return null;
        },
      )
    else
      ActivateIntent: CallbackAction<ActivateIntent>(
        onInvoke: (_) {
          try {
            final activated = SemanticButtonRegistry.invokeCurrentSemanticTap();
            if (!activated) {
              debugPrint('No semantic tap registered, letting system handle');
            }
          } catch (e) {
            debugPrint('ActivateIntent error: $e');
          }
          return null;
        },
      ),

    // Gamepad (F-key) handler
    GameIntent: _createGameAction(),
  };

  void dispose() {
    _pressedKeys.clear();
  }
}