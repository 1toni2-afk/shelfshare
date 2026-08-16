import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/locale/l10n_extensions.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/admin_models.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/centered_scrollable.dart';
import '../data/admin_repository.dart';

/// Eticheta afișată pentru o cheie de funcție. Cheile necunoscute (venite de
/// la un backend mai nou decât aplicația) se afișează ca atare, ca ecranul să
/// nu crape - vezi [kFeatureFlagKeys].
String featureFlagLabel(AppLocalizations l10n, String key) {
  switch (key) {
    case 'advanced_statistics':
      return l10n.featureFlagAdvancedStatistics;
    default:
      return key;
  }
}

/// Panou de admin pentru acces preferențial/beta: caută un utilizator, bifează
/// funcțiile la care are voie, apasă „Aplică". Vezi UserFeatureFlag din
/// backend pentru mecanismul din spate.
class FeatureAccessScreen extends ConsumerStatefulWidget {
  const FeatureAccessScreen({super.key});

  @override
  ConsumerState<FeatureAccessScreen> createState() => _FeatureAccessScreenState();
}

class _FeatureAccessScreenState extends ConsumerState<FeatureAccessScreen> {
  final _searchController = TextEditingController();
  Timer? _debounce;

  List<AdminUser> _results = const [];
  bool _searching = false;
  bool _searched = false;

  AdminUser? _selectedUser;
  bool _loadingFlags = false;
  bool _saving = false;
  // Starea checkbox-urilor, cheie -> bifat; pornește din ce zice serverul.
  Map<String, bool> _flags = const {};

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
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
      final users = await ref.read(adminRepositoryProvider).searchUsers(trimmed);
      if (!mounted) return;
      setState(() {
        _results = users;
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

  Future<void> _selectUser(AdminUser user) async {
    setState(() {
      _selectedUser = user;
      _loadingFlags = true;
      _flags = const {};
    });
    try {
      final data = await ref.read(adminRepositoryProvider).getUserFeatureFlags(user.id);
      if (!mounted) return;
      setState(() {
        _flags = {for (final f in data.flags) f.key: f.enabled};
      });
    } catch (_) {
      if (!mounted) return;
      // Fără date de la server pornim de la „nimic bifat", nu de la un ecran gol.
      setState(() {
        _flags = {for (final key in kFeatureFlagKeys) key: false};
      });
    } finally {
      if (mounted) setState(() => _loadingFlags = false);
    }
  }

  Future<void> _apply() async {
    final user = _selectedUser;
    if (user == null) return;

    setState(() => _saving = true);
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    try {
      final saved = await ref.read(adminRepositoryProvider).setUserFeatureFlags(
            user.id,
            [
              for (final entry in _flags.entries)
                FeatureFlagValue(key: entry.key, enabled: entry.value),
            ],
          );
      if (!mounted) return;
      setState(() {
        _flags = {for (final f in saved.flags) f.key: f.enabled};
      });
      messenger.showSnackBar(SnackBar(content: Text(l10n.adminFeatureAccessSaved)));
    } catch (_) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.adminFeatureAccessSaveError)));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final user = _selectedUser;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.adminFeatureAccessTitle)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              l10n.adminFeatureAccessDesc,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: AppColors.mutedForeground),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _searchController,
              onChanged: _onQueryChanged,
              decoration: InputDecoration(
                hintText: l10n.adminFeatureAccessSearchHint,
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
              Text(l10n.adminFeatureAccessNoResults)
            else
              for (final result in _results)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  selected: result.id == user?.id,
                  title: Text(result.name ?? result.email, overflow: TextOverflow.ellipsis),
                  subtitle: Text(result.email, overflow: TextOverflow.ellipsis),
                  trailing: result.id == user?.id ? const Icon(Icons.check) : null,
                  onTap: () => _selectUser(result),
                ),
            const SizedBox(height: 20),
            if (user == null)
              Text(
                l10n.adminFeatureAccessSearchEmpty,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: AppColors.mutedForeground),
              )
            else if (_loadingFlags)
              const CenteredScrollable(child: CircularProgressIndicator())
            else ...[
              Text(
                user.name ?? user.email,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              for (final key in kFeatureFlagKeys)
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _flags[key] ?? false,
                  title: Text(featureFlagLabel(l10n, key)),
                  onChanged: _saving
                      ? null
                      : (value) => setState(() {
                            _flags = {..._flags, key: value ?? false};
                          }),
                ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: _saving ? null : _apply,
                child: _saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(l10n.adminFeatureAccessApply),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
