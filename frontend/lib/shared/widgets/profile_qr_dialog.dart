import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../core/locale/l10n_extensions.dart';

/// Cod QR care duce direct la profilul public al userului - la fel ca la
/// confirmarea schimburilor (vezi _ExchangeQrDialog), scanat cu orice
/// cameră/aplicație de pe telefon deschide profilul în browser.
class ProfileQrDialog extends StatelessWidget {
  const ProfileQrDialog({super.key, required this.userId});
  final String userId;

  @override
  Widget build(BuildContext context) {
    final link = '${Uri.base.origin}/users/$userId';
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(l10n.profileQrDialogTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            l10n.profileQrDialogBody,
            style: Theme.of(context).textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          QrImageView(data: link, size: 200),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(l10n.commonClose)),
      ],
    );
  }
}
