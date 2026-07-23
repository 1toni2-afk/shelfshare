import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;
import '../../core/locale/l10n_extensions.dart';
import '../../core/network/api_client.dart';
import '../../core/theme/app_theme.dart';

/// Buton "Continuă cu Google" - navighează întreaga pagină (nu doar ruta
/// Flutter) către backend, care redirecționează la rândul lui către Google.
/// E singurul mod pe web de a ieși din SPA și a reveni cu token-urile în
/// query string, la /auth/google/callback (vezi app_router.dart).
class GoogleSignInButton extends StatelessWidget {
  const GoogleSignInButton({super.key});

  void _launch() {
    web.window.location.href = '${ApiConfig.baseUrl}/auth/google';
  }

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: _launch,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const _GoogleLogo(),
          const SizedBox(width: 12),
          Text(
            context.l10n.continueWithGoogle,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: AppColors.foreground,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }
}

/// Mic "logo" Google simplificat (fără dependență de pachete de iconițe
/// sau assets externe) - suficient cât să se recunoască butonul.
class _GoogleLogo extends StatelessWidget {
  const _GoogleLogo();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 18,
      height: 18,
      child: Center(
        child: Text(
          'G',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w900,
            height: 1,
            color: Color(0xFF4285F4),
          ),
        ),
      ),
    );
  }
}
