import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../application/auth_controller.dart';

/// Ecran tranzitoriu: aici ajunge browserul după ce backend-ul
/// redirecționează înapoi din fluxul Google OAuth, cu un cod de schimb
/// (nu token-uri) în query string. Codul se schimbă pe token-uri reale
/// printr-un apel API separat, apoi mergem spre Home (router-ul
/// redirectează automat pe baza AuthState, vezi app_router.dart).
class GoogleCallbackScreen extends ConsumerStatefulWidget {
  const GoogleCallbackScreen({super.key, required this.code});

  final String? code;

  @override
  ConsumerState<GoogleCallbackScreen> createState() => _GoogleCallbackScreenState();
}

class _GoogleCallbackScreenState extends ConsumerState<GoogleCallbackScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _complete());
  }

  Future<void> _complete() async {
    final code = widget.code;
    if (code == null) {
      if (mounted) context.go('/login');
      return;
    }

    await ref.read(authControllerProvider.notifier).completeExternalLogin(code: code);
    if (mounted) context.go('/');
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}
