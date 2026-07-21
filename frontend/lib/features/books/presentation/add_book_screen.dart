import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../../data/models/book.dart';
import '../../../data/models/external_book_result.dart';
import '../../../shared/widgets/book_cover.dart';
import '../../../shared/widgets/centered_scrollable.dart';
import '../application/my_library_controller.dart';
import '../data/books_repository.dart';

class AddBookScreen extends ConsumerStatefulWidget {
  const AddBookScreen({super.key});

  @override
  ConsumerState<AddBookScreen> createState() => _AddBookScreenState();
}

class _AddBookScreenState extends ConsumerState<AddBookScreen> {
  final _searchController = TextEditingController();
  final _titleController = TextEditingController();
  final _authorController = TextEditingController();
  final _languageController = TextEditingController();
  final _editionController = TextEditingController();
  final _priceController = TextEditingController();

  bool _isSearching = false;
  bool _isSubmitting = false;
  String? _searchError;
  List<ExternalBookResult>? _results;
  ExternalBookResult? _selected;
  bool _manualEntry = false;
  BookCondition _condition = BookCondition.buna;
  bool _isHardcover = false;
  bool _isForSale = false;
  bool _isNegotiable = true;
  Timer? _searchDebounce;
  final List<XFile> _photos = [];

  static const _maxPhotos = 2;

  Future<void> _pickPhotos() async {
    final remaining = _maxPhotos - _photos.length;
    if (remaining <= 0) return;
    final picked = await ImagePicker().pickMultiImage(limit: remaining);
    if (picked.isEmpty) return;
    setState(() => _photos.addAll(picked.take(remaining)));
  }

  void _removePhoto(int index) {
    setState(() => _photos.removeAt(index));
  }

