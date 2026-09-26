import 'dart:convert';
import 'dart:typed_data';
import 'package:share_plus/share_plus.dart';

// Nu există echivalent nativ pentru "descărcare browser" - pe Android/iOS
// folosim share sheet-ul nativ, cu fișierul generat în memorie (fără să mai
// fie nevoie de path_provider ca să-l scriem întâi pe disc).
void downloadTextFile({required String filename, required String content, String mimeType = 'text/plain'}) {
  // utf8.encode, nu codeUnits: `codeUnits` dă unități UTF-16, iar
  // Uint8List.fromList le taie la 8 biți - adică orice diacritică din fișier
  // („Preț”, „Bună”) ieșea stricată.
  final bytes = Uint8List.fromList(utf8.encode(content));
  SharePlus.instance.share(
    ShareParams(files: [XFile.fromData(bytes, name: filename, mimeType: mimeType)]),
  );
}
