// lib/chat_page/handlers/keyboard_handler.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import '../widgets/prompt_bar.dart';
import '../widgets/semantic_button_registry.dart';

/// Custom intent for gamepad button shortcuts that bypass text field focus
class GameIntent extends Intent {
  const GameIntent(this.key);
  final LogicalKeyboardKey key;
}

/// 8BitDo Micro gamepad button → SuperVision action mapping:
///
///  Gamepad Button   │  getevent code   │  SuperVision Action
/// ──────────────────┼──────────────────┼──────────────────────────
///  R1  (BTN_TR)     │  gameButtonRight1│  Send with photo
///  R2  (ABS_RZ)     │  gameButtonRight2│  Toggle voice input
///  Start            │  gameButtonStart │  New chat
///  X   (BTN_WEST)   │  gameButtonX     │  What is this?
///  A   (BTN_GAMEPAD)│  gameButtonA     │  Describe room
///  Y   (BTN_NORTH)  │  gameButtonY     │  Read text
///  B   (BTN_EAST)   │  gameButtonB     │  Tell me what you see
///  Select           │  gameButtonSelect│  Toggle settings
///  L1  (BTN_TL)     │  gameButtonLeft1 │  Send text only
///  L2  (ABS_Z)      │  gameButtonLeft2 │  Hide / show messages
///
class KeyboardHandler {
  final BuildContext _context;
  final GlobalKey<PromptBarState> _promptBarKey;
  final VoidCallback _onToggleMessages;   // L2  → hide/show messages
  final VoidCallback _onToggleSettings;   // Select → open/close settings
  final VoidCallback _onNewChat;          // Start → new chat
  final VoidCallback _onQuickAction1;     // A → describe room
  final VoidCallback _onQuickAction2;     // B → tell me what you see
  final VoidCallback _onQuickAction3;     // X → what is this?
  final VoidCallback _onQuickAction4;     // Y → read text
  final VoidCallback _onToggleVoice;      // R2 → toggle voice input

  /// Prevent duplicate key event processing
  final Set<LogicalKeyboardKey> _pressedKeys = <LogicalKeyboardKey>{};

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

  /// Process gamepad / keyboard shortcuts with ghost event prevention
  void onShortcut(LogicalKeyboardKey key) {
    if (!HardwareKeyboard.instance.logicalKeysPressed.contains(key)) {
      debugPrint('KeyboardHandler: Ignoring ghost key event for $key');
      return;
    }

    if (_pressedKeys.contains(key)) {
      debugPrint('KeyboardHandler: Key $key already being processed');
      return;
    }

    _pressedKeys.add(key);

    try {
      // ── 8BitDo Micro gamepad buttons ──────────────────────────────────────
      if (key == LogicalKeyboardKey.gameButtonRight1) {
        // R1 → Send with photo
        _promptBarKey.currentState?.sendWithPhoto();

      } else if (key == LogicalKeyboardKey.gameButtonRight2 ||
          key == LogicalKeyboardKey.gameButtonThumbRight) {
        // R2 → Toggle voice input
        // Note: R2 (ABS_RZ) is an analog trigger — Flutter may fire it as
        // gameButtonRight2 OR gameButtonThumbRight depending on Android version.
        // Both are mapped here as a fallback.
        _onToggleVoice();

      } else if (key == LogicalKeyboardKey.gameButtonStart) {
        // Start → New chat
        _onNewChat();

      } else if (key == LogicalKeyboardKey.gameButtonX) {
        // X → What is this?
        _onQuickAction3();

      } else if (key == LogicalKeyboardKey.gameButtonA) {
        // A → Describe room
        _onQuickAction1();

      } else if (key == LogicalKeyboardKey.gameButtonY) {
        // Y → Read text
        _onQuickAction4();

      } else if (key == LogicalKeyboardKey.gameButtonB) {
        // B → Tell me what you see
        _onQuickAction2();

      } else if (key == LogicalKeyboardKey.gameButtonSelect) {
        // Select → Toggle settings
        _onToggleSettings();

      } else if (key == LogicalKeyboardKey.gameButtonLeft1) {
        // L1 → Send text only
        _promptBarKey.currentState?.sendTextOnly();

      } else if (key == LogicalKeyboardKey.gameButtonLeft2 ||
          key == LogicalKeyboardKey.gameButtonThumbLeft) {
        // L2 → Hide / show messages
        // Same dual-mapping fallback as R2 above.
        _onToggleMessages();

      } else if (key == LogicalKeyboardKey.gameButtonMode) {
        // Mode → Hide / show messages (extra fallback)
        _onToggleMessages();

        // ── Accessibility navigation ─────────────────────────────────────────
      } else if (key == LogicalKeyboardKey.arrowUp ||
          key == LogicalKeyboardKey.arrowLeft) {
        FocusScope.of(_context).previousFocus();

      } else if (key == LogicalKeyboardKey.arrowDown ||
          key == LogicalKeyboardKey.arrowRight) {
        FocusScope.of(_context).nextFocus();

      } else if (key == LogicalKeyboardKey.enter ||
          key == LogicalKeyboardKey.select ||
          key == LogicalKeyboardKey.space) {
        if (_shouldActivateButton()) {
          _activateCurrentButton();
        }
      }
    } finally {
      Future.delayed(const Duration(milliseconds: 100), () {
        _pressedKeys.remove(key);
      });
    }
  }

