import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/admin_models.dart';
import '../../../data/models/user_book.dart';
import '../../../shared/widgets/centered_scrollable.dart';
import '../../books/data/books_repository.dart';
import '../data/admin_repository.dart';

const _kCountLabels = <String, String>{
  'UNIQUE_VIEW': 'Vizitatori unici',
  'RETURN_VISIT': 'Reveniri',
  'WISHLIST_ADD': 'Adăugări la favorite',
  'EXCHANGE_REQUEST': 'Cereri de schimb',
  'BUY_OFFER': 'Oferte de preț',
  'REVIEW': 'Refresh-uri (vechi, ignorate)',
};

/// Panou de admin: caută un anunț după titlu, arată breakdown-ul scorului de
/// interes (popularity + exchange potential) și permite suprascrierea
/// manuală a scorului de popularitate. Vezi backend/src/books/listing-score.
/// service.ts și AdminService.getListingScore/setListingScoreOverride.
///
/// Scorul nu e vizibil userilor normali - acest ecran e singurul loc din
/// aplicație unde apare.
class ListingScoreScreen extends ConsumerStatefulWidget {
  const ListingScoreScreen({super.key});

  @override
  ConsumerState<ListingScoreScreen> createState() => _ListingScoreScreenState();
}

class _ListingScoreScreenState extends ConsumerState<ListingScoreScreen> {
  final _searchController = TextEditingController();
  final _overrideController = TextEditingController();
  Timer? _debounce;

  List<UserBook> _results = const [];
  bool _searching = false;
  bool _searched = false;

  String? _selectedUserBookId;
  ListingScoreBreakdown? _breakdown;
  bool _loadingScore = false;
  bool _saving = false;

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _overrideController.dispose();
    super.dispose();
  }

  void _onQueryChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () => _search(value));
  }

  Future<void> _search(String query) async {
    final trimmed = query.trim();
    if (trimmed.length < 2) {
      if (!mounted) return;
      setState(() {
        _results = const [];
        _searched = false;
      });
      return;
    }

    setState(() => _searching = true);
    try {
      final result = await ref.read(booksRepositoryProvider).browse(
            title: trimmed,
            limit: 20,
          );
      if (!mounted) return;
      setState(() {
        _results = result.items;
        _searched = true;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _results = const [];
        _searched = true;
      });
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  Future<void> _selectListing(UserBook listing) async {
    setState(() {
      _selectedUserBookId = listing.id;
      _loadingScore = true;
      _breakdown = null;
      _overrideController.clear();
    });
    try {
      final data = await ref.read(adminRepositoryProvider).getListingScore(listing.id);
      if (!mounted) return;
      setState(() {
        _breakdown = data;
        _overrideController.text = data.manualScoreOverride?.toString() ?? '';
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nu am putut încărca scorul acestui anunț.')),
      );
    } finally {
      if (mounted) setState(() => _loadingScore = false);
    }
  }

  Future<void> _saveOverride() async {
    final userBookId = _selectedUserBookId;
    if (userBookId == null) return;

    final raw = _overrideController.text.trim();
    final score = raw.isEmpty ? null : double.tryParse(raw);
    if (raw.isNotEmpty && score == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Scorul trebuie să fie un număr.')),
      );
      return;
    }

    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final updated = await ref
          .read(adminRepositoryProvider)
          .setListingScoreOverride(userBookId, score);
      if (!mounted) return;
      setState(() {
        _breakdown = updated;
        _overrideController.text = updated.manualScoreOverride?.toString() ?? '';
      });
      messenger.showSnackBar(SnackBar(
        content: Text(score == null ? 'Override eliminat.' : 'Override salvat.'),
      ));
    } catch (_) {
      messenger.showSnackBar(const SnackBar(content: Text('Salvarea a eșuat.')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final breakdown = _breakdown;

    return Scaffold(
      appBar: AppBar(title: const Text('Scor de interes anunț')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              'Caută un anunț după titlul cărții ca să vezi breakdown-ul scorului de '
              'popularitate și de potențial de schimb, sau să suprascrii manual scorul.',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: AppColors.mutedForeground),
            ),
            const SizedBox(height: 16),
            TextField(
              textAlignVertical: TextAlignVertical.center,
              controller: _searchController,
              onChanged: _onQueryChanged,
              decoration: InputDecoration(
                hintText: 'Titlul cărții...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searching
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : null,
              ),
            ),
            const SizedBox(height: 12),
            if (_searched && _results.isEmpty)
              const Text('Niciun anunț găsit.')
            else
              for (final result in _results)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  selected: result.id == _selectedUserBookId,
                  title: Text(result.book.title, overflow: TextOverflow.ellipsis),
                  subtitle: Text(
                    result.book.author ?? 'Autor necunoscut',
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: result.id == _selectedUserBookId
                      ? const Icon(Icons.check)
                      : null,
                  onTap: () => _selectListing(result),
                ),
            const SizedBox(height: 20),
            if (_selectedUserBookId == null)
              Text(
                'Caută un anunț mai sus ca să-i vezi scorul.',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: AppColors.mutedForeground),
              )
            else if (_loadingScore)
              const CenteredScrollable(child: CircularProgressIndicator())
            else if (breakdown != null) ...[
              Text(breakdown.bookTitle, style: Theme.of(context).textTheme.titleMedium),
              if (breakdown.bookAuthor != null)
                Text(
                  breakdown.bookAuthor!,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: AppColors.mutedForeground),
                ),
              const SizedBox(height: 16),
              _ScoreTile(
                label: 'Popularitate',
                value: breakdown.popularityScore,
                highlighted: breakdown.manualScoreOverride != null,
              ),
              const SizedBox(height: 8),
              _ScoreTile(
                label: 'Potențial de schimb',
                value: breakdown.exchangePotentialScore,
              ),
              const SizedBox(height: 16),
              Text('Evenimente (ultimele 30 de zile)',
                  style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 4),
              for (final entry in breakdown.counts.entries)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(_kCountLabels[entry.key] ?? entry.key),
                      Text('${entry.value}'),
                    ],
                  ),
                ),
              if (breakdown.counts.isEmpty)
                Text(
                  'Niciun eveniment în ultimele 30 de zile.',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: AppColors.mutedForeground),
                ),
              const SizedBox(height: 20),
              Text('Suprascriere manuală (popularitate)',
                  style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 4),
              Text(
                'Gol = fără override, se folosește scorul calculat.',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: AppColors.mutedForeground),
              ),
              const SizedBox(height: 8),
              TextField(
                textAlignVertical: TextAlignVertical.center,
                controller: _overrideController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(hintText: 'ex: 87'),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: _saving ? null : _saveOverride,
                child: _saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Salvează'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ScoreTile extends StatelessWidget {
  const _ScoreTile({required this.label, required this.value, this.highlighted = false});

  final String label;
  final double value;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      color: highlighted ? AppColors.primary.withValues(alpha: 0.08) : null,
      child: ListTile(
        title: Text(label),
        subtitle: highlighted ? const Text('Override manual activ') : null,
        trailing: Text(
          value.toStringAsFixed(1),
          style: Theme.of(context).textTheme.titleLarge,
        ),
      ),
    );
  }
}
