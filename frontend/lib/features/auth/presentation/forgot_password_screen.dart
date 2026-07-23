import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/locale/l10n_extensions.dart';
import '../../../core/theme/app_theme.dart';
import '../../../l10n/app_localizations.dart';
import '../data/auth_repository.dart';

enum _Step { email, code, password, done }

/// Resetare parolă în 3 pași, toți în aceeași pagină, fără niciun link de
/// deschis din email - un cod pe 6 cifre introdus manual evită complet
/// problemele de routing/cache ale linkurilor (aceeași soluție ca la
/// verificarea de email, vezi VerifyCodeSection).
class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  _Step _step = _Step.email;

  final _emailController = TextEditingController();
  final _codeController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  final _passwordFormKey = GlobalKey<FormState>();

  bool _isLoading = false;
  bool _isResending = false;
  String? _codeError;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _codeController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submitEmail() async {
    final email = _emailController.text.trim();
    if (!email.contains('@')) return;
    setState(() => _isLoading = true);
    try {
      await ref.read(authRepositoryProvider).forgotPassword(email);
      if (mounted) setState(() => _step = _Step.code);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _submitCode() async {
    final code = _codeController.text.trim();
    if (code.length != 6) {
      setState(() => _codeError = context.l10n.verifyCodeTooShort);
      return;
    }
    setState(() {
      _isLoading = true;
      _codeError = null;
    });
    try {
      await ref.read(authRepositoryProvider).verifyResetCode(
            email: _emailController.text.trim(),
            code: code,
          );
      if (mounted) setState(() => _step = _Step.password);
    } catch (_) {
      if (mounted) setState(() => _codeError = context.l10n.verifyInvalidOrExpired);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _resendCode() async {
    setState(() => _isResending = true);
    try {
      await ref.read(authRepositoryProvider).forgotPassword(_emailController.text.trim());
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(context.l10n.verifyResendSnackbar)));
      }
    } catch (_) {
      // ignorăm - nu dezvăluim nimic în plus, doar nu blocăm UI-ul
    } finally {
      if (mounted) setState(() => _isResending = false);
    }
  }

  Future<void> _submitNewPassword() async {
    if (!_passwordFormKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      await ref.read(authRepositoryProvider).resetPassword(
            email: _emailController.text.trim(),
            code: _codeController.text.trim(),
            newPassword: _passwordController.text,
          );
      if (mounted) setState(() => _step = _Step.done);
    } on DioException catch (e) {
      if (!mounted) return;
      final data = e.response?.data;
      final message = (data is Map && data['message'] != null)
          ? data['message'].toString()
          : context.l10n.resetPasswordGenericError;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(context.l10n.resetPasswordGenericError)));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(),
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: switch (_step) {
                _Step.email => _EmailStep(
                    controller: _emailController,
                    isLoading: _isLoading,
                    onSubmit: _submitEmail,
                    l10n: l10n,
                  ),
                _Step.code => _CodeStep(
                    codeController: _codeController,
                    email: _emailController.text.trim(),
                    error: _codeError,
                    isLoading: _isLoading,
                    isResending: _isResending,
                    onSubmit: _submitCode,
                    onResend: _resendCode,
                    onChanged: () {
                      if (_codeError != null) setState(() => _codeError = null);
                    },
                    l10n: l10n,
                  ),
                _Step.password => _PasswordStep(
                    formKey: _passwordFormKey,
                    passwordController: _passwordController,
                    confirmController: _confirmController,
                    obscurePassword: _obscurePassword,
                    isLoading: _isLoading,
                    onToggleObscure: () => setState(() => _obscurePassword = !_obscurePassword),
                    onSubmit: _submitNewPassword,
                    l10n: l10n,
                  ),
                _Step.done => _DoneStep(l10n: l10n, onGoToLogin: () => context.go('/login')),
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _EmailStep extends StatelessWidget {
  const _EmailStep({
    required this.controller,
    required this.isLoading,
    required this.onSubmit,
    required this.l10n,
  });

  final TextEditingController controller;
  final bool isLoading;
  final VoidCallback onSubmit;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(l10n.forgotPasswordTitle, style: Theme.of(context).textTheme.displaySmall),
        const SizedBox(height: 8),
        Text(
          l10n.forgotPasswordSubtitle,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: AppColors.mutedForeground),
        ),
        const SizedBox(height: 32),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: controller,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: l10n.commonEmailLabel,
                    prefixIcon: const Icon(Icons.mail_outline),
                  ),
                  onFieldSubmitted: (_) => onSubmit(),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: isLoading ? null : onSubmit,
                  child: isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.primaryForeground,
                          ),
                        )
                      : Text(l10n.forgotPasswordSubmit),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _CodeStep extends StatelessWidget {
  const _CodeStep({
    required this.codeController,
    required this.email,
    required this.error,
    required this.isLoading,
    required this.isResending,
    required this.onSubmit,
    required this.onResend,
    required this.onChanged,
    required this.l10n,
  });

  final TextEditingController codeController;
  final String email;
  final String? error;
  final bool isLoading;
  final bool isResending;
  final VoidCallback onSubmit;
  final VoidCallback onResend;
  final VoidCallback onChanged;
  final AppLocalizations l10n;

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
        Text(l10n.forgotPasswordCodeHeading, style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 12),
        Text(
          l10n.forgotPasswordCodeSentTo(email),
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 24),
        TextField(
          controller: codeController,
          keyboardType: TextInputType.number,
          // Codul e afișat în email cu o linie ("123-456") pentru lizibilitate -
          // la copy-paste linia vine odată cu el, deci filtrăm orice non-cifră.
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          maxLength: 6,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, letterSpacing: 8),
          decoration: InputDecoration(
            counterText: '',
            hintText: '000000',
            errorText: error,
          ),
          onChanged: (_) => onChanged(),
        ),
        const SizedBox(height: 16),
        ElevatedButton(
          onPressed: isLoading ? null : onSubmit,
          child: isLoading
              ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : Text(l10n.verifyConfirmButton),
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: isResending ? null : onResend,
          child: Text(isResending ? l10n.verifyResending : l10n.verifyResendPrompt),
        ),
      ],
    );
  }
}

