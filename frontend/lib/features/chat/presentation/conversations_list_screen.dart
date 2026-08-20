import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/locale/l10n_extensions.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/support_pages.dart';
import '../../../data/models/conversation.dart';
import '../../../shared/widgets/centered_scrollable.dart';
import '../../../l10n/app_localizations.dart';
import '../../profile/application/profile_controller.dart';
import '../application/conversations_controller.dart';
import 'conversation_screen.dart';

/// Prag desktop pentru layout-ul chat: sub 900 px cădem înapoi la o singură
/// coloană (list → navigare la /chat/:id, cum era înainte). Peste, arătăm
/// lista în stânga și fereastra activă în dreapta, ca în mockup.
const _kChatDesktopBreakpoint = 900.0;

/// Lățimea coloanei cu lista de conversații pe desktop. Egală cu ce e folosit
/// în mockup - suficient pentru avatar + nume + preview mesaj, cu spațiu de
/// respirație.
const _kConversationsColumnWidth = 360.0;

enum _ConversationsFilter { all, unread, archived }

class ConversationsListScreen extends ConsumerStatefulWidget {
  const ConversationsListScreen({super.key, this.archived = false});

  /// Kept for backward-compatibility cu vechea rută /chat/archived, dar
  /// filtrele sunt acum inline (chip-uri). Când ruta primește archived=true,
  /// pornim cu tabul „Arhivate" selectat.
  final bool archived;

  @override
  ConsumerState<ConversationsListScreen> createState() =>
      _ConversationsListScreenState();
}

