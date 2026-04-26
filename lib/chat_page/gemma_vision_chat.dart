// chat_page/gemma_vision_chat.dart

import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:flutter_gemma/pigeon.g.dart';
import 'widgets/prompt_bar.dart';
import 'services/bootstrap_manager.dart';
import 'services/chat_helpers.dart';
import 'services/speech_service.dart';
import 'services/streaming_tts_service.dart';
import 'services/text_recognition_service.dart';
import 'models/message_models.dart';
import '/error_recovery_page.dart';
import 'handlers/keyboard_handler.dart';
import 'widgets/chat_ui_builder.dart';
import '../settings_page.dart';
import 'widgets/semantic_button_registry.dart';
import 'config/system_prompts.dart';

/// Main chat interface with AI vision model - handles bootstrap and lifecycle management
class ChatPage extends StatefulWidget {
  const ChatPage({Key? key}) : super(key: key);
  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> with TickerProviderStateMixin {
  /* Core state */
  /// Chat message history
  final _msgs = <ChatMessage>[];

  /// UI toggle states
  bool _showMessages = false;
  bool _showCamera = true;

  /// TTS services (initially temporary, replaced after bootstrap)
  late FlutterTts _tts = FlutterTts();
  late StreamingTtsService _streamingTts = StreamingTtsService(_tts);

  /// Service references (nullable until bootstrap completes)
  ChatHelpers? _chatHelpers;
  SpeechService? _speechService;
  KeyboardHandler? _keyboardHandler;
  TextRecognitionService? _textRecognition;

  /// AI model configuration
  String _systemCtx = SystemPrompts.blindUserNavigation;
  PreferredBackend _backend = PreferredBackend.cpu;

  /* UI control */
  final _promptBarKey = GlobalKey<PromptBarState>();
  bool _initialising = true;
  bool _redirectedOnError = false;
  bool _disposed = false;

  /* Focus management for accessibility */
  final FocusNode _rootFocus = FocusNode();

  /* Auto-scroll for message list */
  final ScrollController _scrollController = ScrollController();
  Timer? _autoScrollTimer;

  /* Page transition animations */
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  /* Ambient background animations */
  late AnimationController _orb1Controller;
  late AnimationController _orb2Controller;
  late AnimationController _orb3Controller;

  late Animation<double> _orb1Animation;
  late Animation<double> _orb2Animation;
  late Animation<double> _orb3Animation;

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _bootstrap();
  }