class _PasswordStep extends StatelessWidget {
  const _PasswordStep({
    required this.formKey,
    required this.passwordController,
    required this.confirmController,
    required this.obscurePassword,
    required this.isLoading,
    required this.onToggleObscure,
    required this.onSubmit,
    required this.l10n,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController passwordController;
  final TextEditingController confirmController;
  final bool obscurePassword;
  final bool isLoading;
  final VoidCallback onToggleObscure;
  final VoidCallback onSubmit;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return Form(
      key: formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(l10n.resetPasswordTitle, style: Theme.of(context).textTheme.displaySmall),
          const SizedBox(height: 8),
          Text(
            l10n.resetPasswordSubtitle,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: AppColors.mutedForeground),
          ),
          const SizedBox(height: 32),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    controller: passwordController,
                    obscureText: obscurePassword,
                    decoration: InputDecoration(
                      labelText: l10n.resetPasswordNewLabel,
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(
                          obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                        ),
                        onPressed: onToggleObscure,
                      ),
                    ),
                    validator: (value) =>
                        (value == null || value.length < 8) ? l10n.authMinEightChars : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: confirmController,
                    obscureText: obscurePassword,
                    decoration: InputDecoration(
                      labelText: l10n.authConfirmPasswordLabel,
                      prefixIcon: const Icon(Icons.lock_outline),
                    ),
                    validator: (value) =>
                        value != passwordController.text ? l10n.authPasswordMismatch : null,
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: isLoading ? null : onSubmit,
                    child: isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.primaryForeground,
                            ),
                          )
                        : Text(l10n.resetPasswordSubmit),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DoneStep extends StatelessWidget {
  const _DoneStep({required this.l10n, required this.onGoToLogin});

  final AppLocalizations l10n;
  final VoidCallback onGoToLogin;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.check_circle_outline, size: 64, color: AppColors.primary),
        const SizedBox(height: 24),
        Text(l10n.resetPasswordSuccessHeading, style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 12),
        Text(l10n.resetPasswordSuccessBody, textAlign: TextAlign.center),
        const SizedBox(height: 24),
        ElevatedButton(onPressed: onGoToLogin, child: Text(l10n.resetPasswordGoToLogin)),
      ],
    );
  }
}
