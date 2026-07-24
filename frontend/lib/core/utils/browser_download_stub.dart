import 'dart:typed_data';
import 'package:share_plus/share_plus.dart';

// Nu există echivalent nativ pentru "descărcare browser" - pe Android/iOS
// folosim share sheet-ul nativ, cu fișierul generat în memorie (fără să mai
// fie nevoie de path_provider ca să-l scriem întâi pe disc).
void downloadTextFile({required String filename, required String content, String mimeType = 'text/plain'}) {
  final bytes = Uint8List.fromList(content.codeUnits);
  SharePlus.instance.share(
    ShareParams(files: [XFile.fromData(bytes, name: filename, mimeType: mimeType)]),
  );
}
