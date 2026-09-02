import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/providers.dart';
import '../../../data/models/book.dart';

class BookshelfImportResult {
  final int imported;
  final int skipped;
  final int total;

  const BookshelfImportResult({required this.imported, required this.skipped, required this.total});

  factory BookshelfImportResult.fromJson(Map<String, dynamic> json) {
    return BookshelfImportResult(
      imported: json['imported'] as int,
      skipped: json['skipped'] as int,
      total: json['total'] as int,
    );
  }
}

class GenreCount {
  final String genre;
  final int count;

  const GenreCount({required this.genre, required this.count});

  factory GenreCount.fromJson(Map<String, dynamic> json) {
    return GenreCount(
      genre: json['genre'] as String,
      count: (json['count'] as num).toInt(),
    );
  }
}

class BookshelfRepository {
  BookshelfRepository(this._ref);
  final Ref _ref;

  Future<Bookshelf> getMyShelf() async {
    final dio = _ref.read(apiClientProvider).dio;
    final response = await dio.get('/bookshelf/me');
    return Bookshelf.fromJson(response.data as Map<String, dynamic>);
  }

  /// Cărțile deținute dar nelistate - prim-planul din My Shelf.
  Future<List<OwnedBook>> getOwnedShelf() async {
    final dio = _ref.read(apiClientProvider).dio;
    final response = await dio.get('/bookshelf/me/owned');
    return (response.data as List)
        .map((e) => OwnedBook.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// „Add to shelf" - adaugă o carte ca deținută, fără să creeze un anunț.
  /// `percentRead` e alternativa la `currentPage` pentru cine știe doar cât la
  /// sută a citit; backendul îl convertește în pagini.
  Future<void> addOwnedBook({
    required String title,
    String? author,
    String? isbn,
    String? coverUrl,
    String? genre,
    String? publisher,
    int? publishedYear,
    BookshelfStatus status = BookshelfStatus.reading,
    int? totalPages,
    int? currentPage,
    int? percentRead,
  }) async {
    final dio = _ref.read(apiClientProvider).dio;
    // Câmpurile goale devin null, nu string gol: validatorii backendului
    // (@IsISBN, @MaxLength) resping un "" trimis explicit.
    String? clean(String? value) =>
        (value == null || value.trim().isEmpty) ? null : value.trim();
    await dio.post('/bookshelf/own', data: {
      'title': title,
      'author': ?clean(author),
      'isbn': ?clean(isbn),
      'coverUrl': ?clean(coverUrl),
      'genre': ?clean(genre),
      'publisher': ?clean(publisher),
      'publishedYear': ?publishedYear,
      'status': status.toJson(),
      'totalPages': ?totalPages,
      'currentPage': ?currentPage,
      'percentRead': ?percentRead,
    });
  }

  Future<List<GenreCount>> getGenreDistribution() async {
    final dio = _ref.read(apiClientProvider).dio;
    final response = await dio.get('/bookshelf/me/genres');
    return (response.data as List)
        .map((e) => GenreCount.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<BookshelfStatus?> getStatusForBook(String bookId) async {
    final dio = _ref.read(apiClientProvider).dio;
    final response = await dio.get('/bookshelf/me/$bookId');
    final status = response.data['status'] as String?;
    return status != null ? BookshelfStatusX.fromJson(status) : null;
  }

  Future<void> setStatus(String bookId, BookshelfStatus status, {bool? owned}) async {
    final dio = _ref.read(apiClientProvider).dio;
    await dio.put('/bookshelf/$bookId', data: {
      'status': status.toJson(),
      'owned': ?owned,
    });
  }

  Future<void> removeFromShelf(String bookId) async {
    final dio = _ref.read(apiClientProvider).dio;
    await dio.delete('/bookshelf/$bookId');
  }

  /// Import dintr-un export CSV Goodreads/StoryGraph - fișierul poate avea
  /// câteva mii de rânduri, deci mărim timeout-ul peste cel implicit de 10s
  /// al clientului Dio (vezi api_client.dart).
  Future<BookshelfImportResult> importCsv(
    String source, {
    required List<int> bytes,
    required String filename,
  }) async {
    final dio = _ref.read(apiClientProvider).dio;
    final formData = FormData.fromMap({
      'file': MultipartFile.fromBytes(bytes, filename: filename.isEmpty ? 'import.csv' : filename),
    });
    final response = await dio.post(
      '/bookshelf/import/$source',
      data: formData,
      options: Options(sendTimeout: const Duration(seconds: 60), receiveTimeout: const Duration(seconds: 60)),
    );
    return BookshelfImportResult.fromJson(response.data as Map<String, dynamic>);
  }
}

final bookshelfRepositoryProvider = Provider<BookshelfRepository>((ref) {
  return BookshelfRepository(ref);
});

/// Raftul propriu al userului curent (READING / WANT_TO_READ / FINISHED).
/// Cache-uit prin FutureProvider - se auto-invalidează când `ProviderScope`
/// se rebuiește (ex. la logout/login).
final myBookshelfProvider = FutureProvider<Bookshelf>((ref) {
  return ref.watch(bookshelfRepositoryProvider).getMyShelf();
});

/// Cărțile deținute dar nelistate, afișate în prim-planul din My Shelf.
final myOwnedShelfProvider = FutureProvider<List<OwnedBook>>((ref) {
  return ref.watch(bookshelfRepositoryProvider).getOwnedShelf();
});

/// Top 5 genuri din raftul propriu - alimentează graficul radar din My Shelf.
final myGenreDistributionProvider = FutureProvider<List<GenreCount>>((ref) {
  return ref.watch(bookshelfRepositoryProvider).getGenreDistribution();
});
