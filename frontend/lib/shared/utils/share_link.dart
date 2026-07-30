import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

/// Distribuie un link absolut către o rută din aplicație (ex. "/books/abc123").
///
/// Pe Android/iOS deschide share sheet-ul nativ, ca linkul să poată pleca
/// direct în WhatsApp, Instagram sau orice altă aplicație instalată. Pe web nu
/// există un echivalent garantat (`navigator.share` lipsește pe multe
/// browsere desktop), deci acolo rămâne copierea în clipboard.
Future<void> shareAppLink(
  BuildContext context,
  String path, {
  String? subject,
}) async {
  final link = '${_origin()}$path';

  if (kIsWeb) {
    await Clipboard.setData(ClipboardData(text: link));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Link copiat în clipboard')),
      );
    }
    return;
  }

  await SharePlus.instance.share(ShareParams(uri: Uri.parse(link), subject: subject));
}

/// Pe mobil `Uri.base` e un `file://`, deci nu poate forma un link partajabil -
/// folosim domeniul public al aplicației.
String _origin() {
  if (kIsWeb) return Uri.base.origin;
  return 'https://shelfshare.ro';
}