class _ConversationsListScreenState
    extends ConsumerState<ConversationsListScreen> {
  late _ConversationsFilter _filter =
      widget.archived ? _ConversationsFilter.archived : _ConversationsFilter.all;
  final _searchController = TextEditingController();
  String _searchQuery = '';

  /// Conversația deschisă în panoul din dreapta pe desktop. Pe mobil rămâne
  /// null; tap-ul navighează direct la /chat/:id.
  String? _selectedConversationId;
  Conversation? _selectedConversation;

  // Modul de editare în masă (Milestone 18): ridicat aici (nu mai trăiește în
  // _ConversationsPane) ca să poată fi controlat și din AppBar-ul mobil, nu
  // doar din antetul intern al panoului - vezi de ce mai jos, la AppBar.
  bool _selectionMode = false;
  final Set<String> _selected = {};

  void _exitSelection() {
    setState(() {
      _selectionMode = false;
      _selected.clear();
    });
  }

  void _toggleSelected(String id) {
    setState(() {
      if (!_selected.remove(id)) _selected.add(id);
    });
  }

  void _enterSelectionWith(String id) {
    setState(() {
      _selectionMode = true;
      _selected.add(id);
    });
  }

  Future<void> _bulkArchive(bool archived) async {
    if (_selected.isEmpty) return;
    final notifier =
        ref.read(conversationsControllerProvider(archived).notifier);
    for (final id in _selected.toList()) {
      await notifier.setArchived(id, !archived);
    }
    _exitSelection();
  }

  Future<void> _bulkDelete(bool archived) async {
    if (_selected.isEmpty) return;
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.chatDeleteTitle),
        content: Text(l10n.chatDeleteConfirm),
        actions: [
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.white),
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.commonCancel),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.white),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.commonDelete),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final notifier =
        ref.read(conversationsControllerProvider(archived).notifier);
    for (final id in _selected.toList()) {
      await notifier.delete(id);
    }
    _exitSelection();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop =
        MediaQuery.of(context).size.width >= _kChatDesktopBreakpoint;
    final l10n = context.l10n;
    final archived = _filter == _ConversationsFilter.archived;

    final list = _ConversationsPane(
      showTitle: isDesktop,
      filter: _filter,
      onFilterChange: (f) => setState(() => _filter = f),
      searchController: _searchController,
      searchQuery: _searchQuery,
      onSearchChange: (q) => setState(() => _searchQuery = q),
      selectedConversationId: _selectedConversationId,
      onConversationTap: (c) {
        if (isDesktop) {
          setState(() {
            _selectedConversationId = c.id;
            _selectedConversation = c;
          });
        } else {
          context.push('/chat/${c.id}', extra: c.otherUser);
        }
      },
      selectionMode: _selectionMode,
      selected: _selected,
      onToggleSelected: _toggleSelected,
      onEnterSelectionWith: _enterSelectionWith,
      onEnterSelection: () => setState(() => _selectionMode = true),
      onExitSelection: _exitSelection,
      onBulkArchive: () => _bulkArchive(archived),
      onBulkDelete: () => _bulkDelete(archived),
    );

    if (!isDesktop) {
      // Layout mobil: doar lista, ca înainte. AppBar-ul cu titlu vine din
      // shell-ul principal (hamburger + Chat). Butoanele de editare/conversație
      // nouă stăteau înainte într-un rând separat sub acest AppBar, aproape gol
      // (doar ele două, restul rândului irosit pe un Spacer) - mutate acum
      // direct în AppBar, la același nivel cu titlul, ca să nu mai consume un
      // rând întreg de spațiu vertical doar pentru 2 iconițe.
      return Scaffold(
        appBar: AppBar(
          centerTitle: !_selectionMode,
          leading: _selectionMode
              ? IconButton(icon: const Icon(Icons.close), onPressed: _exitSelection)
              : null,
          title: _selectionMode
              ? Text(
                  '${_selected.length}',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                )
              : Text(l10n.navChat),
          actions: _selectionMode
              ? [
                  IconButton(
                    icon: Icon(archived
                        ? Icons.unarchive_outlined
                        : Icons.archive_outlined),
                    tooltip: archived ? l10n.chatUnarchive : l10n.chatArchive,
                    onPressed:
                        _selected.isEmpty ? null : () => _bulkArchive(archived),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline,
                        color: AppColors.destructive),
                    tooltip: l10n.chatDeleteTitle,
                    onPressed:
                        _selected.isEmpty ? null : () => _bulkDelete(archived),
                  ),
                ]
              : [
                  IconButton(
                    icon: const Icon(Icons.checklist_rounded),
                    tooltip: l10n.commonEdit,
                    onPressed: () => setState(() => _selectionMode = true),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add_comment_outlined),
                    tooltip: l10n.chatNewConversationTooltip,
                    onPressed: () => context.push('/search'),
                  ),
                ],
        ),
        body: list,
      );
    }

    // Layout desktop: lista + panoul cu chatul activ / safety page.
    return Row(
      children: [
        SizedBox(width: _kConversationsColumnWidth, child: list),
        const VerticalDivider(width: 1, thickness: 1),
        Expanded(
          child: _selectedConversationId == null
              ? const _ChatSafetyPage()
              : ConversationScreen(
                  // Key forțează un remount când selecția se schimbă -
                  // ConversationScreen menține scroll position, undelete etc.
                  // în state intern, deci trebuie recreat curat.
                  key: ValueKey(_selectedConversationId),
                  conversationId: _selectedConversationId!,
                  otherUser: _selectedConversation?.otherUser,
                ),
        ),
      ],
    );
  }
}

/// Coloana din stânga (sau întreg ecranul pe mobil): search bar + filtre +
/// lista de conversații.
class _ConversationsPane extends ConsumerWidget {
  const _ConversationsPane({
    required this.showTitle,
    required this.filter,
    required this.onFilterChange,
    required this.searchController,
    required this.searchQuery,
    required this.onSearchChange,
    required this.selectedConversationId,
    required this.onConversationTap,
    required this.selectionMode,
    required this.selected,
    required this.onToggleSelected,
    required this.onEnterSelectionWith,
    required this.onEnterSelection,
    required this.onExitSelection,
    required this.onBulkArchive,
    required this.onBulkDelete,
  });

