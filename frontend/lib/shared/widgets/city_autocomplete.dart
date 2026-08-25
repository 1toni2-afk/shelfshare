import 'package:flutter/material.dart';
import '../../core/constants/romanian_cities.dart';

/// Câmp de oraș cu sugestii pe măsură ce scrii.
///
/// Înlocuiește dropdown-ul: cu 41 de reședințe de județ o listă derulantă era
/// încă utilizabilă, cu toate cele 316 orașe nu mai e. Potrivirea ignoră
/// diacriticele și majusculele, deci „timisoara" găsește „Timișoara", iar
/// prefixele sunt afișate înaintea potrivirilor din interiorul numelui
/// („Aiud" apare primul la „ai", nu după „Băile Tușnad").
class CityAutocomplete extends StatefulWidget {
  const CityAutocomplete({
    super.key,
    required this.value,
    required this.onChanged,
    required this.label,
    this.allowEmpty = true,
    this.emptyLabel,
  });

  final String? value;
  final ValueChanged<String?> onChanged;
  final String label;

  /// Dacă `true`, ștergerea completă a textului trimite `null` (fără oraș).
  final bool allowEmpty;
  final String? emptyLabel;

  @override
  State<CityAutocomplete> createState() => _CityAutocompleteState();
}

class _CityAutocompleteState extends State<CityAutocomplete> {
  @override
  Widget build(BuildContext context) {
    return Autocomplete<String>(
      initialValue: TextEditingValue(text: widget.value ?? ''),
      optionsBuilder: (textEditingValue) {
        final query = normalizeForSearch(textEditingValue.text);
        if (query.isEmpty) return kRomanianCities.take(20);
        final prefix = <String>[];
        final contains = <String>[];
        for (final city in kRomanianCities) {
          final normalized = normalizeForSearch(city);
          if (normalized.startsWith(query)) {
            prefix.add(city);
          } else if (normalized.contains(query)) {
            contains.add(city);
          }
        }
        return [...prefix, ...contains].take(30);
      },
      onSelected: widget.onChanged,
      fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
        return TextFormField(
          textAlignVertical: TextAlignVertical.center,
          controller: controller,
          focusNode: focusNode,
          decoration: InputDecoration(
            labelText: widget.label,
            prefixIcon: const Icon(Icons.location_city_outlined),
            suffixIcon: controller.text.isEmpty
                ? null
                : IconButton(
                    icon: const Icon(Icons.clear, size: 18),
                    onPressed: () {
                      controller.clear();
                      widget.onChanged(null);
                    },
                  ),
          ),
          // Textul liber care nu e un oraș din listă nu se salvează: backend-ul
          // validează cu @IsIn, deci ar fi respins oricum. Golirea câmpului
          // înseamnă „fără oraș".
          onChanged: (text) {
            if (text.trim().isEmpty && widget.allowEmpty) {
              widget.onChanged(null);
              return;
            }
            final exact = kRomanianCities.firstWhere(
              (city) => normalizeForSearch(city) == normalizeForSearch(text),
              orElse: () => '',
            );
            if (exact.isNotEmpty) widget.onChanged(exact);
          },
          validator: (text) {
            if (text == null || text.trim().isEmpty) {
              return widget.allowEmpty ? null : widget.emptyLabel;
            }
            final known = kRomanianCities.any(
              (city) => normalizeForSearch(city) == normalizeForSearch(text),
            );
            return known ? null : widget.emptyLabel;
          },
        );
      },
      optionsViewBuilder: (context, onSelected, options) {
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(12),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 260, maxWidth: 420),
              child: ListView.builder(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: options.length,
                itemBuilder: (context, index) {
                  final city = options.elementAt(index);
                  return ListTile(
                    dense: true,
                    title: Text(city),
                    onTap: () => onSelected(city),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Minuscule fără diacritice românești, pentru comparații de căutare.
String normalizeForSearch(String input) {
  const map = {
    'ă': 'a',
    'â': 'a',
    'î': 'i',
    'ș': 's',
    'ş': 's',
    'ț': 't',
    'ţ': 't',
  };
  final lower = input.toLowerCase().trim();
  final buffer = StringBuffer();
  for (final char in lower.split('')) {
    buffer.write(map[char] ?? char);
  }
  return buffer.toString();
}

