import '../../core/network/api_client.dart';

const _kProxiedHosts = {'books.google.com', 'books.googleusercontent.com'};

/// Coperțile de la Google Books nu trimit `Access-Control-Allow-Origin`
/// (verificat manual - Open Library da, Google Books nu), iar pe Flutter Web
/// randarea prin CanvasKit cere bytes-ii imaginii printr-un fetch supus CORS,
/// nu un simplu `<img>` - fără header-ul de CORS, browserul blochează
/// răspunsul și coperta pică pe placeholder-ul generat din titlu, deși URL-ul
/// era corect și imaginea exista.
///
/// Rescrie un asemenea URL ca să treacă prin proxy-ul nostru (vezi
/// `BooksController.proxyCover` pe backend), care servește bytes-ii de pe
/// domeniul propriu, unde CORS-ul global al API-ului deja se aplică. Alte
/// surse (Open Library, storage-ul nostru) rămân neschimbate.
String? coverProxyUrl(String? url) {
  if (url == null || url.isEmpty) return url;
  final uri = Uri.tryParse(url);
  if (uri == null || !_kProxiedHosts.contains(uri.host)) return url;
  return '${ApiConfig.baseUrl}/books/cover-proxy?url=${Uri.encodeQueryComponent(url)}';
}
