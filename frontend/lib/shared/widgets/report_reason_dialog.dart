import 'package:flutter/material.dart';
import '../../core/locale/l10n_extensions.dart';
import '../../features/safety/data/safety_repository.dart';

/// Dialog reutilizabil de alegere a motivului de raportare - folosit atât
/// din chat (raportare user), cât și din detaliile unei cărți (raportare
/// anunț). Întoarce motivul ales sau null dacă userul anulează.
class ReportReasonDialog extends StatefulWidget {
  const ReportReasonDialog({super.key});

  @override
  State<ReportReasonDialog> createState() => _ReportReasonDialogState();
}

class _ReportReasonDialogState extends State<ReportReasonDialog> {
  ReportReason _reason = ReportReason.spam;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(l10n.reportDialogTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final reason in ReportReason.values)
            RadioListTile<ReportReason>(
              contentPadding: EdgeInsets.zero,
              title: Text(reason.label),
              value: reason,
              // ignore: deprecated_member_use
              groupValue: _reason,
              // ignore: deprecated_member_use
              onChanged: (value) => setState(() => _reason = value!),
            ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(l10n.commonCancel)),
        TextButton(
          onPressed: () => Navigator.of(context).pop(_reason),
          child: Text(l10n.commonSubmit),
        ),
      ],
    );
  }
}
