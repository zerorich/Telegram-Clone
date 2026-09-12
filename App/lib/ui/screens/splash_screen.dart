import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:telegramclone/core/theme.dart';
import 'package:telegramclone/core/theme_extensions.dart';
import 'package:telegramclone/providers/auth_provider.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _logoCtrl;
  late final AnimationController _pulseCtrl;
  late final Animation<double> _scaleAnim;
  late final Animation<double> _fadeAnim;
  late final Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();

    _logoCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _scaleAnim = CurvedAnimation(
      parent: _logoCtrl,
      curve: Curves.elasticOut,
    );
    _fadeAnim = CurvedAnimation(
      parent: _logoCtrl,
      curve: const Interval(0.0, 0.5, curve: Curves.easeIn),
    );
    _pulseAnim = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );

    _logoCtrl.forward();

    Future.microtask(() async {
      await ref.read(authProvider.notifier).checkAuth();
      if (!mounted) return;
      final status = ref.read(authProvider).status;
      if (status == AuthStatus.authenticated) {
        context.go('/home');
      } else {
        context.go('/auth/login');
      }
    });
  }

  @override
  void dispose() {
    _logoCtrl.dispose();
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.scaffoldBg,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedBuilder(
              animation: Listenable.merge([_logoCtrl, _pulseCtrl]),
              builder: (context, _) {
                return FadeTransition(
                  opacity: _fadeAnim,
                  child: ScaleTransition(
                    scale: _scaleAnim,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Pulsing outer ring
                        ScaleTransition(
                          scale: _pulseAnim,
                          child: Container(
                            width: 120,
                            height: 120,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.teal.withValues(alpha: 0.12),
                            ),
                          ),
                        ),
                        // Icon container
                        Container(
                          width: 96,
                          height: 96,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: [AppColors.teal, AppColors.tealDark],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                          ),
                          child: const Icon(
                            Icons.telegram,
                            size: 56,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 32),
            FadeTransition(
              opacity: _fadeAnim,
              child: Text(
                'Telegram',
                style: TextStyle(
                  color: context.primaryText,
                  fontSize: 28,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            const SizedBox(height: 48),
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                color: AppColors.teal,
                strokeWidth: 2.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
