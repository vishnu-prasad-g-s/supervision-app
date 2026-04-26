import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'download_page/model_download_page.dart';

/// Branded splash screen shown on first launch
class SplashScreen extends StatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {

  late AnimationController _logoController;
  late AnimationController _textController;
  late AnimationController _orbController;

  late Animation<double> _logoFade;
  late Animation<double> _logoScale;
  late Animation<double> _textFade;
  late Animation<Offset> _textSlide;
  late Animation<double> _orbAnim;

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _navigateAfterDelay();
  }

  void _initAnimations() {
    // Orb ambient animation
    _orbController = AnimationController(
      duration: const Duration(seconds: 6),
      vsync: this,
    )..repeat(reverse: true);
    _orbAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _orbController, curve: Curves.easeInOut),
    );

    // Logo fade + scale in
    _logoController = AnimationController(
      duration: const Duration(milliseconds: 900),
      vsync: this,
    );
    _logoFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.easeOut),
    );
    _logoScale = Tween<double>(begin: 0.7, end: 1.0).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.elasticOut),
    );

    // Text slide up + fade in (delayed)
    _textController = AnimationController(
      duration: const Duration(milliseconds: 700),
      vsync: this,
    );
    _textFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _textController, curve: Curves.easeOut),
    );
    _textSlide = Tween<Offset>(
      begin: const Offset(0, 0.4),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _textController, curve: Curves.easeOutCubic),
    );

    // Start animations sequentially
    _logoController.forward();
    Future.delayed(const Duration(milliseconds: 400), () {
      if (mounted) _textController.forward();
    });
  }

  Future<void> _navigateAfterDelay() async {
    await Future.delayed(const Duration(milliseconds: 2800));
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => const ModelDownloadPage(),
        transitionDuration: const Duration(milliseconds: 600),
        transitionsBuilder: (_, animation, __, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  @override
  void dispose() {
    _logoController.dispose();
    _textController.dispose();
    _orbController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF07070F),
      body: Stack(
        children: [
          // Ambient silver orbs background
          AnimatedBuilder(
            animation: _orbAnim,
            builder: (context, _) {
              final size = MediaQuery.of(context).size;
              return CustomPaint(
                size: size,
                painter: _SplashOrbPainter(_orbAnim.value),
              );
            },
          ),

          // Dot grid texture
          Positioned.fill(
            child: CustomPaint(painter: _DotGridPainter()),
          ),

          // Centered content
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Logo icon
                AnimatedBuilder(
                  animation: _logoController,
                  builder: (_, __) => FadeTransition(
                    opacity: _logoFade,
                    child: ScaleTransition(
                      scale: _logoScale,
                      child: _buildLogo(),
                    ),
                  ),
                ),

                const SizedBox(height: 32),

                // App name + tagline
                AnimatedBuilder(
                  animation: _textController,
                  builder: (_, __) => FadeTransition(
                    opacity: _textFade,
                    child: SlideTransition(
                      position: _textSlide,
                      child: _buildText(),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Bottom version text
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: AnimatedBuilder(
              animation: _textController,
              builder: (_, __) => FadeTransition(
                opacity: _textFade,
                child: Text(
                  'Powered by Gemma AI',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.25),
                    fontSize: 12,
                    letterSpacing: 1.2,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogo() {
    return Container(
      width: 110,
      height: 110,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withOpacity(0.05),
        border: Border.all(
          color: Colors.white.withOpacity(0.15),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.white.withOpacity(0.12),
            blurRadius: 40,
            spreadRadius: 5,
          ),
        ],
      ),
      child: const Icon(
        Icons.remove_red_eye_outlined,
        size: 52,
        color: Colors.white,
      ),
    );
  }

  Widget _buildText() {
    return Column(
      children: [
        // App name
        const Text(
          'SuperVision',
          style: TextStyle(
            color: Colors.white,
            fontSize: 36,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 10),
        // Tagline
        Text(
          'Your AI Vision Assistant',
          style: TextStyle(
            color: Colors.white.withOpacity(0.45),
            fontSize: 14,
            fontWeight: FontWeight.w400,
            letterSpacing: 0.8,
          ),
        ),
      ],
    );
  }
}

// ── Painters ──────────────────────────────────────────────────────────────

class _SplashOrbPainter extends CustomPainter {
  final double progress;
  _SplashOrbPainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    // Silver orb top right
    final x1 = size.width * 0.78 + math.sin(progress * math.pi) * 30;
    final y1 = size.height * 0.22 + math.cos(progress * math.pi) * 25;
    canvas.drawCircle(
      Offset(x1, y1), 220,
      Paint()..shader = RadialGradient(colors: [
        Colors.white.withOpacity(0.12),
        Colors.white.withOpacity(0.03),
        Colors.transparent,
      ], stops: const [0.0, 0.5, 1.0]).createShader(
        Rect.fromCircle(center: Offset(x1, y1), radius: 220)),
    );

    // Silver orb bottom left
    final x2 = size.width * 0.18 + math.cos(progress * math.pi) * 28;
    final y2 = size.height * 0.75 + math.sin(progress * math.pi) * 30;
    canvas.drawCircle(
      Offset(x2, y2), 200,
      Paint()..shader = RadialGradient(colors: [
        Colors.white.withOpacity(0.10),
        Colors.white.withOpacity(0.02),
        Colors.transparent,
      ], stops: const [0.0, 0.5, 1.0]).createShader(
        Rect.fromCircle(center: Offset(x2, y2), radius: 200)),
    );
  }

  @override
  bool shouldRepaint(_SplashOrbPainter old) => old.progress != progress;
}

class _DotGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.025)
      ..style = PaintingStyle.fill;
    const spacing = 28.0;
    for (int r = 0; r <= (size.height / spacing).ceil(); r++) {
      for (int c = 0; c <= (size.width / spacing).ceil(); c++) {
        canvas.drawCircle(Offset(c * spacing, r * spacing), 1.0, paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DotGridPainter old) => false;
}
