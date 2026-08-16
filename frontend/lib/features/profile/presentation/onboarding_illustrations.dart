import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

/// Ilustrație simplă, desenată din widget-uri Flutter (nu un asset extern) -
/// un rând de cărți așezate pe un raft, cu un ghiveci și o cană alături.
/// Ton vizual "friendly" pentru ecranele de bun venit/mulțumire ale
/// wizard-ului de onboarding, cu culorile temei (nu cele din mockup-ul de
/// referință, ca să rămână coerentă cu light/dark mode).
class BookshelfIllustration extends StatelessWidget {
  const BookshelfIllustration({super.key});

  static const _books = [
    (height: 74.0, color: AppColors.primary),
    (height: 92.0, color: AppColors.accent),
    (height: 64.0, color: AppColors.primary),
    (height: 86.0, color: AppColors.accent),
    (height: 70.0, color: AppColors.primary),
  ];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 130,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (final book in _books)
                Container(
                  width: 20,
                  height: book.height,
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  decoration: BoxDecoration(
                    color: book.color,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(3),
                      topRight: Radius.circular(3),
                    ),
                  ),
                ),
              const SizedBox(width: 14),
              Icon(Icons.local_florist_outlined, color: AppColors.success, size: 30),
              const SizedBox(width: 10),
              Icon(Icons.coffee_outlined, color: AppColors.mutedForeground, size: 22),
            ],
          ),
          const SizedBox(height: 6),
          Container(
            height: 4,
            width: 230,
            decoration: BoxDecoration(
              color: AppColors.mutedForeground.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ],
      ),
    );
  }
}
