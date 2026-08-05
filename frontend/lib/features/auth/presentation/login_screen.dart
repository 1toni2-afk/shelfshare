import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/locale/l10n_extensions.dart';
import '../../../core/locale/locale_controller.dart';
import '../../../core/theme/app_theme.dart';
import '../../profile/presentation/settings_screen.dart' show showLanguagePicker;
import '../../../shared/widgets/google_sign_in_button.dart';
import '../../support/presentation/support_dialog.dart';
import '../application/auth_controller.dart';
import '../application/auth_state.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _showGoogleErrorIfAny());
  }

  void _showGoogleErrorIfAny() {
    final error = GoRouterState.of(context).uri.queryParameters['error'];
    if (error == 'google_auth_failed' && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.authGoogleFailed)),
      );
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    ref.read(authControllerProvider.notifier).login(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(authControllerProvider);
    final isLoading = state is AuthLoading;
    final l10n = context.l10n;

    ref.listen<AuthState>(authControllerProvider, (previous, next) {
      if (next is AuthError) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(next.message)),
        );
      }
      // Abia după un login reușit închidem contextul de autofill - asta e
      // ce declanșează în Chrome (și în managerele de parole de pe mobil)
      // întrebarea „vrei să salvez parola?". Dacă l-am închide la apăsarea
      // butonului, s-ar oferi salvarea și pentru credențiale greșite.
      if (next is AuthAuthenticated) {
        TextInput.finishAutofillContext();
      }
    });

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
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: AppColors.accent.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.menu_book_rounded,
                      color: AppColors.accent,
                      size: 34,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text('ShelfShare', style: Theme.of(context).textTheme.displaySmall),
                  const SizedBox(height: 6),
                  Text(
                    l10n.loginWelcomeBack,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: AppColors.mutedForeground,
                        ),
                  ),
                  const SizedBox(height: 32),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Form(
                        key: _formKey,
                        // AutofillGroup + autofillHints sunt ce transformă cele
                        // două câmpuri într-un formular de login recognoscibil
                        // pentru Chrome și pentru managerele de parole: fără
                        // ele, browserul nu completează nimic și nici nu se
                        // oferă să salveze credențialele. Vezi și
                        // TextInput.finishAutofillContext() din _submit.
                        child: AutofillGroup(
                          child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            TextFormField(
                              controller: _emailController,
                              keyboardType: TextInputType.emailAddress,
                              textCapitalization: TextCapitalization.none,
                              // Enter merge la câmpul următor pe email.
                              // Milestone 16: userii se așteaptă să poată
                              // completa formularul cu tastatura.
                              textInputAction: TextInputAction.next,
                              autofillHints: const [AutofillHints.username, AutofillHints.email],
                              decoration: InputDecoration(
                                // hintText, nu labelText: un label (chiar cu
                                // floatingLabelBehavior.never) rezervă spațiul
                                // vertical unde ar urca eticheta, deci câmpul are
                                // un gol deasupra textului și pare mai înalt când
                                // scrii. Placeholder-ul nu rezervă acel spațiu.
                                hintText: l10n.commonEmailLabel,
                                prefixIcon: const Icon(Icons.mail_outline),
                              ),
                              validator: (value) => (value == null || !value.contains('@'))
                                  ? l10n.commonEmailInvalid
                                  : null,
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _passwordController,
                              obscureText: _obscurePassword,
                              // Enter pe parolă trimite formularul - același
                              // efect cu apăsarea butonului „Sign in".
                              textInputAction: TextInputAction.done,
                              onFieldSubmitted: (_) {
                                if (!isLoading) _submit();
                              },
                              autofillHints: const [AutofillHints.password],
                              decoration: InputDecoration(
                                hintText: l10n.authPasswordLabel,
                                prefixIcon: const Icon(Icons.lock_outline),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscurePassword
                                        ? Icons.visibility_outlined
                                        : Icons.visibility_off_outlined,
                                  ),
                                  onPressed: () =>
                                      setState(() => _obscurePassword = !_obscurePassword),
                                ),
                              ),
                              validator: (value) => (value == null || value.isEmpty)
                                  ? l10n.authEnterPasswordError
                                  : null,
                            ),
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                onPressed: () => context.push('/forgot-password'),
                                child: Text(l10n.authForgotPasswordLink),
                              ),
                            ),
                            const SizedBox(height: 8),
                            ElevatedButton(
                              onPressed: isLoading ? null : _submit,
                              child: isLoading
                                  ? const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: AppColors.primaryForeground,
                                      ),
                                    )
                                  : Text(l10n.authLoginSubmit),
                            ),
                            const SizedBox(height: 20),
                            Row(
                              children: [
                                const Expanded(child: Divider()),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 12),
                                  child: Text(
                                    l10n.commonOr,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.copyWith(color: AppColors.mutedForeground),
                                  ),
                                ),
                                const Expanded(child: Divider()),
                              ],
                            ),
                            const SizedBox(height: 20),
                            // WIP peste butonul Google până când configurarea
                            // OAuth e completă (Milestone 16 QOL #2).
                            Stack(
                              alignment: Alignment.center,
                              children: [
                                const Opacity(
                                  opacity: 0.4,
                                  child: IgnorePointer(child: GoogleSignInButton()),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: AppColors.warning,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Text(
                                    'Work in progress',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(l10n.authNoAccount),
                      TextButton(
                        onPressed: () => context.push('/register'),
                        child: Text(l10n.authCreateOne),
                      ),
                    ],
                  ),
                  TextButton.icon(
                    onPressed: () => showSupportDialog(context),
                    icon: const Icon(Icons.help_outline, size: 18),
                    label: Text(l10n.supportContactButton),
                  ),
                  // Selectorul de limbă e disponibil și înainte de login: altfel
                  // cineva care nu înțelege limba în care i-a pornit aplicația
                  // nu are cum să o schimbe, fiind blocat pe acest ecran.
                  TextButton.icon(
                    onPressed: () => showLanguagePicker(context, ref),
                    icon: const Icon(Icons.language_outlined, size: 18),
                    label: Text(ref.watch(effectiveLocaleProvider).label),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    l10n.loginMadeWithLove,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.mutedForeground,
                        ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
