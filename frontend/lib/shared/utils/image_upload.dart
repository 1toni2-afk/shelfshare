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

/// Timeout-ul pe cererile de upload de imagini.
///
/// Clientul global are 10s (vezi api_client.dart) - potrivit pentru JSON, dar
/// nu pentru câțiva MB de poză pe un uplink mobil. Depășirea lui arunca în
/// client, DEȘI serverul termina upload-ul: la publicarea unui anunț asta
/// însemna „nu s-a adăugat nimic" pe ecran, cu anunțul creat totuși pe server
/// (bug raportat de pe web, unde toate încercările au apărut ulterior în app).
Options imageUploadOptions() {
  return Options(
    sendTimeout: const Duration(seconds: 60),
    receiveTimeout: const Duration(seconds: 60),
  );
}

/// Limitele de redimensionare la alegerea unei poze de conținut (anunț, chat,
/// starea cărții). Camera unui telefon modern scoate 8-12MB, peste limita de
/// 8MB a backendului și oricum inutil pentru o poză afișată la câteva sute de
/// px. Avatarul folosește limite proprii, mai strânse (vezi my_profile_screen).
const int kContentPhotoMaxDimension = 1600;
const int kContentPhotoQuality = 85;
