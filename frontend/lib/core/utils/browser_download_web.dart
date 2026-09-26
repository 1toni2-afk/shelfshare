import 'dart:convert';
import 'dart:js_interop';
import 'dart:typed_data';
import 'package:web/web.dart' as web;

void downloadTextFile({required String filename, required String content, String mimeType = 'text/plain'}) {
  // Vezi comentariul din browser_download_stub.dart: codeUnits strica
  // diacriticele, fiindca taie fiecare unitate UTF-16 la un octet.
  final bytes = Uint8List.fromList(utf8.encode(content));
  final blob = web.Blob([bytes.toJS].toJS, web.BlobPropertyBag(type: '$mimeType;charset=utf-8'));
  final url = web.URL.createObjectURL(blob);
  final anchor = web.document.createElement('a') as web.HTMLAnchorElement
    ..href = url
    ..download = filename;
  web.document.body!.appendChild(anchor);
  anchor.click();
  anchor.remove();
  web.URL.revokeObjectURL(url);
}
