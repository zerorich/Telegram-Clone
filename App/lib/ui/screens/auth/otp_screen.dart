import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:telegramclone/core/error_utils.dart';
import 'package:telegramclone/core/theme.dart';
import 'package:telegramclone/core/theme_extensions.dart';
import 'package:telegramclone/providers/auth_provider.dart';
import 'package:telegramclone/ui/widgets/otp_input.dart';

class OtpScreen extends ConsumerStatefulWidget {
  const OtpScreen({super.key});

  @override
  ConsumerState<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends ConsumerState<OtpScreen>
    with SingleTickerProviderStateMixin {
  bool _loading = false;
  late final AnimationController _animCtrl;
  late final Animation<double> _fadeAnim;
  late final Animation<Offset> _slideAnim;

  int _resendCountdown = 60;
  Timer? _resendTimer;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut));
    _animCtrl.forward();
    _startResendTimer();
  }

  void _startResendTimer() {
    _resendTimer?.cancel();
    setState(() => _resendCountdown = 60);
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() {
        _resendCountdown--;
        if (_resendCountdown <= 0) t.cancel();
      });
    });
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    _resendTimer?.cancel();
    super.dispose();
  }

  Future<void> _verify(String code) async {
    if (_loading) return;
    final email = ref.read(authDraftProvider).email;
    if (email.isEmpty) {
      if (mounted) context.go('/auth/login');
      return;
    }
    setState(() => _loading = true);
    try {
      final result =
          await ref.read(authProvider.notifier).verifyCode(email, code);
      if (!mounted) return;
      if (result.isNewUser) {
        final draft = ref.read(authDraftProvider);
        draft.isNewUser = true;
        draft.registrationToken = result.registrationToken;
        context.push('/auth/complete');
      } else {
        context.go('/home');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(friendlyError(e))),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _resend() async {
    final email = ref.read(authDraftProvider).email;
    if (email.isEmpty) return;
    try {
      await ref.read(authProvider.notifier).sendCode(email);
      _startResendTimer();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Код отправлен повторно')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(friendlyError(e))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final email = ref.watch(authDraftProvider).email;
    final mq = MediaQuery.of(context);
    final keyboardH = mq.viewInsets.bottom;
    final screenH = mq.size.height;
    final compact = screenH < 680;

    final iconSize = compact ? 64.0 : 80.0;
    final titleFontSize = compact ? 22.0 : 26.0;
    final topGap = compact ? 8.0 : 16.0;

    return Scaffold(
      backgroundColor: context.scaffoldBg,
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: context.primaryText,
          ),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: EdgeInsets.fromLTRB(24, 0, 24, keyboardH + 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(height: topGap),

              // ── Header ──────────────────────────────────────────
              FadeTransition(
                opacity: _fadeAnim,
                child: SlideTransition(
                  position: _slideAnim,
                  child: Column(
                    children: [
                      // Icon
                      Container(
                        width: iconSize,
                        height: iconSize,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.teal.withValues(alpha: 0.12),
                        ),
                        child: Icon(
                          Icons.mark_email_unread_rounded,
                          size: iconSize * 0.5,
                          color: AppColors.teal,
                        ),
                      ),
                      SizedBox(height: compact ? 16 : 24),
                      Text(
                        'Введите код',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: context.primaryText,
                          fontSize: titleFontSize,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Мы отправили 6-значный код на\n$email',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: context.subtitleColor,
                          fontSize: 14.5,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              SizedBox(height: compact ? 28 : 40),

              // ── OTP input ───────────────────────────────────────
              FadeTransition(
                opacity: _fadeAnim,
                child: SlideTransition(
                  position: _slideAnim,
                  // OtpInput fills available width adaptively
                  child: OtpInput(onCompleted: _verify),
                ),
              ),

              const SizedBox(height: 28),

              // ── Loading / resend ────────────────────────────────
              FadeTransition(
                opacity: _fadeAnim,
                child: Center(
                  child: _loading
                      ? const SizedBox(
                          width: 26,
                          height: 26,
                          child: CircularProgressIndicator(
                            color: AppColors.teal,
                            strokeWidth: 2.5,
                          ),
                        )
                      : AnimatedSwitcher(
                          duration: const Duration(milliseconds: 250),
                          child: _resendCountdown > 0
                              ? Padding(
                                  key: const ValueKey('countdown'),
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 10,),
                                  child: Text(
                                    'Повторная отправка через $_resendCountdown с',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: context.subtitleColor,
                                      fontSize: 13.5,
                                    ),
                                  ),
                                )
                              : TextButton.icon(
                                  key: const ValueKey('resend'),
                                  onPressed: _resend,
                                  icon: const Icon(
                                    Icons.refresh_rounded,
                                    color: AppColors.teal,
                                    size: 18,
                                  ),
                                  label: const Text(
                                    'Отправить снова',
                                    style: TextStyle(
                                      color: AppColors.teal,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                        ),
                ),
              ),

              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