  bool get _showDetailsForm => _selected != null || _manualEntry;

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    _titleController.dispose();
    _authorController.dispose();
    _languageController.dispose();
    _editionController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  /// Căutare live pe măsură ce userul tastează, cu un mic debounce - ca
  /// alegerea unei cărți din sugestii (cu autor completat automat) să nu mai
  /// ceară un pas explicit de "Caută".
  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    if (value.trim().length < 2) {
      setState(() {
        _results = null;
        _searchError = null;
      });
      return;
    }
    _searchDebounce = Timer(const Duration(milliseconds: 400), _search);
  }

  Future<void> _search() async {
    final query = _searchController.text.trim();
    if (query.length < 2) return;
    setState(() {
      _isSearching = true;
      _searchError = null;
    });
    try {
      final results = await ref.read(booksRepositoryProvider).searchExternal(query);
      if (mounted) setState(() => _results = results);
    } catch (_) {
      if (mounted) setState(() => _searchError = 'Căutarea a eșuat. Încearcă din nou.');
    } finally {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  void _selectResult(ExternalBookResult result) {
    setState(() {
      _selected = result;
      _manualEntry = false;
    });
  }

  void _startManualEntry() {
    setState(() {
      _manualEntry = true;
      _selected = null;
    });
  }

  void _backToSearch() {
    setState(() {
      _selected = null;
      _manualEntry = false;
    });
  }

  Future<void> _submit() async {
    final title = _selected?.title ?? _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Titlul este obligatoriu')));
      return;
    }

    final salePrice = double.tryParse(_priceController.text.trim().replaceAll(',', '.'));
    if (_isForSale && salePrice == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Introdu un preț valid')));
      return;
    }
    if (_isForSale && _photos.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Adaugă cel puțin o poză cu cartea înainte de a o pune la vânzare')),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final userBook = await ref.read(booksRepositoryProvider).addToLibrary(
            isbn: _selected?.isbn,
            title: title,
            author: _selected?.author ??
                (_authorController.text.trim().isEmpty ? null : _authorController.text.trim()),
            condition: _condition,
            language: _languageController.text.trim().isEmpty ? null : _languageController.text.trim(),
            edition: _editionController.text.trim().isEmpty ? null : _editionController.text.trim(),
            isHardcover: _isHardcover,
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
      ref.invalidate(myLibraryControllerProvider);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Carte adăugată în bibliotecă')));
        Navigator.of(context).pop();
      }
    } on DioException catch (e) {
      final data = e.response?.data;
      final message = data is Map && data['message'] != null
          ? (data['message'] is List ? (data['message'] as List).join(', ') : data['message'].toString())
          : 'Nu am putut adăuga cartea. Încearcă din nou.';
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Adaugă o carte')),
      body: SafeArea(
        child: _showDetailsForm ? _buildDetailsForm() : _buildSearchStep(),
      ),
    );
  }

  Widget _buildSearchStep() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  onChanged: _onSearchChanged,
                  onSubmitted: (_) => _search(),
                  decoration: const InputDecoration(hintText: 'Titlu sau ISBN'),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _isSearching ? null : _search,
                child: const Text('Caută'),
              ),
            ],
          ),
        ),
        Expanded(child: _buildSearchResults()),
      ],
    );
  }

  Widget _buildSearchResults() {
    if (_isSearching) {
      return const CenteredScrollable(child: CircularProgressIndicator());
    }
    if (_searchError != null) {
      return CenteredScrollable(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_searchError!),
            const SizedBox(height: 8),
            OutlinedButton(onPressed: _search, child: const Text('Încearcă din nou')),
          ],
        ),
      );
    }
    if (_results == null || _results!.isEmpty) {
      return CenteredScrollable(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_results == null ? 'Caută o carte după titlu sau ISBN.' : 'Nicio carte găsită.'),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: _startManualEntry,
              child: const Text('Adaugă manual'),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _results!.length + 1,
      separatorBuilder: (_, _) => const Divider(),
      itemBuilder: (context, index) {
        if (index == _results!.length) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: TextButton(
                onPressed: _startManualEntry,
                child: const Text('Nu găsești cartea? Adaugă manual'),
              ),
            ),
          );
        }
        final result = _results![index];
        final subtitleParts = [
          if (result.author != null) result.author!,
          if (result.publishedYear != null) result.publishedYear.toString(),
        ];
        return ListTile(
          contentPadding: EdgeInsets.zero,
          leading: BookCover(url: result.coverUrl, width: 48, height: 68),
          title: Text(result.title),
          subtitle: subtitleParts.isEmpty ? null : Text(subtitleParts.join(' · ')),
          onTap: () => _selectResult(result),
        );
      },
    );
  }

  Widget _buildDetailsForm() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (_selected != null)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: BookCover(url: _selected!.coverUrl, width: 48, height: 68),
            title: Text(_selected!.title),
            subtitle: _selected!.author != null ? Text(_selected!.author!) : null,
            trailing: TextButton(onPressed: _backToSearch, child: const Text('Schimbă')),
          )
        else ...[
          TextField(
            controller: _titleController,
            decoration: const InputDecoration(labelText: 'Titlu'),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _authorController,
            decoration: const InputDecoration(labelText: 'Autor'),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(onPressed: _backToSearch, child: const Text('Caută în schimb')),
          ),
        ],
        const SizedBox(height: 16),
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
        const SizedBox(height: 16),
        TextField(
          controller: _languageController,
          decoration: const InputDecoration(labelText: 'Limbă (opțional)'),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _editionController,
          decoration: const InputDecoration(labelText: 'Ediție (opțional)'),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Ediție cartonată'),
          value: _isHardcover,
          onChanged: (value) => setState(() => _isHardcover = value),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('De vânzare'),
          subtitle: const Text('Pe lângă schimb, poți vinde cartea la un preț fix'),
          value: _isForSale,
          onChanged: (value) => setState(() => _isForSale = value),
        ),
        if (_isForSale) ...[
          const SizedBox(height: 8),
          TextField(
            controller: _priceController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Preț (lei)', suffixText: 'lei'),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('NENEGOCIABIL'),
            subtitle: const Text('Cumpărătorii nu vor putea face oferte de preț'),
            value: !_isNegotiable,
            onChanged: (value) => setState(() => _isNegotiable = !value),
          ),
          const SizedBox(height: 8),
          Text(
            'Poze cu cartea (obligatoriu, cel puțin 1)',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (var i = 0; i < _photos.length; i++)
                Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(_photos[i].path, width: 90, height: 90, fit: BoxFit.cover),
                    ),
                    Positioned(
                      top: 2,
                      right: 2,
                      child: GestureDetector(
                        onTap: () => _removePhoto(i),
                        child: const CircleAvatar(
                          radius: 10,
                          backgroundColor: Colors.black54,
                          child: Icon(Icons.close, size: 14, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
              if (_photos.length < _maxPhotos)
                OutlinedButton(
                  onPressed: _pickPhotos,
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(90, 90),
                    padding: EdgeInsets.zero,
                  ),
                  child: const Icon(Icons.add_a_photo_outlined),
                ),
            ],
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
              : const Text('Adaugă în bibliotecă'),
        ),
      ],
    );
  }
}