  /// Titlul „Chat" al panoului e necesar doar pe desktop, unde nu există alt
  /// AppBar. Pe mobil, ecranul are deja un AppBar cu același titlu centrat -
  /// afișarea amândurora dubla „Chat" sus-centru + sus-stânga.
  final bool showTitle;
  final _ConversationsFilter filter;
  final ValueChanged<_ConversationsFilter> onFilterChange;
  final TextEditingController searchController;
  final String searchQuery;
  final ValueChanged<String> onSearchChange;
  final String? selectedConversationId;
  final ValueChanged<Conversation> onConversationTap;

  // Modul de editare în masă (Milestone 18): starea trăiește acum în ecranul
  // părinte (_ConversationsListScreenState), nu aici - pe mobil, antetul cu
  // acțiunile bulk trebuie să apară în AppBar-ul de sus, nu într-un rând
  // separat sub el, deci starea trebuia să fie vizibilă și acolo.
  final bool selectionMode;
  final Set<String> selected;
  final ValueChanged<String> onToggleSelected;
  final ValueChanged<String> onEnterSelectionWith;
  final VoidCallback onEnterSelection;
  final VoidCallback onExitSelection;
  final VoidCallback onBulkArchive;
  final VoidCallback onBulkDelete;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final archived = filter == _ConversationsFilter.archived;
    final state = ref.watch(conversationsControllerProvider(archived));
    final l10n = context.l10n;

    // Contor pentru chipul „Necitite" - se aplică peste conversațiile ne-
    // arhivate. Pe „Arhivate" filtrul devine irelevant.
    final unreadCount =
        (ref.watch(conversationsControllerProvider(false)).value ?? const [])
            .where((c) => c.unreadCount > 0)
            .length;

