import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/locale/l10n_extensions.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/admin_models.dart';
import '../data/admin_repository.dart';

/// Alegerea unui utilizator prin căutare, pentru acțiunile de admin care au
/// nevoie de `user.id`.
///
/// Există fiindcă `id` e un UUID: nicăieri în aplicație nu e afișat, deci un
/// câmp în care trebuie tastat nu se poate completa decât copiindu-l din altă
/// parte. Aici se caută după nume, `@username` sau email - toate trei sunt
/// deja acoperite de `/admin/users/search` - iar `id`-ul se ia din rândul ales.
///
/// `@username` apare sub nume și nu e cosmetic: numele nu e unic (doi „Andrei
/// Popescu") și poate lipsi cu totul, deci fără handle rândurile nu se pot
/// deosebi între ele.
class AdminUserPicker extends ConsumerStatefulWidget {
  const AdminUserPicker({
    super.key,
    required this.selected,
    required this.onSelected,
    this.autofocus = false,
  });

  final AdminUser? selected;
  final ValueChanged<AdminUser?> onSelected;
  final bool autofocus;

  @override
  ConsumerState<AdminUserPicker> createState() => _AdminUserPickerState();
}

class _AdminUserPickerState extends ConsumerState<AdminUserPicker> {
  final _controller = TextEditingController();
  Timer? _debounce;

  List<AdminUser> _results = const [];
  bool _searching = false;
  bool _searched = false;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onQueryChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () => _search(value));
  }

  Future<void> _search(String query) async {
    final trimmed = query.trim();
    // Sub 2 caractere serverul întoarce oricum listă goală (vezi
    // AdminService.searchUsers) - nu mai facem cererea.
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

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final selected = widget.selected;

    if (selected != null) {
      return Card(
        margin: EdgeInsets.zero,
        child: ListTile(
          leading: const Icon(Icons.person),
          title: Text(selected.name ?? selected.email, overflow: TextOverflow.ellipsis),
          subtitle: Text(_handleAndEmail(selected), overflow: TextOverflow.ellipsis),
          trailing: IconButton(
            tooltip: l10n.adminUserPickerChange,
            icon: const Icon(Icons.close),
            onPressed: () {
              _controller.clear();
              setState(() {
                _results = const [];
                _searched = false;
              });
              widget.onSelected(null);
            },
          ),
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          textAlignVertical: TextAlignVertical.center,
          controller: _controller,
          autofocus: widget.autofocus,
          onChanged: _onQueryChanged,
          decoration: InputDecoration(
            hintText: l10n.adminUserPickerSearchHint,
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
        const SizedBox(height: 8),
        if (_searched && _results.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              l10n.adminUserPickerNoResults,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: AppColors.mutedForeground),
            ),
          )
        else if (!_searched)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              l10n.adminUserPickerEmpty,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: AppColors.mutedForeground),
            ),
          )
        else
          // Într-un dialog înălțimea nu e mărginită de nimic, iar căutarea
          // întoarce până la 50 de rânduri - fără limita asta lista ar împinge
          // butoanele de Anulează/Adaugă în afara ecranului.
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 260),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _results.length,
              itemBuilder: (context, index) {
                final result = _results[index];
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(result.name ?? result.email, overflow: TextOverflow.ellipsis),
                  subtitle: Text(_handleAndEmail(result), overflow: TextOverflow.ellipsis),
                  onTap: () => widget.onSelected(result),
                );
              },
            ),
          ),
      ],
    );
  }

  /// „@handle · email" când userul are username, altfel doar emailul: un „@"
  /// singur pe rând ar arăta ca un handle gol, nu ca un câmp lipsă.
  String _handleAndEmail(AdminUser user) {
    final username = user.username;
    if (username == null || username.isEmpty) return user.email;
    return '@$username · ${user.email}';
  }
}
