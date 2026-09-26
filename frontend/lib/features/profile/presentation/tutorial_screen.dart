import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/locale/l10n_extensions.dart';
import '../../../core/theme/app_theme.dart';
import '../../../l10n/app_localizations.dart';
import '../application/onboarding_todo_controller.dart';
import 'onboarding_illustrations.dart';

/// Turul vizual scurt: cinci ecrane cu o ilustrație și două-trei rânduri de
/// text, despre ce e aplicația și ce poate face omul cu ea.
///
/// Nu se suprapune cu „Cum funcționează" (about_app_screen.dart): acolo sunt
/// explicații lungi, căutate de cineva care are deja o întrebare (XP, trust
/// score, insigne). Aici e primul contact - se citește în jumătate de minut,
/// din listă de pe Home sau din meniul de setări, și se poate închide oricând.
///
/// Ilustrațiile sunt desenate din widget-uri, nu din imagini: rămân clare la
/// orice densitate, se colorează singure în light/dark și nu adaugă nimic la
/// dimensiunea bundle-ului (vezi și onboarding_illustrations.dart).
class TutorialScreen extends ConsumerStatefulWidget {
  const TutorialScreen({super.key});

  @override
  ConsumerState<TutorialScreen> createState() => _TutorialScreenState();
}

class _TutorialScreenState extends ConsumerState<TutorialScreen> {
  final _controller = PageController();
  int _page = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  List<_TutorialPage> _pages(AppLocalizations l10n) => [
        _TutorialPage(
          illustration: const BookshelfIllustration(),
          title: l10n.tutorialShelfTitle,
          body: l10n.tutorialShelfBody,
        ),
        _TutorialPage(
          illustration: const _MatchIllustration(),
          title: l10n.tutorialMatchTitle,
          body: l10n.tutorialMatchBody,
        ),
        _TutorialPage(
          illustration: const _SwapIllustration(),
          title: l10n.tutorialSwapTitle,
          body: l10n.tutorialSwapBody,
        ),
        _TutorialPage(
          illustration: const _WishlistIllustration(),
          title: l10n.tutorialWishlistTitle,
          body: l10n.tutorialWishlistBody,
        ),
        _TutorialPage(
          illustration: const _ShortcutsIllustration(),
          title: l10n.tutorialShortcutsTitle,
          body: l10n.tutorialShortcutsBody,
        ),
      ];

  void _close() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/');
    }
  }

  void _next(int total) {
    if (_page >= total - 1) {
      ref.read(onboardingTodoProvider.notifier).complete(OnboardingTodo.tutorial);
      _close();
      return;
    }
    _controller.nextPage(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final pages = _pages(l10n);
    final isLast = _page == pages.length - 1;

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Text(l10n.tutorialTitle),
        actions: [
          TextButton(
            onPressed: _close,
            child: Text(l10n.tutorialSkip),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Column(
              children: [
                Expanded(
                  child: PageView.builder(
                    controller: _controller,
                    itemCount: pages.length,
                    onPageChanged: (index) => setState(() => _page = index),
                    itemBuilder: (context, index) => pages[index],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          for (var i = 0; i < pages.length; i++)
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              margin: const EdgeInsets.symmetric(horizontal: 3),
                              width: i == _page ? 18 : 7,
                              height: 7,
                              decoration: BoxDecoration(
                                color: i == _page
                                    ? AppColors.accent
                                    : AppColors.mutedForeground.withValues(alpha: 0.35),
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: () => _next(pages.length),
                          child: Text(isLast ? l10n.tutorialDone : l10n.tutorialNext),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TutorialPage extends StatelessWidget {
  const _TutorialPage({
    required this.illustration,
    required this.title,
    required this.body,
  });

  final Widget illustration;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    // Scrollabil, nu Column fix: pe un telefon mic în landscape ilustrația plus
    // două paragrafe depășesc înălțimea și ecranul ar da overflow galben.
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(28, 24, 28, 8),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(height: 170, child: Center(child: illustration)),
          const SizedBox(height: 28),
          Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Text(
            body,
            textAlign: TextAlign.center,
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: AppColors.mutedForeground, height: 1.5),
          ),
        ],
      ),
    );
  }
}

/// Book Match: două cărți în teanc, ușor rotite, cu inima pe cea din față -
/// exact gestul din ecranul de swipe.
class _MatchIllustration extends StatelessWidget {
  const _MatchIllustration();

  @override
  Widget build(BuildContext context) {
    // Lățime fixată, nu toată pagina: `Positioned` se măsoară față de Stack,
    // iar într-un Stack cât ecranul insigna cu inima ar pluti la câțiva zeci
    // de pixeli de teancul de cărți, altfel pe fiecare lățime de fereastră.
    return SizedBox(
      width: 150,
      height: 150,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Transform.rotate(
            angle: -0.18,
            child: _card(AppColors.primary.withValues(alpha: 0.35)),
          ),
          Transform.rotate(
            angle: 0.10,
            child: _card(AppColors.accent),
          ),
          Positioned(
            right: 18,
            bottom: 14,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.card,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 8,
                  ),
                ],
              ),
              child: Icon(Icons.favorite, color: AppColors.destructive, size: 20),
            ),
          ),
        ],
      ),
    );
  }

  Widget _card(Color color) {
    return Container(
      width: 92,
      height: 128,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Icon(Icons.menu_book_rounded, color: Colors.white70, size: 34),
    );
  }
}