  /// Setup smooth page entry animations + ambient orb animations
  void _initAnimations() {
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );
    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
          CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic),
        );

    // Ambient orb drift controllers — different speeds for organic feel
    _orb1Controller = AnimationController(
      duration: const Duration(seconds: 9),
      vsync: this,
    )..repeat(reverse: true);

    _orb2Controller = AnimationController(
      duration: const Duration(seconds: 13),
      vsync: this,
    )..repeat(reverse: true);

    _orb3Controller = AnimationController(
      duration: const Duration(seconds: 7),
      vsync: this,
    )..repeat(reverse: true);

    _orb1Animation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _orb1Controller, curve: Curves.easeInOut),
    );
    _orb2Animation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _orb2Controller, curve: Curves.easeInOut),
    );
    _orb3Animation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _orb3Controller, curve: Curves.easeInOut),
    );
  }

  /// Service initialization with crash recovery and lifecycle guards
  Future<void> _bootstrap() async {
    if (_disposed) return;

    try {
      final result = await BootstrapManager.bootstrap(
        context: context,
        systemContext: _systemCtx,
        backend: _backend,
        promptBarKey: _promptBarKey,
        onToggleMessages: () {
          if (mounted && !_disposed) {
            setState(() => _showMessages = !_showMessages);
            if (_showMessages) {
              _scrollToBottom(force: true);
            }
          }
        },
        onToggleCamera: () {
          if (mounted && !_disposed) setState(() => _showCamera = !_showCamera);
        },
        onToggleSettings: _navigateToSettings,
        onNewChat: _newChat,
        onQuickAction1: _quickAction1,
        onQuickAction2: _quickAction2,
        onQuickAction3: _quickAction3,
        onQuickAction4: _quickAction4,
        onToggleVoice: () {
          _speechService?.toggleDictation();
        },
        isMounted: () => mounted,
        isDisposed: () => _disposed,
        setState: (fn) {
          setState(fn);
          if (_showMessages) {
            _scheduleAutoScroll();
          }
        },
      );

      _streamingTts.stop();
      _tts.stop();

      _tts = result.tts;
      _streamingTts = result.streamingTts;
      _chatHelpers = result.chatHelpers;
      _speechService = result.speechService;
      _keyboardHandler = result.keyboardHandler;
      _textRecognition = result.textRecognition;

      if (mounted && !_disposed) {
        setState(() => _initialising = false);
        _rootFocus.requestFocus();
        _fadeController.forward();
        _slideController.forward();
      }
    } catch (e) {
      debugPrint("Gemma service initialization failed: $e");

      if (mounted && !_disposed && !_redirectedOnError) {
        _redirectedOnError = true;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const ErrorRecoveryPage()),
        );
      }
    }
  }

  void _scheduleAutoScroll() {
    _autoScrollTimer?.cancel();
    _autoScrollTimer = Timer(const Duration(milliseconds: 100), () {
      _scrollToBottom();
    });
  }

  void _scrollToBottom({bool force = false}) {
    if (!_showMessages && !force) return;
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _autoScrollTimer?.cancel();
    _scrollController.dispose();
    _fadeController.dispose();
    _slideController.dispose();
    _orb1Controller.dispose();
    _orb2Controller.dispose();
    _orb3Controller.dispose();
    _streamingTts.stop();
    _tts.stop();
    _speechService?.dispose();
    _textRecognition?.dispose();
    _rootFocus.dispose();
    SemanticButtonRegistry.clear();
    super.dispose();
  }

  /* Chat operation wrappers with null safety */
  Future<void> _newChat() async =>
      await _chatHelpers!.newChat(_msgs, _promptBarKey);

  Future<void> _captureAndSend(String prompt) async =>
      await _chatHelpers!.captureAndSend(prompt, _msgs);

  Future<void> _sendTextOnly(String prompt) async =>
      await _chatHelpers!.sendTextOnly(prompt, _msgs);

  Future<void> _quickAction1() async => _chatHelpers!.quickAction1(_msgs);
  Future<void> _quickAction2() async => _chatHelpers!.quickAction2(_msgs);
  Future<void> _quickAction3() async => _chatHelpers!.quickAction3(_msgs);
  Future<void> _quickAction4() async => _chatHelpers!.quickAction4(_msgs);

  @override
  Widget build(BuildContext context) {
    if (_initialising) return _buildLoadingWrapper();
    return _buildMainContent();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Loading wrapper — keeps the dark theme even during bootstrap
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildLoadingWrapper() {
    return Scaffold(
      backgroundColor: const Color(0xFF07070F),
      body: Stack(
        children: [
          _buildAmbientBackground(),
          _buildGridOverlay(),
          ChatUIBuilder.buildLoadingScreen(),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Main content
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildMainContent() {
    return Shortcuts(
      shortcuts: _keyboardHandler!.shortcuts,
      child: Actions(
        actions: _keyboardHandler!.actions,
        child: Focus(
          focusNode: _rootFocus,
          autofocus: true,
          onKeyEvent: _speechService!.handleFocusKey,
          child: Scaffold(
            // Transparent so our custom background shows through
            backgroundColor: Colors.transparent,
            extendBodyBehindAppBar: true,
            appBar: _buildGlassAppBar(),
            body: Stack(
              children: [
                // ── Ambient background (behind everything) ────────────
                _buildAmbientBackground(),
                _buildGridOverlay(),

                // ── Main UI content ───────────────────────────────────
                SafeArea(
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: SlideTransition(
                      position: _slideAnimation,
                      child: Column(
                        children: [
                          /* View toggle buttons */
                          ChatUIBuilder.buildViewToggleButtons(
                            showMessages: _showMessages,
                            onToggleMessages: () {
                              setState(
                                () => _showMessages = !_showMessages,
                              );
                              if (_showMessages) {
                                _scrollToBottom(force: true);
                              }
                            },
                            onNewChat: _newChat,
                            isResetting: _chatHelpers!.resetting,
                          ),

                          /* Expandable message list or spacer */
                          if (_showMessages)
                            ChatUIBuilder.buildMessagesContainer(
                              _msgs,
                              _scrollController,
                            )
                          else
                            const Expanded(child: SizedBox()),

                          /* Fixed prompt bar at bottom */
                          _buildPromptBarWrapper(),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Glass AppBar
  // ─────────────────────────────────────────────────────────────────────────

  PreferredSizeWidget _buildGlassAppBar() {
    // Wrap the existing app bar in a glass-style container by using
    // PreferredSize with a transparent/blurred surface treatment.
    return PreferredSize(
      preferredSize: const Size.fromHeight(kToolbarHeight + 1),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF07070F).withOpacity(0.75),
          border: Border(
            bottom: BorderSide(
              color: Colors.white.withOpacity(0.07),
              width: 1,
            ),
          ),
        ),
        child: ChatUIBuilder.buildCleanAppBar(
          onNewChat: _newChat,
          onToggleSettings: _navigateToSettings,
          isResetting: _chatHelpers!.resetting,
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Prompt bar wrapper — frosted glass panel
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildPromptBarWrapper() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0E0E1A).withOpacity(0.85),
        border: Border(
          top: BorderSide(
            color: Colors.white.withOpacity(0.07),
            width: 1,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFE0E0E0).withOpacity(0.06),
            blurRadius: 30,
            offset: const Offset(0, -8),
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.4),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: ChatUIBuilder.buildPromptBarContainer(
        promptBarKey: _promptBarKey,
        onPromptWithPhoto: _captureAndSend,
        onPromptTextOnly: _sendTextOnly,
        disabled:
            _chatHelpers!.resetting || _chatHelpers!.isGenerating,
        speechEnabled: _speechService!.speechEnabled,
        listening: _speechService!.listening,
        onToggleListening: _speechService!.toggleDictation,
        isGenerating: _chatHelpers!.isGenerating,
        isSpeaking: _chatHelpers!.isSpeaking,
        onStopTts: _speechService!.stopTts,
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Ambient background — matches download page aesthetic
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildAmbientBackground() {
    return AnimatedBuilder(
      animation:
          Listenable.merge([_orb1Animation, _orb2Animation, _orb3Animation]),
      builder: (context, _) {
        final size = MediaQuery.of(context).size;
        return SizedBox.expand(
          child: CustomPaint(
            painter: _ChatAmbientPainter(
              orb1Progress: _orb1Animation.value,
              orb2Progress: _orb2Animation.value,
              orb3Progress: _orb3Animation.value,
              screenSize: size,
            ),
          ),
        );
      },
    );
  }

  Widget _buildGridOverlay() {
    return Positioned.fill(
      child: CustomPaint(painter: _GridPainter()),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Settings navigation
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _navigateToSettings() async {
    if (_disposed || !mounted) return;

    final result = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(
        builder: (context) =>
            SettingsPage(systemContext: _systemCtx, backend: _backend),
      ),
    );

    if (result != null && mounted && !_disposed) {
      final newSystemContext = result['systemContext'] as String?;
      final newBackend = result['backend'] as PreferredBackend?;

      if (newSystemContext != null && newBackend != null) {
        setState(() {
          _systemCtx = newSystemContext;
          _chatHelpers!.updateSystemContext(_systemCtx);

          if (_backend != newBackend) {
            _backend = newBackend;
            _msgs.clear();
            _initialising = true;
            BootstrapManager.reset();
            _redirectedOnError = false;
            _bootstrap();
          }
        });
      }
    }
  }
}

// ───────────────────────────────────────────────────────────────────────────
// Custom painters
// ───────────────────────────────────────────────────────────────────────────

/// Three drifting orbs — blue (top-right), purple (bottom-left), teal (center-right).
/// A third orb adds depth without overwhelming the chat content.
class _ChatAmbientPainter extends CustomPainter {
  final double orb1Progress;
  final double orb2Progress;
  final double orb3Progress;
  final Size screenSize;

  _ChatAmbientPainter({
    required this.orb1Progress,
    required this.orb2Progress,
    required this.orb3Progress,
    required this.screenSize,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Fill solid dark base first
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = const Color(0xFF07070F),
    );

    // Orb 1 — electric blue, upper right area
    final o1x = size.width * 0.82 + math.sin(orb1Progress * math.pi) * 45;
    final o1y = size.height * 0.15 + math.cos(orb1Progress * math.pi) * 35;
    canvas.drawCircle(
      Offset(o1x, o1y),
      280,
      Paint()
        ..shader = RadialGradient(
          colors: [
            const Color(0xFFE0E0E0).withOpacity(0.28),
            const Color(0xFFBDBDBD).withOpacity(0.07),
            Colors.transparent,
          ],
          stops: const [0.0, 0.45, 1.0],
        ).createShader(Rect.fromCircle(center: Offset(o1x, o1y), radius: 280)),
    );

    // Orb 2 — deep purple, lower left
    final o2x = size.width * 0.12 + math.cos(orb2Progress * math.pi) * 38;
    final o2y = size.height * 0.78 + math.sin(orb2Progress * math.pi) * 42;
    canvas.drawCircle(
      Offset(o2x, o2y),
      250,
      Paint()
        ..shader = RadialGradient(
          colors: [
            const Color(0xFF9E9E9E).withOpacity(0.25),
            const Color(0xFFBDBDBD).withOpacity(0.06),
            Colors.transparent,
          ],
          stops: const [0.0, 0.45, 1.0],
        ).createShader(Rect.fromCircle(center: Offset(o2x, o2y), radius: 250)),
    );

    // Orb 3 — dim teal accent, mid-screen (subtle, doesn't compete with content)
    final o3x = size.width * 0.55 + math.sin(orb3Progress * math.pi * 1.3) * 30;
    final o3y = size.height * 0.48 + math.cos(orb3Progress * math.pi) * 25;
    canvas.drawCircle(
      Offset(o3x, o3y),
      180,
      Paint()
        ..shader = RadialGradient(
          colors: [
            const Color(0xFFE0E0E0).withOpacity(0.10),
            Colors.transparent,
          ],
          stops: const [0.0, 1.0],
        ).createShader(Rect.fromCircle(center: Offset(o3x, o3y), radius: 180)),
    );
  }

  @override
  bool shouldRepaint(_ChatAmbientPainter old) =>
      old.orb1Progress != orb1Progress ||
      old.orb2Progress != orb2Progress ||
      old.orb3Progress != orb3Progress;
}

/// Subtle dot-grid texture — identical to download page for visual consistency.
class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.025)
      ..style = PaintingStyle.fill;

    const spacing = 28.0;
    final cols = (size.width / spacing).ceil();
    final rows = (size.height / spacing).ceil();

    for (int r = 0; r <= rows; r++) {
      for (int c = 0; c <= cols; c++) {
        canvas.drawCircle(Offset(c * spacing, r * spacing), 1.0, paint);
      }
    }
  }

  @override
  bool shouldRepaint(_GridPainter old) => false;
}