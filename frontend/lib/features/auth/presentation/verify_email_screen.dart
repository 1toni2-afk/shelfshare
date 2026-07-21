import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../data/auth_repository.dart';

enum _VerifyStatus { loading, success, error }

/// Ecran la care ajunge browserul din linkul de confirmare trimis pe email -
/// preia token-ul din query string și îl trimite la backend.
class VerifyEmailScreen extends ConsumerStatefulWidget {
  const VerifyEmailScreen({super.key, required this.token});

  final String? token;

  @override
  ConsumerState<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends ConsumerState<VerifyEmailScreen> {
  _VerifyStatus _status = _VerifyStatus.loading;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _verify());
  }

  Future<void> _verify() async {
    final token = widget.token;
    if (token == null || token.isEmpty) {
      setState(() {
        _status = _VerifyStatus.error;
        _errorMessage = 'Link de confirmare invalid.';
      });
      return;
    }

    try {
      await ref.read(authRepositoryProvider).verifyEmail(token);
      if (mounted) setState(() => _status = _VerifyStatus.success);
    } catch (_) {
      if (mounted) {
        setState(() {
          _status = _VerifyStatus.error;
          _errorMessage = 'Linkul de confirmare este invalid sau a expirat.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  switch (_status) {
                    _VerifyStatus.loading => const CircularProgressIndicator(),
                    _VerifyStatus.success => const Icon(
                        Icons.check_circle_outline,
                        size: 64,
                        color: AppColors.primary,
                      ),
                    _VerifyStatus.error => const Icon(
                        Icons.error_outline,
                        size: 64,
                        color: AppColors.destructive,
                      ),
                  },
                  const SizedBox(height: 24),
                  Text(
                    switch (_status) {
                      _VerifyStatus.loading => 'Confirmăm adresa de email...',
                      _VerifyStatus.success => 'Email confirmat cu succes!',
                      _VerifyStatus.error => 'Nu am putut confirma emailul',
                    },
                    style: Theme.of(context).textTheme.headlineSmall,
                    textAlign: TextAlign.center,
                  ),
                  if (_status == _VerifyStatus.error && _errorMessage != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _errorMessage!,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppColors.mutedForeground,
                          ),
                    ),
                  ],
                  if (_status != _VerifyStatus.loading) ...[
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () => context.go('/login'),
                      child: const Text('Mergi la autentificare'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
