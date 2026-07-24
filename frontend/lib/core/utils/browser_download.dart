// package:web (dart:js_interop) nu compilează pentru ținte non-web
// (Android/iOS/desktop) - de-abia la prima compilare pentru Android a ieșit
// la iveală, fiindcă până acum aplicația a rulat doar pe web. Import
// condiționat: implementarea reală doar când compilăm pentru web, altfel
// share sheet-ul nativ (vezi browser_download_stub.dart).
export 'browser_download_stub.dart' if (dart.library.js_interop) 'browser_download_web.dart';
