import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:telegramclone/providers/auth_provider.dart';
import 'package:telegramclone/ui/widgets/otp_input.dart';

class OtpScreen extends ConsumerStatefulWidget {
  const OtpScreen({super.key});

  @override
  ConsumerState<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends ConsumerState<OtpScreen> {
  bool _loading = false;

  Future<void> _verify(String code) async {
    if (_loading) return;
    final email = ref.read(authDraftProvider).email;
    if (email.isEmpty) {
      if (mounted) context.go('/auth/login');
      return;
    }
    setState(() => _loading = true);
    try {
      final isNewUser =
          await ref.read(authProvider.notifier).verifyCode(email, code);
      if (!mounted) return;
      if (isNewUser) {
        ref.read(authDraftProvider).isNewUser = true;
        context.push('/auth/complete');
      } else {
        context.go('/home');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Code sent again')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final email = ref.watch(authDraftProvider).email;

    return Scaffold(
      appBar: AppBar(title: const Text('Enter code')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Text('Enter the 6-digit code sent to $email'),
            const SizedBox(height: 32),
            OtpInput(onCompleted: _verify),
            if (_loading) ...[
              const SizedBox(height: 24),
              const CircularProgressIndicator(),
            ],
            const SizedBox(height: 24),
            TextButton(
              onPressed: _loading ? null : _resend,
              child: const Text('Resend code'),
            ),
          ],
        ),
      ),
    );
  }
}
