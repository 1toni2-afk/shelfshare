import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/locale/l10n_extensions.dart';
import '../../../data/models/book.dart';
import '../data/auctions_repository.dart';
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
  final _reservePriceController = TextEditingController();
  final _buyNowPriceController = TextEditingController();
  BookCondition _condition = BookCondition.buna;
  bool _isForSale = false;
  bool _isNegotiable = true;
  bool _isAuction = false;
  int _auctionDurationHours = 24;
  bool _isSubmitting = false;
  final List<XFile> _photos = [];

  static const _maxPhotos = 2;

  @override
  void dispose() {
    _priceController.dispose();
    _reservePriceController.dispose();
    _buyNowPriceController.dispose();
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
    final l10n = context.l10n;
    final salePrice = double.tryParse(_priceController.text.trim().replaceAll(',', '.'));
    if ((_isForSale || _isAuction) && salePrice == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l10n.addBookInvalidPrice)));
      return;
    }
    if ((_isForSale || _isAuction) && _photos.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.relistNeedPhoto)),
      );
      return;
    }
    final reservePrice = _reservePriceController.text.trim().isEmpty
        ? null
        : double.tryParse(_reservePriceController.text.trim().replaceAll(',', '.'));
    final buyNowPrice = _buyNowPriceController.text.trim().isEmpty
        ? null
        : double.tryParse(_buyNowPriceController.text.trim().replaceAll(',', '.'));

    setState(() => _isSubmitting = true);
    try {
      final userBook = await ref.read(booksRepositoryProvider).relistBook(
            widget.originalUserBookId,
            condition: _condition,
          );
      for (final photo in _photos) {
        await ref.read(booksRepositoryProvider).addPhoto(
              userBook.id,
              bytes: await photo.readAsBytes(),
              filename: photo.name,
            );
      }
      if (_isForSale) {
        await ref.read(booksRepositoryProvider).markForSale(
              userBook.id,
              salePrice: salePrice!,
              isNegotiable: _isNegotiable,
            );
      } else if (_isAuction) {
        await ref.read(auctionsRepositoryProvider).createAuction(
              userBook.id,
              startingPrice: salePrice!,
              reservePrice: reservePrice,
              buyNowPrice: buyNowPrice,
              durationHours: _auctionDurationHours,
            );
      }
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(l10n.relistSuccess)));
      }
    } on DioException catch (e) {
      if (mounted) {
        final data = e.response?.data;
        final message = data is Map && data['message'] != null
            ? (data['message'] is List ? (data['message'] as List).join(', ') : data['message'].toString())
            : l10n.relistGenericError;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
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
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.relistHeading(widget.bookTitle), style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              l10n.relistSubtitle,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 20),
            DropdownButtonFormField<BookCondition>(
              initialValue: _condition,
              decoration: InputDecoration(labelText: l10n.filtersCondition),
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
              title: Text(l10n.addBookForSaleSwitch),
              value: _isForSale,
              onChanged: (value) => setState(() {
                _isForSale = value;
                if (value) _isAuction = false;
              }),
            ),
            if (_isForSale) ...[
              TextField(
                controller: _priceController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(labelText: l10n.addBookPriceLabel, suffixText: 'lei'),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(l10n.addBookNonNegotiable),
                value: !_isNegotiable,
                onChanged: (value) => setState(() => _isNegotiable = !value),
              ),
            ],
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.addBookAuctionSwitch),
              value: _isAuction,
              onChanged: (value) => setState(() {
                _isAuction = value;
                if (value) _isForSale = false;
              }),
            ),
            if (_isAuction) ...[
              TextField(
                controller: _priceController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(labelText: l10n.addBookAuctionStartingPrice, suffixText: 'lei'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _reservePriceController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: l10n.addBookAuctionReservePrice,
                  helperText: l10n.addBookAuctionReservePriceHint,
                  suffixText: 'lei',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _buyNowPriceController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: l10n.addBookAuctionBuyNowPrice,
                  helperText: l10n.addBookAuctionBuyNowPriceHint,
                  suffixText: 'lei',
                ),
              ),
              const SizedBox(height: 12),
              Text(l10n.addBookAuctionDuration, style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  ChoiceChip(
                    label: Text(l10n.addBookAuctionDuration24h),
                    selected: _auctionDurationHours == 24,
                    onSelected: (_) => setState(() => _auctionDurationHours = 24),
                  ),
                  ChoiceChip(
                    label: Text(l10n.addBookAuctionDuration3d),
                    selected: _auctionDurationHours == 72,
                    onSelected: (_) => setState(() => _auctionDurationHours = 72),
                  ),
                  ChoiceChip(
                    label: Text(l10n.addBookAuctionDuration7d),
                    selected: _auctionDurationHours == 168,
                    onSelected: (_) => setState(() => _auctionDurationHours = 168),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 8),
            Text(
              (_isForSale || _isAuction) ? l10n.addBookPhotosLabelRequired : l10n.addBookPhotosLabelOptional,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
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
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _isSubmitting ? null : _submit,
              child: _isSubmitting
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(l10n.addBookSubmit),
            ),
          ],
        ),
      ),
    );
  }
}
