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

class BookshelfRepository {
  BookshelfRepository(this._ref);
  final Ref _ref;

  Future<Bookshelf> getMyShelf() async {
    final dio = _ref.read(apiClientProvider).dio;
    final response = await dio.get('/bookshelf/me');
    return Bookshelf.fromJson(response.data as Map<String, dynamic>);
  }

  Future<BookshelfStatus?> getStatusForBook(String bookId) async {
    final dio = _ref.read(apiClientProvider).dio;
    final response = await dio.get('/bookshelf/me/$bookId');
    final status = response.data['status'] as String?;
    return status != null ? BookshelfStatusX.fromJson(status) : null;
  }

  Future<void> setStatus(String bookId, BookshelfStatus status) async {
    final dio = _ref.read(apiClientProvider).dio;
    await dio.put('/bookshelf/$bookId', data: {'status': status.toJson()});
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