  bool _shouldActivateButton() {
    if (_isIOS) {
      return HardwareKeyboard.instance.isControlPressed &&
          HardwareKeyboard.instance.isAltPressed;
    } else {
      return true;
    }
  }

  void _activateCurrentButton() {
    SemanticButtonRegistry.invokeCurrentSemanticTap();
  }

  CallbackAction<GameIntent> _createGameAction() {
    return CallbackAction<GameIntent>(
      onInvoke: (intent) {
        try {
          final key = intent.key;
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

  Map<LogicalKeySet, Intent> get shortcuts => {
    if (_isIOS) ...{
      LogicalKeySet(LogicalKeyboardKey.arrowDown):  const NextFocusIntent(),
      LogicalKeySet(LogicalKeyboardKey.arrowRight): const NextFocusIntent(),
      LogicalKeySet(LogicalKeyboardKey.arrowUp):    const PreviousFocusIntent(),
      LogicalKeySet(LogicalKeyboardKey.arrowLeft):  const PreviousFocusIntent(),
      LogicalKeySet(
        LogicalKeyboardKey.control,
        LogicalKeyboardKey.alt,
        LogicalKeyboardKey.space,
      ): const ActivateIntent(),
    } else ...{
      LogicalKeySet(LogicalKeyboardKey.arrowDown):  const NextFocusIntent(),
      LogicalKeySet(LogicalKeyboardKey.arrowRight): const NextFocusIntent(),
      LogicalKeySet(LogicalKeyboardKey.arrowUp):    const PreviousFocusIntent(),
      LogicalKeySet(LogicalKeyboardKey.arrowLeft):  const PreviousFocusIntent(),
      LogicalKeySet(LogicalKeyboardKey.enter):  const ActivateIntent(),
      LogicalKeySet(LogicalKeyboardKey.select): const ActivateIntent(),
      LogicalKeySet(LogicalKeyboardKey.space):  const ActivateIntent(),
    },

    // 8BitDo Micro gamepad buttons
    LogicalKeySet(LogicalKeyboardKey.gameButtonRight1):    const GameIntent(LogicalKeyboardKey.gameButtonRight1),    // R1
    LogicalKeySet(LogicalKeyboardKey.gameButtonRight2):    const GameIntent(LogicalKeyboardKey.gameButtonRight2),    // R2
    LogicalKeySet(LogicalKeyboardKey.gameButtonThumbRight):const GameIntent(LogicalKeyboardKey.gameButtonThumbRight),// R2 fallback
    LogicalKeySet(LogicalKeyboardKey.gameButtonStart):     const GameIntent(LogicalKeyboardKey.gameButtonStart),     // Start
    LogicalKeySet(LogicalKeyboardKey.gameButtonX):         const GameIntent(LogicalKeyboardKey.gameButtonX),         // X
    LogicalKeySet(LogicalKeyboardKey.gameButtonA):         const GameIntent(LogicalKeyboardKey.gameButtonA),         // A
    LogicalKeySet(LogicalKeyboardKey.gameButtonY):         const GameIntent(LogicalKeyboardKey.gameButtonY),         // Y
    LogicalKeySet(LogicalKeyboardKey.gameButtonB):         const GameIntent(LogicalKeyboardKey.gameButtonB),         // B
    LogicalKeySet(LogicalKeyboardKey.gameButtonSelect):    const GameIntent(LogicalKeyboardKey.gameButtonSelect),    // Select
    LogicalKeySet(LogicalKeyboardKey.gameButtonLeft1):     const GameIntent(LogicalKeyboardKey.gameButtonLeft1),     // L1
    LogicalKeySet(LogicalKeyboardKey.gameButtonLeft2):     const GameIntent(LogicalKeyboardKey.gameButtonLeft2),     // L2
    LogicalKeySet(LogicalKeyboardKey.gameButtonThumbLeft): const GameIntent(LogicalKeyboardKey.gameButtonThumbLeft), // L2 fallback
    LogicalKeySet(LogicalKeyboardKey.gameButtonMode):      const GameIntent(LogicalKeyboardKey.gameButtonMode),      // Mode
  };

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

    GameIntent: _createGameAction(),
  };

  void dispose() {
    _pressedKeys.clear();
  }
}