    return Container(
      color: AppColors.background,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Doar pe desktop: pe mobil, același antet (titlu + acțiuni normale
          // sau bulk) trăiește acum în AppBar-ul ecranului părinte, ca să nu
          // mai irosească un rând întreg de spațiu vertical doar pentru 2
          // iconițe (vezi ConversationsListScreen.build).
          if (showTitle)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: selectionMode
                  ? Row(
                      children: [
                        IconButton(
                          icon: Icon(Icons.close, color: AppColors.foreground),
                          onPressed: onExitSelection,
                        ),
                        Expanded(
                          child: Text(
                            '${selected.length}',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                        ),
                        IconButton(
                          icon: Icon(
                              archived
                                  ? Icons.unarchive_outlined
                                  : Icons.archive_outlined,
                              color: AppColors.foreground),
                          tooltip:
                              archived ? l10n.chatUnarchive : l10n.chatArchive,
                          onPressed: selected.isEmpty ? null : onBulkArchive,
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline,
                              color: AppColors.destructive),
                          tooltip: l10n.chatDeleteTitle,
                          onPressed: selected.isEmpty ? null : onBulkDelete,
                        ),
                      ],
                    )
                  : Row(
                      children: [
                        Expanded(
                          child: Text(
                            l10n.navChat,
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                        ),
                        // Editare în masă: selectează conversații ca să le
                        // arhivezi/ștergi împreună. Înlocuiește vechiul creion
                        // (care doar deschidea o conversație nouă - mutat lângă).
                        IconButton(
                          icon: Icon(Icons.checklist_rounded, color: AppColors.foreground),
                          tooltip: l10n.commonEdit,
                          onPressed: onEnterSelection,
                        ),
                        IconButton(
                          icon: Icon(Icons.add_comment_outlined, color: AppColors.foreground),
                          tooltip: l10n.chatNewConversationTooltip,
                          onPressed: () => context.push('/search'),
                        ),
                      ],
                    ),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: searchController,
              onChanged: onSearchChange,
              decoration: InputDecoration(
                hintText: l10n.chatSearchHint,
                prefixIcon: const Icon(Icons.search, size: 20),
                isDense: true,
                suffixIcon: searchQuery.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          searchController.clear();
                          onSearchChange('');
                        },
                      ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                _FilterChip(
                  label: l10n.chatFilterAll,
                  selected: filter == _ConversationsFilter.all,
                  onTap: () => onFilterChange(_ConversationsFilter.all),
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: l10n.chatFilterUnread,
                  badge: unreadCount > 0 ? unreadCount : null,
                  selected: filter == _ConversationsFilter.unread,
                  onTap: () =>
                      onFilterChange(_ConversationsFilter.unread),
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: l10n.chatFilterArchived,
                  selected: filter == _ConversationsFilter.archived,
                  onTap: () =>
                      onFilterChange(_ConversationsFilter.archived),
                ),
                const SizedBox(width: 8),
                // Nu e un filtru ca celelalte 3 (nu filtrează lista de mai jos) -
                // deschide direct chatul cu echipa de admini (userul obișnuit)
                // sau inbox-ul de suport (adminii) - vezi backend/src/admin-chat.
                _FilterChip(
                  label: l10n.chatFilterModerator,
                  selected: false,
                  icon: Icons.shield_outlined,
                  onTap: () {
                    final isAdmin =
                        ref.read(profileControllerProvider).value?.isAdmin ?? false;
                    context.push(isAdmin ? '/admin/chat' : '/support/chat');
                  },
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => ref
                  .read(conversationsControllerProvider(archived).notifier)
                  .refresh(),
              child: state.when(
                data: (all) {
                  final filtered = _applyFilter(all);
                  if (filtered.isEmpty) {
                    return CenteredScrollable(
                      child: Text(
                        _emptyLabel(l10n),
                        style: TextStyle(color: AppColors.mutedForeground),
                      ),
                    );
                  }
                  return ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    itemCount: filtered.length,
                    separatorBuilder: (_, _) =>
                        const Divider(height: 1, indent: 76),
                    itemBuilder: (context, index) {
                      final conv = filtered[index];
                      return _ConversationTile(
                        conversation: conv,
                        archived: archived,
                        isSelected: conv.id == selectedConversationId,
                        selectionMode: selectionMode,
                        isChecked: selected.contains(conv.id),
                        onTap: () {
                          if (selectionMode) {
                            onToggleSelected(conv.id);
                          } else {
                            onConversationTap(conv);
                          }
                        },
                        onLongPress: () {
                          // Long-press intră direct în modul de selecție cu
                          // conversația respectivă bifată - scurtătură uzuală.
                          onEnterSelectionWith(conv.id);
                        },
                      );
                    },
                  );
                },
                loading: () => const CenteredScrollable(
                    child: CircularProgressIndicator()),
                error: (error, _) => CenteredScrollable(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(l10n.chatLoadError),
                      const SizedBox(height: 8),
                      OutlinedButton(
                        onPressed: () => ref
                            .read(conversationsControllerProvider(archived)
                                .notifier)
                            .refresh(),
                        child: Text(l10n.commonRetry),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Conversation> _applyFilter(List<Conversation> all) {
    Iterable<Conversation> result = all;
    if (filter == _ConversationsFilter.unread) {
      result = result.where((c) => c.unreadCount > 0);
    }
    if (searchQuery.trim().isNotEmpty) {
      final q = searchQuery.toLowerCase().trim();
      result = result.where((c) {
        final name = c.otherUser.name?.toLowerCase() ?? '';
        final last = c.lastMessage?.content?.toLowerCase() ?? '';
        return name.contains(q) || last.contains(q);
      });
    }
    return result.toList();
  }

  String _emptyLabel(AppLocalizations l10n) {
    if (searchQuery.trim().isNotEmpty) return l10n.chatEmptySearch;
    switch (filter) {
      case _ConversationsFilter.archived:
        return l10n.chatEmptyArchived;
      case _ConversationsFilter.unread:
        return l10n.chatEmptyUnread;
      case _ConversationsFilter.all:
        return l10n.chatEmptyConversations;
    }
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.badge,
    this.icon,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final int? badge;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? AppColors.accent.withValues(alpha: 0.15) : null,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 15, color: selected ? AppColors.accent : AppColors.foreground),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: TextStyle(
                color: selected ? AppColors.accent : AppColors.foreground,
                fontSize: 13,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
            if (badge != null) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: AppColors.accent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$badge',
                  style: const TextStyle(
                    color: AppColors.accentForeground,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ConversationTile extends ConsumerWidget {
  const _ConversationTile({
    required this.conversation,
    required this.archived,
    required this.isSelected,
    required this.onTap,
    this.selectionMode = false,
    this.isChecked = false,
    this.onLongPress,
  });

  final Conversation conversation;
  final bool archived;
  final bool isSelected;
  final VoidCallback onTap;

  /// Modul de editare în masă: tile-ul arată bifă în loc de avatar-status și
  /// tap-ul (de)selectează în loc să deschidă conversația.
  final bool selectionMode;
  final bool isChecked;
  final VoidCallback? onLongPress;

  Future<bool> _confirmDelete(BuildContext context) async {
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.chatDeleteTitle),
        content: Text(l10n.chatDeleteConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.commonCancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.commonDelete),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final lastMessage = conversation.lastMessage;
    final preview = lastMessage == null
        ? l10n.chatStartConversation
        : lastMessage.content ??
            (lastMessage.photo != null
                ? l10n.chatPhotoPreview
                : l10n.chatLocationPreview);
    final hasUnread = conversation.unreadCount > 0;
    final notifier = ref.read(conversationsControllerProvider(archived).notifier);

    final avatar = Stack(
      clipBehavior: Clip.none,
      children: [
        CircleAvatar(
          backgroundImage: conversation.otherUser.profileImage != null
              ? NetworkImage(conversation.otherUser.profileImage!)
              : null,
          child: conversation.otherUser.profileImage == null
              ? const Icon(Icons.person)
              : null,
        ),
        if (conversation.otherUser.isOnline)
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: AppColors.success,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.background, width: 2),
              ),
            ),
          ),
      ],
    );

    final tile = ListTile(
      selected: isSelected,
      leading: selectionMode
          ? Checkbox(value: isChecked, onChanged: (_) => onTap())
          : avatar,
      title: Text(
        conversation.otherUser.name ?? l10n.commonUnknownUser,
        style: hasUnread ? const TextStyle(fontWeight: FontWeight.bold) : null,
      ),
      subtitle: Text(
        preview,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: hasUnread
            ? TextStyle(
                fontWeight: FontWeight.w600,
                color: Theme.of(context).textTheme.bodyMedium?.color,
              )
            : null,
      ),
      // IMPORTANT: fără `alignment` pe acest Container. Ca `trailing` de ListTile
      // primește constrângeri largi (loose), iar un Container cu `alignment` se
      // umflă să umple toată lățimea disponibilă - badge-ul devenea un cerc uriaș
      // care fura tot spațiul, iar numele se rupea pe verticală, literă cu literă.
      // Fără alignment, Container-ul se strânge pe conținut. Pilulă (borderRadius)
      // în loc de cerc, ca „99+" să nu iasă din formă.
      // Arhivate: buton explicit de dezarhivare - swipe-ul de mai jos există,
      // dar userii nu-l descopereau ("acum e complicat procesul"). Un buton
      // vizibil e cea mai directă cale.
      trailing: selectionMode
          ? null
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (hasUnread)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.accent,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      conversation.unreadCount > 99
                          ? '99+'
                          : '${conversation.unreadCount}',
                      style: const TextStyle(
                        color: AppColors.accentForeground,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                if (archived)
                  IconButton(
                    icon: const Icon(Icons.unarchive_outlined),
                    tooltip: l10n.chatUnarchive,
                    onPressed: () => notifier.setArchived(conversation.id, false),
                  ),
              ],
            ),
      onTap: onTap,
      onLongPress: onLongPress,
    );

    return Container(
      color: (isSelected || isChecked)
          ? AppColors.accent.withValues(alpha: 0.08)
          : null,
      // În modul de selecție dezactivăm swipe-ul (arhivă/ștergere pe gest):
      // gestul de bifare intră în conflict, iar acțiunile există deja în antet.
      child: selectionMode
          ? tile
          : Dismissible(
              key: ValueKey(conversation.id),
              background: _SwipeBackground(
                alignment: Alignment.centerLeft,
                color: AppColors.accent,
                icon: archived
                    ? Icons.unarchive_outlined
                    : Icons.archive_outlined,
                label: archived ? l10n.chatUnarchive : l10n.chatArchive,
              ),
              secondaryBackground: const _SwipeBackground(
                alignment: Alignment.centerRight,
                color: AppColors.destructive,
                icon: Icons.delete_outline,
                label: null,
              ),
              confirmDismiss: (direction) async {
                if (direction == DismissDirection.startToEnd) {
                  await notifier.setArchived(conversation.id, !archived);
                  return false;
                }
                if (!await _confirmDelete(context)) return false;
                await notifier.delete(conversation.id);
                return false;
              },
              child: tile,
            ),
    );
  }
}

class _SwipeBackground extends StatelessWidget {
  const _SwipeBackground({
    required this.alignment,
    required this.color,
    required this.icon,
    required this.label,
  });

  final Alignment alignment;
  final Color color;
  final IconData icon;
  final String? label;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: color.withValues(alpha: 0.15),
      alignment: alignment,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color),
          if (label != null) ...[
            const SizedBox(width: 8),
            Text(label!, style: TextStyle(color: color, fontWeight: FontWeight.w600)),
          ],
        ],
      ),
    );
  }
}

