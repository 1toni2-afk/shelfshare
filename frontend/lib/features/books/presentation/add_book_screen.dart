import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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

  bool _isSearching = false;
  bool _isSubmitting = false;
  String? _searchError;
  List<ExternalBookResult>? _results;
  ExternalBookResult? _selected;
  bool _manualEntry = false;
  BookCondition _condition = BookCondition.buna;
  bool _isHardcover = false;

  bool get _showDetailsForm => _selected != null || _manualEntry;

  @override
  void dispose() {
    _searchController.dispose();
    _titleController.dispose();
    _authorController.dispose();
    _languageController.dispose();
    _editionController.dispose();
    super.dispose();
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

    setState(() => _isSubmitting = true);
    try {
      await ref.read(booksRepositoryProvider).addToLibrary(
            isbn: _selected?.isbn,
            title: title,
            author: _selected?.author ??
                (_authorController.text.trim().isEmpty ? null : _authorController.text.trim()),
            condition: _condition,
            language: _languageController.text.trim().isEmpty ? null : _languageController.text.trim(),
            edition: _editionController.text.trim().isEmpty ? null : _editionController.text.trim(),
            isHardcover: _isHardcover,
          );
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
