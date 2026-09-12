import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:telegramclone/core/error_utils.dart';
import 'package:telegramclone/core/theme.dart';
import 'package:telegramclone/core/theme_extensions.dart';
import 'package:telegramclone/providers/auth_provider.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _emailCtrl = TextEditingController();
  bool _loading = false;
  late final AnimationController _animCtrl;
  late final Animation<double> _fadeAnim;
  late final Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut));
    _animCtrl.forward();
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _animCtrl.dispose();
    super.dispose();
  }

  Future<void> _continue() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Введите корректный email')),
      );
      return;
    }
    setState(() => _loading = true);
    try {
      await ref.read(authProvider.notifier).sendCode(email);
      ref.read(authDraftProvider).email = email;
      if (mounted) context.push('/auth/otp');
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

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final screenH = mq.size.height;
    final keyboardH = mq.viewInsets.bottom;
    final safePadding = mq.padding;

    // Available height without keyboard and system bars
    final availH = screenH - keyboardH - safePadding.top - safePadding.bottom;

    // Scale down decorative elements on small / compact screens
    final compact = availH < 560;
    final logoSize = compact ? 72.0 : 96.0;
    final iconSize = compact ? 44.0 : 56.0;
    final titleFontSize = compact ? 24.0 : 28.0;
    final topGap = compact ? 24.0 : (screenH * 0.07).clamp(32.0, 60.0);
    final midGap = compact ? 16.0 : 28.0;
    final formGap = compact ? 24.0 : 44.0;

    return Scaffold(
      backgroundColor: context.scaffoldBg,
      // Let the Scaffold resize body when keyboard appears so
      // SingleChildScrollView can scroll it all into view.
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: SingleChildScrollView(
          // Dismiss keyboard when user drags down
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          // Add bottom padding so the button clears the keyboard
          padding: EdgeInsets.fromLTRB(24, 0, 24, keyboardH + 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(height: topGap),

              // ── Logo ────────────────────────────────────────────
              FadeTransition(
                opacity: _fadeAnim,
                child: SlideTransition(
                  position: _slideAnim,
                  child: Center(
                    child: Container(
                      width: logoSize,
                      height: logoSize,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [AppColors.teal, AppColors.tealDark],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: Icon(
                        Icons.telegram,
                        size: iconSize,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),

              SizedBox(height: midGap),

              // ── Title ───────────────────────────────────────────
              FadeTransition(
                opacity: _fadeAnim,
                child: SlideTransition(
                  position: _slideAnim,
                  child: Column(
                    children: [
                      Text(
                        'Telegram',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: context.primaryText,
                          fontSize: titleFontSize,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.3,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Введите email — мы отправим\nкод для входа',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: context.subtitleColor,
                          fontSize: 15,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              SizedBox(height: formGap),

              // ── Form ────────────────────────────────────────────
              FadeTransition(
                opacity: _fadeAnim,
                child: SlideTransition(
                  position: _slideAnim,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Email field
                      TextField(
                        controller: _emailCtrl,
                        keyboardType: TextInputType.emailAddress,
                        autocorrect: false,
                        textInputAction: TextInputAction.done,
                        style: TextStyle(
                          color: context.primaryText,
                          fontSize: 16,
                        ),
                        decoration: InputDecoration(
                          labelText: 'Email',
                          labelStyle: TextStyle(color: context.subtitleColor),
                          prefixIcon: Icon(
                            Icons.mail_outline_rounded,
                            color: context.subtitleColor,
                          ),
                          filled: true,
                          fillColor: context.tileHighlight,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(
                              color: context.subtitleColor.withValues(alpha: 0.15),
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(
                              color: context.subtitleColor.withValues(alpha: 0.15),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(
                              color: AppColors.teal,
                              width: 1.5,
                            ),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 16,
                          ),
                        ),
                        onSubmitted: (_) => _loading ? null : _continue(),
                      ),

                      const SizedBox(height: 16),

                      // Continue button
                      SizedBox(
                        height: 52,
                        child: FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.teal,
                            disabledBackgroundColor: AppColors.tealDark,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          onPressed: _loading ? null : _continue,
                          child: _loading
                              ? const SizedBox(
                                  height: 22,
                                  width: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    color: Colors.white,
                                  ),
                                )
                              : const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      'Продолжить',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    SizedBox(width: 8),
                                    Icon(
                                      Icons.arrow_forward_rounded,
                                      size: 20,
                                    ),
                                  ],
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Extra breathing room at the bottom
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