/// Schimbul: doi oameni, două cărți, săgețile între ei.
class _SwapIllustration extends StatelessWidget {
  const _SwapIllustration();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _person(AppColors.primary, Icons.menu_book_rounded),
        const SizedBox(width: 16),
        Icon(Icons.swap_horiz, size: 34, color: AppColors.accent),
        const SizedBox(width: 16),
        _person(AppColors.accent, Icons.auto_stories),
      ],
    );
  }

  Widget _person(Color color, IconData bookIcon) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CircleAvatar(
          radius: 24,
          backgroundColor: color.withValues(alpha: 0.18),
          child: Icon(Icons.person, color: color, size: 26),
        ),
        const SizedBox(height: 10),
        Container(
          width: 42,
          height: 56,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(bookIcon, color: Colors.white70, size: 20),
        ),
      ],
    );
  }
}

/// Favorite + alertă: inima cu clopoțelul peste ea.
class _WishlistIllustration extends StatelessWidget {
  const _WishlistIllustration();

  @override
  Widget build(BuildContext context) {
    // Vezi comentariul din _MatchIllustration: clopoțelul trebuie să stea
    // lipit de inimă, nu de marginea ecranului.
    return SizedBox(
      width: 150,
      height: 150,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 118,
            height: 118,
            decoration: BoxDecoration(
              color: AppColors.destructive.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.favorite, color: AppColors.destructive, size: 52),
          ),
          Positioned(
            right: 6,
            top: 10,
            child: Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: AppColors.accent,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.notifications_active,
                  color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }
}

/// Scurtăturile: o bucată de meniu, cu ultimul rând gol și un „+".
class _ShortcutsIllustration extends StatelessWidget {
  const _ShortcutsIllustration();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 190,
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _row(Icons.auto_stories_outlined, AppColors.primary, 0.9),
          _row(Icons.swap_horiz_outlined, AppColors.primary, 0.7),
          _row(Icons.favorite_border, AppColors.primary, 0.55),
          const SizedBox(height: 4),
          _row(Icons.add, AppColors.accent, 0.35, dashed: true),
        ],
      ),
    );
  }

  Widget _row(IconData icon, Color color, double barWidth, {bool dashed = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: barWidth,
              child: Container(
                height: 7,
                decoration: BoxDecoration(
                  color: dashed
                      ? color.withValues(alpha: 0.25)
                      : AppColors.mutedForeground.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
