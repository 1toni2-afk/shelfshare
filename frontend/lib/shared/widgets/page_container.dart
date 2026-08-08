import 'package:flutter/material.dart';

/// Lățimea maximă unificată pentru paginile „simple" (liste, formulare,
/// text) - fiecare ecran avea până acum propria lățime aleasă separat
/// (Settings ~350px pe un monitor de 1920px, Search lipit de sidebar,
/// Safety center/FAQ/Pre-register complet nemărginite) - Milestone 23.
const kPageContentMaxWidth = 1400.0;

/// Centrează conținutul unei pagini la [kPageContentMaxWidth], cu padding
/// orizontal implicit de 32px. Un singur loc care definește „cât de lat e un
/// ecran" - schimbă-l aici, nu în fiecare ecran în parte.
class PageContainer extends StatelessWidget {
  const PageContainer({
    super.key,
    required this.child,
    this.horizontalPadding = 32,
  });

  final Widget child;
  final double horizontalPadding;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: kPageContentMaxWidth),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
          child: child,
        ),
      ),
    );
  }
}
