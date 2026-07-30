import 'package:dio/dio.dart';

/// Construiește partea de multipart pentru o imagine, cu `Content-Type` corect.
///
/// De ce e nevoie de un helper: `MultipartFile.fromBytes` din dio pune implicit
/// `application/octet-stream`, nu deduce tipul din numele fișierului. Backend-ul
/// verifică `file.mimetype.startsWith('image/')` pe toate cele trei rute de
/// upload de imagini (profil, poze de carte, poze în chat), deci fără tipul
/// explicit fiecare upload primea `400 „Fișierul trebuie să fie o imagine"` -
/// iar Nest nu loghează 4xx, așa că eroarea nu apărea nici în logurile
/// serverului.
MultipartFile imageMultipartFile(List<int> bytes, String filename) {
  final safeName = filename.trim().isEmpty ? 'photo.jpg' : filename.trim();
  return MultipartFile.fromBytes(
    bytes,
    filename: safeName,
    contentType: DioMediaType('image', _subtypeFor(safeName)),
  );
}

String _subtypeFor(String filename) {
  final dot = filename.lastIndexOf('.');
  final extension = dot == -1 ? '' : filename.substring(dot + 1).toLowerCase();
  switch (extension) {
    case 'png':
      return 'png';
    case 'gif':
      return 'gif';
    case 'webp':
      return 'webp';
    case 'heic':
      return 'heic';
    case 'heif':
      return 'heif';
    case 'bmp':
      return 'bmp';
    // image_picker întoarce uneori nume fără extensie (mai ales pe web); jpeg e
    // formatul în care comprimăm oricum înainte de upload.
    default:
      return 'jpeg';
  }
}
