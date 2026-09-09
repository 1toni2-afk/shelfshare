import 'dart:math';

import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

/// Mottouri despre sustenabilitate, afișate random pe empty state-uri și
/// ecrane de loading (vezi [MottoText]) - vocea de brand a aplicației, nu
/// conținut funcțional, deci rămân text fix în română peste tot, la fel ca
/// `loginMadeWithLove`, nu trec prin l10n.
const List<String> sustainabilityMottos = [
  'O carte. Mai multe vieți.',
  'Cărțile circulă. Poveștile rămân.',
  'Cărțile nu se termină. Se dau mai departe.',
  'Citește. Schimbă. Repetă.',
  'Cărți care merg mai departe.',
  'Lasă cartea să circule.',
  'Dă-o mai departe. Citește mai departe.',
  'Mai puține rafturi pline. Mai multe povești citite.',
  'Cărți pentru oameni, nu pentru rafturi.',
  'O poveste nu aparține unui singur cititor.',
];

/// O linie de motto, aleasă o singură dată per widget - fixată în [initState]
/// (via `late final`), nu recalculată la fiecare rebuild, altfel ar sări pe
/// alt text de fiecare dată când părintele se reconstruiește (ex. la fiecare
/// tick al unui Riverpod provider).
class MottoText extends StatefulWidget {
  const MottoText({super.key, this.style});
  final TextStyle? style;

  @override
  State<MottoText> createState() => _MottoTextState();
}

class _MottoTextState extends State<MottoText> {
  late final String _motto = sustainabilityMottos[Random().nextInt(sustainabilityMottos.length)];

  @override
  Widget build(BuildContext context) {
    return Text(
      _motto,
      textAlign: TextAlign.center,
      style: widget.style ??
          Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.mutedForeground,
                fontStyle: FontStyle.italic,
              ),
    );
  }
}
