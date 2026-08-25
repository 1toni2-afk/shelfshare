import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/locale/l10n_extensions.dart';
import '../../../data/models/user.dart';
import '../../../shared/widgets/centered_scrollable.dart';
import '../../../shared/widgets/city_autocomplete.dart';
import '../application/profile_controller.dart';

/// Lungimea maximă a bio-ului („About me"). Ținută sincronizată cu validarea
/// din backend (UpdateProfileDto.bio) - dacă o modifici aici, modifică și acolo.
const kBioMaxLength = 20;

/// Editarea profilului ca rută (`/profile/edit`), nu ca bottom sheet.
///
/// Înainte, Setările și Edit profile erau două `showModalBottomSheet`
/// suprapuse, iar back-ul de sistem pe Android ieșea complet din stivă în loc
/// să întoarcă un pas. Ca rute copil ale branch-ului `/profile`, stiva devine
/// `/profile → /profile/settings → /profile/edit`, deci back întoarce exact
/// unde trebuie.
class EditProfileScreen extends ConsumerWidget {
  const EditProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(profileControllerProvider);
    final user = state.value;
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.profileEditProfile)),
      body: SafeArea(
        child: user == null
            ? const CenteredScrollable(child: CircularProgressIndicator())
            : _EditProfileForm(user: user),
      ),
    );
  }
}

class _EditProfileForm extends ConsumerStatefulWidget {
  const _EditProfileForm({required this.user});
  final AppUser user;

  @override
  ConsumerState<_EditProfileForm> createState() => _EditProfileFormState();
}

class _EditProfileFormState extends ConsumerState<_EditProfileForm> {
  late final _nameController = TextEditingController(text: widget.user.name);
  late final _usernameController = TextEditingController(text: widget.user.username);
  late final _bioController = TextEditingController(text: widget.user.bio);
  late String? _city = widget.user.city;
  late final int? _birthdayDay = widget.user.birthdayDay;
  late final int? _birthdayMonth = widget.user.birthdayMonth;
  late final Set<String> _languages = widget.user.languages.toSet();
  late bool _nameVisible = widget.user.nameVisible;
  late bool _showAcquisitionHistory = widget.user.showAcquisitionHistory;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _nameController.dispose();
    _usernameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  /// Preset-ul de limbi propuse. Dacă userul are deja o limbă în afara listei
  /// (ex. „Latină"), o afișăm și pe aia ca chip - altfel n-ar avea cum s-o
  /// menține odată ce a intrat în editor.
  Iterable<String> _availableLanguages(Set<String> selected) {
    const preset = ['Română', 'English', 'Magyar', 'Deutsch', 'Français', 'Español', 'Italiano'];
    final extras = selected.where((l) => !preset.contains(l));
    return [...preset, ...extras];
  }

  Future<void> _submit() async {
    setState(() => _isSubmitting = true);
    try {
      await ref.read(profileControllerProvider.notifier).updateProfile(
            name: _nameController.text.trim().isEmpty ? null : _nameController.text.trim(),
            username: _usernameController.text.trim().isEmpty
                ? null
                : _usernameController.text.trim(),
            nameVisible: _nameVisible,
            city: _city,
            bio: _bioController.text.trim(),
            birthdayDay: _birthdayDay,
            birthdayMonth: _birthdayMonth,
            languages: _languages.toList(),
            showAcquisitionHistory: _showAcquisitionHistory,
          );
      if (mounted) context.pop();
    } on DioException catch (e) {
      if (mounted) {
        final data = e.response?.data;
        final message = (data is Map && data['message'] != null)
            ? data['message'].toString()
            : context.l10n.profileSaveError;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(context.l10n.profileSaveError)));
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Center(
      child: SingleChildScrollView(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(context).viewInsets.bottom + 32,
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                textAlignVertical: TextAlignVertical.center,
                controller: _nameController,
                decoration: InputDecoration(labelText: l10n.onboardingLastName),
              ),
              const SizedBox(height: 16),
              TextField(
                textAlignVertical: TextAlignVertical.center,
                controller: _usernameController,
                decoration: InputDecoration(
                  labelText: l10n.profileUsernameLabel,
                  prefixIcon: const Icon(Icons.alternate_email),
                ),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(l10n.onboardingNameVisibleSwitch),
                subtitle: Text(l10n.onboardingUsernameAlwaysVisible),
                value: _nameVisible,
                onChanged: (value) => setState(() => _nameVisible = value),
              ),
              const SizedBox(height: 16),
              CityAutocomplete(
                value: _city,
                label: l10n.profileCityLabel,
                emptyLabel: l10n.shareCityUnknown,
                onChanged: (value) => setState(() => _city = value),
              ),
              const SizedBox(height: 16),
              TextField(
                textAlignVertical: TextAlignVertical.center,
                controller: _bioController,
                maxLength: kBioMaxLength,
                decoration: InputDecoration(labelText: l10n.profileAboutMe),
              ),
              const SizedBox(height: 16),
              Text(l10n.profileLanguagesTitle,
                  style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 8),
              // Alege limbile din setul comun (RO/EN/HU/DE/FR/ES/IT) plus,
              // dacă userul are altă limbă deja salvată, o afișăm ca chip
              // suplimentar. Nu adăugăm un câmp text - lista fixă e suficient
              // și evită typo-uri care ar fragmenta datele („română" vs „RO").
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final lang in _availableLanguages(_languages))
                    FilterChip(
                      label: Text(lang),
                      selected: _languages.contains(lang),
                      onSelected: (selected) => setState(() {
                        if (selected) {
                          _languages.add(lang);
                        } else {
                          _languages.remove(lang);
                        }
                      }),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(l10n.profileShowAcquisitionHistory),
                subtitle: Text(l10n.profileShowAcquisitionHistorySubtitle),
                value: _showAcquisitionHistory,
                onChanged: (value) => setState(() => _showAcquisitionHistory = value),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: _isSubmitting ? null : _submit,
                child: _isSubmitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(l10n.commonSave),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
