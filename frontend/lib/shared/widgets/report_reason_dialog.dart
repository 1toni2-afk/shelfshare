import 'package:flutter/material.dart';
import '../../core/locale/l10n_extensions.dart';
import '../../features/safety/data/safety_repository.dart';

/// Dialog reutilizabil de alegere a motivului de raportare - folosit din chat,
/// din anunțuri, din recenzii, din postările de grup și de pe un schimb.
/// Întoarce motivul ales sau null dacă userul anulează.
///
/// [target] decide ce listă de motive se oferă: „profil fals" n-are sens pe o
/// recenzie, iar „conținut fals" n-are sens pe un user. Aceeași împărțire e
/// validată și pe server (REPORT_REASONS_BY_TARGET), deci nu e doar cosmetică:
/// o pereche greșită motiv/țintă e respinsă.
class ReportReasonDialog extends StatefulWidget {
  const ReportReasonDialog({super.key, required this.target});

  final ReportTargetKind target;

  @override
  State<ReportReasonDialog> createState() => _ReportReasonDialogState();
}

class _ReportReasonDialogState extends State<ReportReasonDialog> {
  late ReportReason _reason = widget.target.reasons.first;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(l10n.reportDialogTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final reason in widget.target.reasons)
            RadioListTile<ReportReason>(
              contentPadding: EdgeInsets.zero,
              title: Text(reason.label(l10n)),
              value: reason,
              // ignore: deprecated_member_use
              groupValue: _reason,
              // ignore: deprecated_member_use
              onChanged: (value) => setState(() => _reason = value!),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.commonCancel),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(_reason),
          child: Text(l10n.commonSubmit),
        ),
      ],
    );
  }
}
