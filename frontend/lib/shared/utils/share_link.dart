import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Copiază în clipboard un link absolut către o rută din aplicație
/// (ex. "/books/abc123") - nu deschide un share sheet nativ (fără pachet
/// nou), dar acoperă cazul de bază: userul poate trimite linkul oricui.
Future<void> copyShareLink(BuildContext context, String path) async {
  final link = '${Uri.base.origin}$path';
  await Clipboard.setData(ClipboardData(text: link));
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Link copiat în clipboard')),
    );
  }
}
