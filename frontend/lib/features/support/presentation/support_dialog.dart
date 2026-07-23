import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/locale/l10n_extensions.dart';
import '../../../core/theme/app_theme.dart';
import '../data/support_repository.dart';

/// Formular de contact pentru useri care nu se pot loga (deci fără sesiune
/// autentificată) - accesibil direct din ecranul de login, protejat cu un
/// captcha simplu (o adunare) în loc de un serviciu extern.
Future<void> showSupportDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (context) => const _SupportDialog(),
  );
}

class _SupportDialog extends ConsumerStatefulWidget {
  const _SupportDialog();

  @override
  ConsumerState<_SupportDialog> createState() => _SupportDialogState();
}

class _SupportDialogState extends ConsumerState<_SupportDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _messageController = TextEditingController();
  final _captchaAnswerController = TextEditingController();

  CaptchaChallenge? _captcha;
  bool _loadingCaptcha = true;
  bool _isSubmitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadCaptcha();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _messageController.dispose();
    _captchaAnswerController.dispose();
    super.dispose();
  }

  Future<void> _loadCaptcha() async {
    setState(() => _loadingCaptcha = true);
    try {
      final captcha = await ref.read(supportRepositoryProvider).getCaptcha();
      if (mounted) setState(() => _captcha = captcha);
    } catch (_) {
      // ignorăm - butonul de trimitere rămâne dezactivat cât timp _captcha e null
    } finally {
      if (mounted) setState(() => _loadingCaptcha = false);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _captcha == null) return;
    final answer = int.tryParse(_captchaAnswerController.text.trim());
    if (answer == null) return;

    setState(() {
      _isSubmitting = true;
      _error = null;
    });
    try {
      await ref.read(supportRepositoryProvider).submit(
            name: _nameController.text.trim(),
            email: _emailController.text.trim(),
            phone: _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
            message: _messageController.text.trim(),
            captchaToken: _captcha!.token,
            captchaAnswer: answer,
          );
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.supportSuccessMessage)),
        );
      }
    } on DioException catch (e) {
      if (!mounted) return;
      final data = e.response?.data;
      final message = (data is Map && data['message'] != null)
          ? data['message'].toString()
          : context.l10n.supportGenericError;
      setState(() => _error = message);
      // Un captcha greșit/expirat trebuie reîmprospătat - lăsăm userul să
      // reintroducă un răspuns nou, nu doar să retrimită la fel.
      _captchaAnswerController.clear();
      await _loadCaptcha();
    } catch (_) {
      if (mounted) setState(() => _error = context.l10n.supportGenericError);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(l10n.supportDialogTitle),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n.supportDialogSubtitle,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.mutedForeground),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: l10n.supportNameLabel,
                  prefixIcon: const Icon(Icons.person_outline),
                ),
                validator: (value) => (value == null || value.trim().isEmpty) ? l10n.commonRequired : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: l10n.commonEmailLabel,
                  prefixIcon: const Icon(Icons.mail_outline),
                ),
                validator: (value) =>
                    (value == null || !value.contains('@')) ? l10n.commonEmailInvalid : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: l10n.supportPhoneLabel,
                  prefixIcon: const Icon(Icons.phone_outlined),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _messageController,
                maxLines: 4,
                decoration: InputDecoration(labelText: l10n.supportMessageLabel),
                validator: (value) =>
                    (value == null || value.trim().length < 5) ? l10n.commonRequired : null,
              ),
              const SizedBox(height: 16),
              if (_loadingCaptcha)
                const Center(child: CircularProgressIndicator())
              else if (_captcha != null) ...[
                Text(_captcha!.question, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _captchaAnswerController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: InputDecoration(labelText: l10n.supportCaptchaAnswerLabel),
                  validator: (value) => (value == null || value.trim().isEmpty) ? l10n.commonRequired : null,
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: const TextStyle(color: AppColors.destructive)),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(l10n.commonCancel)),
        ElevatedButton(
          onPressed: (_isSubmitting || _loadingCaptcha || _captcha == null) ? null : _submit,
          child: _isSubmitting
              ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : Text(l10n.supportSubmit),
        ),
      ],
    );
  }
}
