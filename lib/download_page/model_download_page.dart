// download_page/model_download_page.dart

import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../chat_page/services/announcement_service.dart';
import 'package:super_vision/chat_page/gemma_vision_chat.dart';

import 'models/enums.dart';
import 'models/models.dart';
import 'services/logger.dart';
import 'services/download_manager.dart';
import 'logic/download_logic.dart';
import 'ui/modern_ui_widgets.dart';
import 'ui/ui_helpers.dart';

/// Main page widget that handles the model download UI and state management.
/// This is a StatefulWidget that manages the download process for ML models,
/// including authentication, progress tracking, error handling, and user interactions.
class ModelDownloadPage extends StatefulWidget {
  const ModelDownloadPage({Key? key}) : super(key: key);

  @override
  State<ModelDownloadPage> createState() => _ModelDownloadPageState();
}

class _ModelDownloadPageState extends State<ModelDownloadPage>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  // Current status of the download process (notStarted, downloading, completed, etc.)
  DownloadStatus _downloadStatus = DownloadStatus.notStarted;

  // Progress information including bytes downloaded, speed, and estimated time
  DownloadProgress? _progress;

  // List of error messages to display to the user when downloads fail
  List<String> _errorMessages = [];

  // Controls visibility of the license agreement bottom sheet
  bool _showAgreementSheet = false;

  // Subscription to listen for log updates and refresh UI accordingly
  late StreamSubscription _logSubscription;

  // Business logic handler that manages all download operations
  late DownloadPageLogic _logic;

  // Animation controllers for ambient background orbs
  late AnimationController _orb1Controller;
  late AnimationController _orb2Controller;
  late AnimationController _pulseController;

  late Animation<double> _orb1Animation;
  late Animation<double> _orb2Animation;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeAnimations();
    _initializeLogic();
    _initializeDownloader();
    _checkDownloadState();
    _setupLogListener();
  }

  bool _isRetryingLicense = false;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        _downloadStatus == DownloadStatus.awaitingLicenseAcceptance &&
        !_isRetryingLicense) {
      _isRetryingLicense = true;
      Logger.info('App resumed from license page - retrying once');
      Future.delayed(const Duration(milliseconds: 1000), () {
        if (mounted) {
          _logic.retryAfterLicenseAcceptance();
          // Reset flag after 5 seconds so user can retry manually if needed
          Future.delayed(const Duration(seconds: 5), () {
            _isRetryingLicense = false;
          });
        }
      });
    }
  }

  /// Sets up ambient background animations for visual depth.
  void _initializeAnimations() {
    _orb1Controller = AnimationController(
      duration: const Duration(seconds: 8),
      vsync: this,
    )..repeat(reverse: true);

    _orb2Controller = AnimationController(
      duration: const Duration(seconds: 11),
      vsync: this,
    )..repeat(reverse: true);

    _pulseController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    )..repeat(reverse: true);

    _orb1Animation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _orb1Controller, curve: Curves.easeInOut),
    );
    _orb2Animation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _orb2Controller, curve: Curves.easeInOut),
    );
    _pulseAnimation = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _logSubscription.cancel();
    _logic.dispose();
    _orb1Controller.dispose();
    _orb2Controller.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  /// Initializes the download logic with callback functions that update the UI state.
  void _initializeLogic() {
    _logic = DownloadPageLogic(
      setDownloadStatus: (status) => setState(() => _downloadStatus = status),
      setProgress: (progress) => setState(() => _progress = progress),
      setErrorMessages: (messages) => setState(() => _errorMessages = messages),
      setShowAgreementSheet: (show) =>
          setState(() => _showAgreementSheet = show),
    );
  }

  /// Sets up a listener for log entries to refresh the UI when new logs are added.
  void _setupLogListener() {
    _logSubscription = Logger.logStream.listen((logEntry) {
      setState(() {});
    });
  }

  /// Initializes the download manager system.
  Future<void> _initializeDownloader() async {
    await DownloadManager.initialize();
    Logger.info('Download manager initialized');
  }

  /// Checks if there are any ongoing downloads from previous app sessions.
  Future<void> _checkDownloadState() async {
    await _logic.checkForOngoingDownloads(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF07070F),
      body: Stack(
        children: [
          // ── Ambient background layer ──────────────────────────────────
          _buildAmbientBackground(),

          // ── Subtle noise/grid texture overlay ────────────────────────
          _buildGridOverlay(),

          // ── Main content ──────────────────────────────────────────────
          SafeArea(
            child: Stack(
              children: [
                // Scrollable body with glass card
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20.0,
                    vertical: 12.0,
                  ),
                  child: Column(
                    children: [
                      const Spacer(flex: 1),

                      // ── Frosted glass card ──────────────────────────
                      _buildGlassCard(),

                      const Spacer(flex: 1),

                      // ── Error panel ─────────────────────────────────
                      if (_errorMessages.isNotEmpty &&
                          _downloadStatus == DownloadStatus.failed) ...[
                        _buildErrorPanel(),
                        const SizedBox(height: 16),
                      ],
                    ],
                  ),
                ),

                // ── Logs button ─────────────────────────────────────────
                Positioned(
                  top: 8,
                  right: 16,
                  child: _buildStyledLogsButton(),
                ),
              ],
            ),
          ),
        ],
      ),

      // ── License bottom sheet ─────────────────────────────────────────
      bottomSheet: _showAgreementSheet
          ? _buildStyledLicenseSheet()
          : null,
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Background layers
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildAmbientBackground() {
    return AnimatedBuilder(
      animation: Listenable.merge([_orb1Animation, _orb2Animation]),
      builder: (context, _) {
        final size = MediaQuery.of(context).size;
        return SizedBox.expand(
          child: CustomPaint(
            painter: _AmbientOrbPainter(
              orb1Progress: _orb1Animation.value,
              orb2Progress: _orb2Animation.value,
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
  // Glass card
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildGlassCard() {
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Container(
          width: double.infinity,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            // Outer glow ring
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFE0E0E0).withOpacity(
                  0.12 * _pulseAnimation.value,
                ),
                blurRadius: 60,
                spreadRadius: 0,
              ),
              BoxShadow(
                color: Colors.black.withOpacity(0.6),
                blurRadius: 40,
                offset: const Offset(0, 16),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.03),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: Colors.white.withOpacity(0.09),
                  width: 1,
                ),
              ),
              child: Stack(
                children: [
                  // Subtle top-left shimmer inside card
                  Positioned(
                    top: -40,
                    left: -40,
                    child: Container(
                      width: 180,
                      height: 180,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            const Color(0xFFE0E0E0).withOpacity(0.08),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                  // Card content
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 28.0,
                      vertical: 40.0,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // App label chip
                        _buildChip(),
                        const SizedBox(height: 32),

                        // Download icon
                        ModernUIWidgets.buildDownloadIcon(
                          _downloadStatus,
                          _progress,
                        ),
                        const SizedBox(height: 28),

                        // Status message
                        ModernUIWidgets.buildStatusMessage(
                          _downloadStatus,
                          _progress,
                          _errorMessages,
                        ),
                        const SizedBox(height: 20),

                        // Progress bar
                        ModernUIWidgets.buildProgressBar(
                          _progress,
                          _downloadStatus,
                        ),
                        const SizedBox(height: 36),

                        // Action buttons
                        ModernUIWidgets.buildActionButtons(
                          _downloadStatus,
                          () => _logic.startDownload(),
                          () => _logic.pauseDownload(),
                          () => _logic.resumeDownload(),
                          () => _logic.showCancelConfirmation(context),
                          () => Navigator.of(context).pushReplacement(
                            MaterialPageRoute(
                              builder: (context) => ChatPage(),
                            ),
                          ),
                        ),

                        const SizedBox(height: 8),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildChip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFE0E0E0).withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFFE0E0E0).withOpacity(0.25),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0xFF4FACFE),
            ),
          ),
          const SizedBox(width: 8),
          const Text(
            'SuperVision  ·  Model Setup',
            style: TextStyle(
              color: Color(0xFF4FACFE),
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Error panel
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildErrorPanel() {
    return GestureDetector(
      onTap: () => UIHelpers.showErrorDialog(context, _errorMessages),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFFFF4B4B).withOpacity(0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: const Color(0xFFFF4B4B).withOpacity(0.25),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFFF4B4B).withOpacity(0.05),
              blurRadius: 20,
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFFF4B4B).withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.error_outline_rounded,
                color: Color(0xFFFF6B6B),
                size: 18,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Download Failed',
                    style: TextStyle(
                      color: Color(0xFFFF6B6B),
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Tap to view error details',
                    style: TextStyle(
                      color: const Color(0xFFCFCFCF).withOpacity(0.65),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: const Color(0xFFCFCFCF).withOpacity(0.7),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Logs button
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildStyledLogsButton() {
    return GestureDetector(
      onTap: () => UIHelpers.showLogsDialog(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.04),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Colors.white.withOpacity(0.10),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.terminal_rounded,
              size: 14,
              color: Colors.white.withOpacity(0.55),
            ),
            const SizedBox(width: 6),
            Text(
              'Logs',
              style: TextStyle(
                color: Colors.white.withOpacity(0.55),
                fontSize: 12,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // License sheet
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildStyledLicenseSheet() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0E0E1A),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(
          top: BorderSide(color: Colors.white.withOpacity(0.08)),
          left: BorderSide(color: Colors.white.withOpacity(0.05)),
          right: BorderSide(color: Colors.white.withOpacity(0.05)),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFE0E0E0).withOpacity(0.07),
            blurRadius: 40,
            offset: const Offset(0, -10),
          ),
        ],
      ),
      child: ModernUIWidgets.buildLicenseBottomSheet(
        context,
        () => _logic.cancelLicenseAgreement(),
        () => _logic.openLicenseAgreement(),
      ),
    );
  }
}

// ───────────────────────────────────────────────────────────────────────────
// Custom painters
// ───────────────────────────────────────────────────────────────────────────

/// Paints two animated radial gradient orbs that slowly drift for visual depth.
class _AmbientOrbPainter extends CustomPainter {
  final double orb1Progress;
  final double orb2Progress;
  final Size screenSize;

  _AmbientOrbPainter({
    required this.orb1Progress,
    required this.orb2Progress,
    required this.screenSize,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Orb 1 — electric blue, upper right
    final orb1X = size.width * 0.75 + math.sin(orb1Progress * math.pi) * 40;
    final orb1Y = size.height * 0.20 + math.cos(orb1Progress * math.pi) * 30;

    final paint1 = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFFE0E0E0).withOpacity(0.30),
          const Color(0xFFBDBDBD).withOpacity(0.08),
          Colors.transparent,
        ],
        stops: const [0.0, 0.45, 1.0],
      ).createShader(
        Rect.fromCircle(center: Offset(orb1X, orb1Y), radius: 260),
      );
    canvas.drawCircle(Offset(orb1X, orb1Y), 260, paint1);

    // Orb 2 — deep purple, lower left
    final orb2X = size.width * 0.18 + math.cos(orb2Progress * math.pi) * 35;
    final orb2Y = size.height * 0.72 + math.sin(orb2Progress * math.pi) * 40;

    final paint2 = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFF9E9E9E).withOpacity(0.28),
          const Color(0xFFBDBDBD).withOpacity(0.07),
          Colors.transparent,
        ],
        stops: const [0.0, 0.45, 1.0],
      ).createShader(
        Rect.fromCircle(center: Offset(orb2X, orb2Y), radius: 240),
      );
    canvas.drawCircle(Offset(orb2X, orb2Y), 240, paint2);
  }

  @override
  bool shouldRepaint(_AmbientOrbPainter old) =>
      old.orb1Progress != orb1Progress || old.orb2Progress != orb2Progress;
}

/// Paints a very subtle dot-grid to add texture and depth to the background.
class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.028)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.fill;

    const spacing = 28.0;
    final cols = (size.width / spacing).ceil();
    final rows = (size.height / spacing).ceil();

    for (int r = 0; r <= rows; r++) {
      for (int c = 0; c <= cols; c++) {
        canvas.drawCircle(
          Offset(c * spacing, r * spacing),
          1.0,
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_GridPainter old) => false;
}