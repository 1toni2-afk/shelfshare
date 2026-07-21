import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/widgets/centered_scrollable.dart';
import '../data/exchanges_repository.dart';

/// Ecran deschis prin scanarea codului QR afișat de celălalt participant -
/// confirmă finalizarea schimbului (reutilizează același endpoint ca
/// butonul "Marchează finalizat" din listă).
class ExchangeConfirmScreen extends ConsumerStatefulWidget {
  const ExchangeConfirmScreen({super.key, required this.exchangeId});
  final String exchangeId;

  @override
  ConsumerState<ExchangeConfirmScreen> createState() => _ExchangeConfirmScreenState();
}

class _ExchangeConfirmScreenState extends ConsumerState<ExchangeConfirmScreen> {
  bool _isSubmitting = false;
  bool _done = false;
  String? _error;

  Future<void> _confirm() async {
    setState(() {
      _isSubmitting = true;
      _error = null;
    });
    try {
      await ref.read(exchangesRepositoryProvider).complete(widget.exchangeId);
      if (mounted) setState(() => _done = true);
    } on DioException catch (e) {
      final data = e.response?.data;
      final message = data is Map && data['message'] != null
          ? (data['message'] is List ? (data['message'] as List).join(', ') : data['message'].toString())
          : 'Nu am putut confirma schimbul.';
      if (mounted) setState(() => _error = message);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Confirmă schimbul')),
      body: SafeArea(
        child: CenteredScrollable(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_done) ...[
                const Icon(Icons.check_circle, size: 48, color: Color(0xFF2E7D32)),
                const SizedBox(height: 12),
                const Text('Schimb marcat ca finalizat!'),
              ] else ...[
                const Text('Confirmi că schimbul de cărți s-a finalizat?'),
                if (_error != null) ...[
                  const SizedBox(height: 8),
                  Text(_error!, style: const TextStyle(color: Colors.red)),
                ],
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _isSubmitting ? null : _confirm,
                  child: _isSubmitting
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Confirmă finalizarea'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