/// Ecranul din panoul dreapta când nu e nicio conversație selectată. E o
/// „welcome page" cu reguli de siguranță - Milestone 16 QOL zice: „când
/// userul intră în Mesaje, să nu se deschidă automat ultimul chat, ci să-i
/// arate pagina de safety".
class _ChatSafetyPage extends StatelessWidget {
  const _ChatSafetyPage();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.accent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.chat_bubble_outline,
                        color: AppColors.accent, size: 28),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      l10n.chatSafetyHeadline,
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                l10n.chatSafetyIntro,
                style: TextStyle(
                    color: AppColors.mutedForeground,
                    fontSize: 14,
                    height: 1.5),
              ),
              const SizedBox(height: 24),
              _SafetyItem(
                icon: Icons.privacy_tip_outlined,
                title: l10n.chatSafetyPersonalTitle,
                body: l10n.chatSafetyPersonalBody,
              ),
              _SafetyItem(
                icon: Icons.credit_card_off_outlined,
                title: l10n.chatSafetyPaymentTitle,
                body: l10n.chatSafetyPaymentBody,
              ),
              _SafetyItem(
                icon: Icons.location_on_outlined,
                title: l10n.chatSafetyMeetupTitle,
                body: l10n.chatSafetyMeetupBody,
              ),
              _SafetyItem(
                icon: Icons.flag_outlined,
                title: l10n.chatSafetyReportTitle,
                body: l10n.chatSafetyReportBody,
              ),
              const SizedBox(height: 20),
              OutlinedButton.icon(
                icon: const Icon(Icons.shield_outlined),
                label: Text(l10n.chatSafetyOpenCenter),
                onPressed: () => openSupportPage(context, '/safety-center'),
              ),
              const SizedBox(height: 12),
              Center(
                child: Text(
                  l10n.chatSafetyHint,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: AppColors.mutedForeground,
                      fontSize: 12,
                      fontStyle: FontStyle.italic),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SafetyItem extends StatelessWidget {
  const _SafetyItem({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.accent, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                      color: AppColors.foreground,
                      fontSize: 14,
                      fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(
                  body,
                  style: TextStyle(
                      color: AppColors.mutedForeground,
                      fontSize: 13,
                      height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
