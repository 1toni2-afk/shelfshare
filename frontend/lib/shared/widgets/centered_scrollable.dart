import 'package:flutter/material.dart';

/// Conținut scrollabil chiar și când e gol/în eroare, altfel RefreshIndicator
/// nu ar avea cum să detecteze gestul de tragere.
class CenteredScrollable extends StatelessWidget {
  const CenteredScrollable({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(
          height: MediaQuery.of(context).size.height * 0.6,
          child: Center(child: child),
        ),
      ],
    );
  }
}
