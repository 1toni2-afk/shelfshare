import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/providers.dart';

enum ReportReason { spam, scam, inappropriate, harassment, other }

extension ReportReasonX on ReportReason {
  String toJson() {
    switch (this) {
      case ReportReason.spam:
        return 'SPAM';
      case ReportReason.scam:
        return 'SCAM';
      case ReportReason.inappropriate:
        return 'INAPPROPRIATE';
      case ReportReason.harassment:
        return 'HARASSMENT';
      case ReportReason.other:
        return 'OTHER';
    }
  }

  String get label {
    switch (this) {
      case ReportReason.spam:
        return 'Spam';
      case ReportReason.scam:
        return 'Înșelătorie';
      case ReportReason.inappropriate:
        return 'Conținut nepotrivit';
      case ReportReason.harassment:
        return 'Hărțuire';
      case ReportReason.other:
        return 'Altceva';
    }
  }
}

class BlockStatus {
  const BlockStatus({required this.blockedByMe, required this.blockedByThem});
  final bool blockedByMe;
  final bool blockedByThem;

  factory BlockStatus.fromJson(Map<String, dynamic> json) {
    return BlockStatus(
      blockedByMe: json['blockedByMe'] as bool,
      blockedByThem: json['blockedByThem'] as bool,
    );
  }
}

class SafetyRepository {
  SafetyRepository(this._ref);
  final Ref _ref;

  Future<BlockStatus> getBlockStatus(String userId) async {
    final dio = _ref.read(apiClientProvider).dio;
    final response = await dio.get('/users/$userId/block');
    return BlockStatus.fromJson(response.data as Map<String, dynamic>);
  }

  Future<void> blockUser(String userId) async {
    final dio = _ref.read(apiClientProvider).dio;
    await dio.post('/users/$userId/block');
  }

  Future<void> unblockUser(String userId) async {
    final dio = _ref.read(apiClientProvider).dio;
    await dio.delete('/users/$userId/block');
  }

  Future<void> reportUser(
    String userId, {
    required ReportReason reason,
    String? details,
    String? userBookId,
  }) async {
    final dio = _ref.read(apiClientProvider).dio;
    await dio.post('/users/$userId/report', data: {
      'reason': reason.toJson(),
      if (details != null && details.isNotEmpty) 'details': details,
      'userBookId': ?userBookId,
    });
  }
}

final safetyRepositoryProvider = Provider<SafetyRepository>((ref) {
  return SafetyRepository(ref);
});
