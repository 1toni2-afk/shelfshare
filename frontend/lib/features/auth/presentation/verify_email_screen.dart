import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../data/auth_repository.dart';

/// Secțiune de confirmare prin cod pe 6 cifre - apare direct după crearea
/// contului, nu printr-un link separat (linkurile aveau probleme cu
/// cache-ul browserului/service worker-ul Flutter, un cod introdus manual
/// nu depinde de nicio navigare).
class VerifyCodeSection extends ConsumerStatefulWidget {
  const VerifyCodeSection({super.key, required this.email});

  final String email;

  @override
  ConsumerState<VerifyCodeSection> createState() => _VerifyCodeSectionState();
}

class _VerifyCodeSectionState extends ConsumerState<VerifyCodeSection> {
  final _codeController = TextEditingController();
  bool _isSubmitting = false;
  bool _isResending = false;
  String? _error;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final code = _codeController.text.trim();
    if (code.length != 6) {
      setState(() => _error = 'Codul trebuie să aibă 6 cifre');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _error = null;
    });
    try {
      await ref.read(authRepositoryProvider).verifyEmail(email: widget.email, code: code);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cont confirmat cu succes!')),
        );
        context.go('/login');
      }
    } catch (_) {
      if (mounted) setState(() => _error = 'Cod invalid sau expirat.');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _resend() async {
    setState(() => _isResending = true);
    try {
      await ref.read(authRepositoryProvider).resendVerificationCode(widget.email);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Am retrimis codul, dacă e cazul.')),
        );
      }
    } catch (_) {
      // ignorăm - nu dezvăluim nimic în plus, doar nu blocăm UI-ul
    } finally {
      if (mounted) setState(() => _isResending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 88,
          height: 88,
          decoration: BoxDecoration(
            color: AppColors.accent.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.mark_email_read_outlined, color: AppColors.accent, size: 40),
        ),
        const SizedBox(height: 24),
        Text('Verifică-ți emailul', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 12),
        Text(
          'Ți-am trimis un cod de confirmare pe ${widget.email}',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 24),
        TextField(
          controller: _codeController,
          keyboardType: TextInputType.number,
          maxLength: 6,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, letterSpacing: 8),
          decoration: InputDecoration(
            counterText: '',
            hintText: '000000',
            errorText: _error,
          ),
          onChanged: (_) {
            if (_error != null) setState(() => _error = null);
          },
        ),
        const SizedBox(height: 16),
        ElevatedButton(
          onPressed: _isSubmitting ? null : _submit,
          child: _isSubmitting
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Confirmă'),
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: _isResending ? null : _resend,
          child: Text(_isResending ? 'Se retrimite...' : 'Nu ai primit codul? Retrimite'),
        ),
      ],
    );
  }
}
