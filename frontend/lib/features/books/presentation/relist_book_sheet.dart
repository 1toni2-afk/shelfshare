import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../../data/models/book.dart';
import '../data/books_repository.dart';

/// Deschide fluxul de re-listare a unei cărți primite printr-un schimb
/// finalizat sau o ofertă acceptată - păstrează aceeași carte din catalog,
/// dar e un anunț nou (stare + poze proprii), legat de cel original prin
/// previousListingId, ca istoricul să rămână urmăribil.
Future<void> showRelistBookSheet(
  BuildContext context, {
  required String originalUserBookId,
  required String bookTitle,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (context) => _RelistBookSheet(
      originalUserBookId: originalUserBookId,
      bookTitle: bookTitle,
    ),
  );
}

class _RelistBookSheet extends ConsumerStatefulWidget {
  const _RelistBookSheet({required this.originalUserBookId, required this.bookTitle});
  final String originalUserBookId;
  final String bookTitle;

  @override
  ConsumerState<_RelistBookSheet> createState() => _RelistBookSheetState();
}

class _RelistBookSheetState extends ConsumerState<_RelistBookSheet> {
  final _priceController = TextEditingController();
  BookCondition _condition = BookCondition.buna;
  bool _isForSale = false;
  bool _isNegotiable = true;
  bool _isSubmitting = false;
  final List<XFile> _photos = [];

  static const _maxPhotos = 2;

  @override
  void dispose() {
    _priceController.dispose();
    super.dispose();
  }

  Future<void> _pickPhotos() async {
    final remaining = _maxPhotos - _photos.length;
    if (remaining <= 0) return;
    final picked = await ImagePicker().pickMultiImage(limit: remaining);
    if (picked.isEmpty) return;
    setState(() => _photos.addAll(picked.take(remaining)));
  }

  Future<void> _submit() async {
    final salePrice = double.tryParse(_priceController.text.trim().replaceAll(',', '.'));
    if (_isForSale && salePrice == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Introdu un preț valid')));
      return;
    }
    if (_isForSale && _photos.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Adaugă cel puțin o poză înainte de a o pune la vânzare')),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final userBook = await ref.read(booksRepositoryProvider).relistBook(
            widget.originalUserBookId,
            condition: _condition,
            isForSale: _isForSale,
            salePrice: _isForSale ? salePrice : null,
            isNegotiable: _isNegotiable,
          );
      for (final photo in _photos) {
        await ref.read(booksRepositoryProvider).addPhoto(
              userBook.id,
              bytes: await photo.readAsBytes(),
              filename: photo.name,
            );
      }
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Cartea a fost adăugată în biblioteca ta')));
      }
    } on DioException catch (e) {
      final data = e.response?.data;
      final message = data is Map && data['message'] != null
          ? (data['message'] is List ? (data['message'] as List).join(', ') : data['message'].toString())
          : 'Nu am putut adăuga cartea.';
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Adaugă „${widget.bookTitle}" în biblioteca ta', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              'Descrie starea în care ai primit-o - rămâne legată de istoricul cărții.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 20),
            DropdownButtonFormField<BookCondition>(
              initialValue: _condition,
              decoration: const InputDecoration(labelText: 'Stare'),
              items: [
                for (final condition in BookCondition.values)
                  DropdownMenuItem(value: condition, child: Text(condition.label)),
              ],
              onChanged: (value) {
                if (value != null) setState(() => _condition = value);
              },
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('De vânzare'),
              value: _isForSale,
              onChanged: (value) => setState(() => _isForSale = value),
            ),
            if (_isForSale) ...[
              TextField(
                controller: _priceController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Preț (lei)', suffixText: 'lei'),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('NENEGOCIABIL'),
                value: !_isNegotiable,
                onChanged: (value) => setState(() => _isNegotiable = !value),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (var i = 0; i < _photos.length; i++)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(_photos[i].path, width: 70, height: 70, fit: BoxFit.cover),
                    ),
                  if (_photos.length < _maxPhotos)
                    OutlinedButton(
                      onPressed: _pickPhotos,
                      style: OutlinedButton.styleFrom(minimumSize: const Size(70, 70), padding: EdgeInsets.zero),
                      child: const Icon(Icons.add_a_photo_outlined),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _isSubmitting ? null : _submit,
              child: _isSubmitting
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Adaugă în bibliotecă'),
            ),
          ],
        ),
      ),
    );
  }
}
