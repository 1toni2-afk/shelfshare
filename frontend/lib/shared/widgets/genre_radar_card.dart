import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/locale/l10n_extensions.dart';
import '../../core/theme/app_theme.dart';
import '../../features/books/data/bookshelf_repository.dart';
import '../utils/genre_localization.dart';

/// Cardul cu top 5 genuri din preferințele userului (raft + cărți listate +
/// wishlist), ca grafic radar - vezi GET /bookshelf/me/genres
/// (backend/src/bookshelf/bookshelf.service.ts). Trăia inițial doar în
/// „Raftul meu de cărți" (/bookshelf, un ecran secundar accesat din Setări),
/// dar userii ajung firesc pe „Raftul meu" (/library, tab-ul principal din
/// bara de jos) - mutat acolo, sub rezumatul raftului, ca să fie găsit fără
/// să știi dinainte că cele două ecrane cu nume aproape identice sunt diferite.
class GenreRadarCard extends ConsumerWidget {
  const GenreRadarCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final async = ref.watch(myGenreDistributionProvider);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l10n.bookshelfGenreChartTitle, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            async.when(
              data: (genres) {
                // Sub 3 puncte, un radar nu are formă (degenerează într-o
                // linie/punct) - preferăm mesajul gol în loc de un grafic
                // ilizibil.
                if (genres.length < 3) {
                  return SizedBox(
                    height: 160,
                    child: Center(
                      child: Text(
                        l10n.bookshelfGenreChartEmpty,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  );
                }
                final maxCount = genres.map((g) => g.count).reduce((a, b) => a > b ? a : b);
                return SizedBox(
                  height: 220,
                  child: RadarChart(
                    RadarChartData(
                      radarShape: RadarShape.polygon,
                      tickCount: maxCount < 4 ? maxCount : 4,
                      ticksTextStyle: const TextStyle(color: Colors.transparent, fontSize: 0),
                      radarBorderData: BorderSide(color: AppColors.mutedForeground.withValues(alpha: 0.3)),
                      gridBorderData: BorderSide(color: AppColors.mutedForeground.withValues(alpha: 0.2)),
                      tickBorderData: const BorderSide(color: Colors.transparent),
                      getTitle: (index, angle) => RadarChartTitle(
                        text: localizedGenre(context, genres[index].genre),
                      ),
                      titleTextStyle: Theme.of(context)
                          .textTheme
                          .labelSmall
                          ?.copyWith(color: AppColors.mutedForeground),
                      dataSets: [
                        RadarDataSet(
                          fillColor: AppColors.primary.withValues(alpha: 0.25),
                          borderColor: AppColors.primary,
                          borderWidth: 2,
                          entryRadius: 3,
                          dataEntries: [
                            for (final g in genres) RadarEntry(value: g.count.toDouble()),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
              loading: () => const SizedBox(
                height: 220,
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (error, _) => SizedBox(
                height: 160,
                child: Center(
                  child: Text(l10n.bookshelfLoadError, style: Theme.of(context).textTheme.bodySmall),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
