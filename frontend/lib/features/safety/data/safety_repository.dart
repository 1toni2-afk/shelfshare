import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/providers.dart';
import '../../../l10n/app_localizations.dart';

/// Ce anume se raporteaza. Decide ce motive se ofera - vezi
/// [ReportReasonsX.reasonsFor] si REPORT_REASONS_BY_TARGET pe backend, care
/// valideaza aceeasi impartire (o pereche gresita motiv/tinta e respinsa).
enum ReportTargetKind {
  /// Anunt, recenzie, postare de grup, conversatie.
  content,

  /// Un user, sau un schimb care nu s-a respectat.
  user,
}

enum ReportReason {
  spam,
  scam,
  inappropriate,
  harassment,
  other,
  abusiveLanguage,
  falseContent,
  fakeProfile,
}

extension ReportReasonsX on ReportTargetKind {
  /// Motivele oferite pentru acest tip de tinta, in ordinea de afisare.
  /// „Altceva" sta mereu la final.
  List<ReportReason> get reasons {
    switch (this) {
      case ReportTargetKind.content:
        return const [
          ReportReason.spam,
          ReportReason.abusiveLanguage,
          ReportReason.falseContent,
          ReportReason.inappropriate,
          ReportReason.other,
        ];
      case ReportTargetKind.user:
        return const [
          ReportReason.harassment,
          ReportReason.scam,
          ReportReason.fakeProfile,
          ReportReason.other,
        ];
    }
  }
}

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
      case ReportReason.abusiveLanguage:
        return 'ABUSIVE_LANGUAGE';
      case ReportReason.falseContent:
        return 'FALSE_CONTENT';
      case ReportReason.fakeProfile:
        return 'FAKE_PROFILE';
    }
  }

  /// Textele erau hardcodate in romana, desi aplicatia are patru limbi -
  /// acum vin din ARB, ca orice alt text vizibil.
  String label(AppLocalizations l10n) {
    switch (this) {
      case ReportReason.spam:
        return l10n.reportReasonSpam;
      case ReportReason.scam:
        return l10n.reportReasonScam;
      case ReportReason.inappropriate:
        return l10n.reportReasonInappropriate;
      case ReportReason.harassment:
        return l10n.reportReasonHarassment;
      case ReportReason.other:
        return l10n.reportReasonOther;
      case ReportReason.abusiveLanguage:
        return l10n.reportReasonAbusiveLanguage;
      case ReportReason.falseContent:
        return l10n.reportReasonFalseContent;
      case ReportReason.fakeProfile:
        return l10n.reportReasonFakeProfile;
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
