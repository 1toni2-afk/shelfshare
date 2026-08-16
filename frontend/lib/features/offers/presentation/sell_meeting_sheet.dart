import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/locale/l10n_extensions.dart';
import '../../../data/models/price_offer.dart';
import '../../chat/data/places_repository.dart';
import '../../exchanges/presentation/meeting_sheet.dart' show formatMeetingDateTime;
import '../application/offers_controller.dart';

/// Analog cu exchanges/presentation/meeting_sheet.dart, pentru vânzări cu
/// bani (PriceOffer) - aceeași logică de programare, doar apelează
/// offersControllerProvider în loc de exchangesControllerProvider.
class SellMeetingSheet extends ConsumerStatefulWidget {
  const SellMeetingSheet({super.key, required this.offer});
  final PriceOffer offer;

  @override
  ConsumerState<SellMeetingSheet> createState() => _SellMeetingSheetState();
}

class _SellMeetingSheetState extends ConsumerState<SellMeetingSheet> {
  late DateTime? _dateTime = widget.offer.meetingTime?.toLocal();
  late final _locationController = TextEditingController(text: widget.offer.meetingLocation);
  bool _isSubmitting = false;

  Timer? _locationDebounce;
  List<PlaceResult>? _locationSuggestions;
  bool _searchingLocation = false;

  @override
  void dispose() {
    _locationDebounce?.cancel();
    _locationController.dispose();
    super.dispose();
  }

  void _onLocationChanged(String value) {
    _locationDebounce?.cancel();
    final query = value.trim();
    if (query.length < 3) {
      setState(() {
        _locationSuggestions = null;
        _searchingLocation = false;
      });
      return;
    }
    setState(() => _searchingLocation = true);
    _locationDebounce = Timer(const Duration(milliseconds: 400), () async {
      try {
        final results = await ref.read(placesRepositoryProvider).search(query);
        if (mounted) {
          setState(() {
            _locationSuggestions = results;
            _searchingLocation = false;
          });
        }
      } catch (_) {
        if (mounted) {
          setState(() {
            _locationSuggestions = const [];
            _searchingLocation = false;
          });
        }
      }
    });
  }

  void _selectSuggestion(PlaceResult place) {
    _locationController.text = place.displayName;
    _locationController.selection = TextSelection.fromPosition(
      TextPosition(offset: _locationController.text.length),
    );
    setState(() => _locationSuggestions = null);
  }

  Future<void> _pickDateTime() async {
    final now = DateTime.now();
    final initial = _dateTime ?? now.add(const Duration(days: 1));
    final date = await showDatePicker(
      context: context,
      initialDate: initial.isBefore(now) ? now : initial,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (time == null) return;
    setState(() {
      _dateTime = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  Future<void> _submit() async {
    final dateTime = _dateTime;
    final location = _locationController.text.trim();
    if (dateTime == null || location.isEmpty) return;

    setState(() => _isSubmitting = true);
    try {
      await ref.read(offersControllerProvider.notifier).proposeMeeting(
            widget.offer.id,
            meetingTime: dateTime,
            meetingLocation: location,
          );
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(context.l10n.exchangeMeetingSaveError)));
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l10n.exchangeMeetingSheetTitle, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 20),
          OutlinedButton.icon(
            onPressed: _pickDateTime,
            icon: const Icon(Icons.calendar_today),
            label: Text(_dateTime == null ? l10n.exchangePickDateTime : formatMeetingDateTime(_dateTime!)),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _locationController,
            maxLength: 200,
            onChanged: _onLocationChanged,
            decoration: InputDecoration(
              labelText: l10n.exchangeLocationLabel,
              suffixIcon: _searchingLocation
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(
                        height: 16,
                        width: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : const Icon(Icons.search),
            ),
          ),
          if (_locationSuggestions != null && _locationSuggestions!.isNotEmpty) ...[
            const SizedBox(height: 4),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 220),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _locationSuggestions!.length,
                itemBuilder: (context, index) {
                  final place = _locationSuggestions![index];
                  return ListTile(
                    dense: true,
                    leading: const Icon(Icons.place_outlined),
                    title: Text(
                      place.displayName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    onTap: () => _selectSuggestion(place),
                  );
                },
              ),
            ),
          ],
          const SizedBox(height: 8),
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
    );
  }
}

Future<void> showSellMeetingSheet(BuildContext context, PriceOffer offer) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (context) => SellMeetingSheet(offer: offer),
  );
}
