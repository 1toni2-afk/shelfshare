import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

/// Etichetă deasupra câmpului. Tema aplicației folosește
/// `FloatingLabelBehavior.never` (vezi app_theme.dart), deci un `labelText`
/// dispare de îndată ce câmpul are text - inutilizabil pentru câmpuri
/// numerice precompletate, unde userul trebuie să știe ce înseamnă cifra.
class FieldLabel extends StatelessWidget {
  const FieldLabel(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 6),
      child: Text(
        text,
        style: Theme.of(context)
            .textTheme
            .labelLarge
            ?.copyWith(color: AppColors.mutedForeground),
      ),
    );
  }
}
