import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/locale/l10n_extensions.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/application/auth_state.dart';
import '../data/pre_registration_repository.dart';

class PreRegistrationScreen extends ConsumerStatefulWidget {
  const PreRegistrationScreen({super.key});

  @override
  ConsumerState<PreRegistrationScreen> createState() =>
      _PreRegistrationScreenState();
}

class _PreRegistrationScreenState extends ConsumerState<PreRegistrationScreen> {
  late final TextEditingController _emailController;
  bool _submitting = false;
  bool _done = false;

  @override
  void initState() {
    super.initState();
    // Prefill cu emailul userului logat, dacă există - poate fi editat.
    final auth = ref.read(authControllerProvider);
    final prefill = auth is AuthAuthenticated ? auth.user.email : '';
    _emailController = TextEditingController(text: prefill);
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final l10n = context.l10n;
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l10n.preRegisterError)));
      return;
    }
    setState(() => _submitting = true);
    try {
      await ref.read(preRegistrationRepositoryProvider).register(email);
      if (mounted) {
        setState(() => _done = true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.preRegisterSuccess)),
        );
      }
    } on DioException {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(l10n.preRegisterError)));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final auth = ref.watch(authControllerProvider);
    final loggedIn = auth is AuthAuthenticated;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.preRegisterAndroidTitle)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const SizedBox(height: 16),
            Center(
              child: Icon(
                Icons.android,
                size: 72,
                color: AppColors.accent,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              l10n.preRegisterAndroidHeadline,
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              l10n.preRegisterAndroidBody,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.mutedForeground,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            TextField(
              controller: _emailController,
              readOnly: _done,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              decoration: InputDecoration(
                labelText: l10n.preRegisterEmailHint,
                helperText: loggedIn ? l10n.preRegisterAlreadyLoggedIn : null,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              // După înscriere reușită, butonul e dezactivat + iconă de check
              // - nu vrem să tastezi și să dai submit fără să vezi feedback.
              onPressed: _submitting || _done ? null : _submit,
              icon: _done
                  ? const Icon(Icons.check_circle_outline)
                  : const Icon(Icons.notifications_active_outlined),
              label: _submitting
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(_done ? l10n.preRegisterSuccess : l10n.preRegisterSubmit),
            ),
          ],
        ),
      ),
    );
  }
}
