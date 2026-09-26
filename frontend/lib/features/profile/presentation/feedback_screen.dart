import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/locale/l10n_extensions.dart';
import '../../../core/theme/app_theme.dart';
import '../data/feedback_repository.dart';

/// Formularul de feedback ca PAGINĂ, nu ca dialog (dialogul din Setări rămâne
/// unde e). Există ca destinație pentru un link din afara aplicației - emailul
/// de bun venit trimis la 3 zile după înregistrare duce aici, iar un link nu
/// poate deschide un dialog dintr-un alt ecran.
class FeedbackScreen extends ConsumerStatefulWidget {
  const FeedbackScreen({super.key});

  @override
  ConsumerState<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends ConsumerState<FeedbackScreen> {
  final _controller = TextEditingController();
  XFile? _photo;
  Uint8List? _photoBytes;
  bool _sending = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1600,
      maxHeight: 1600,
      imageQuality: 85,
    );
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    if (!mounted) return;
    setState(() {
      _photo = picked;
      _photoBytes = bytes;
    });
  }

  Future<void> _submit() async {
    final l10n = context.l10n;
    final message = _controller.text.trim();
    // Aceeași limită ca pe backend (FeedbackController): sub 3 caractere
    // cererea ar fi respinsă oricum, deci nici nu o trimitem.
    if (message.length < 3 || _sending) return;

    setState(() => _sending = true);
    try {
      await ref.read(feedbackRepositoryProvider).submit(
            message,
            photoBytes: _photoBytes,
            photoFilename: _photo?.name,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l10n.profileFeedbackThanks)));
      setState(() {
        _controller.clear();
        _photo = null;
        _photoBytes = null;
        _sending = false;
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l10n.profileFeedbackError)));
      setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final photoBytes = _photoBytes;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.profileSendFeedback)),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(
                l10n.feedbackPageIntro,
                style: TextStyle(
                    color: AppColors.mutedForeground, fontSize: 14, height: 1.5),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _controller,
                autofocus: true,
                minLines: 5,
                maxLines: 10,
                maxLength: 2000,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: l10n.profileFeedbackHint,
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 12),
              if (photoBytes != null)
                Stack(
                  alignment: Alignment.topRight,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.memory(photoBytes,
                          height: 160, fit: BoxFit.cover),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      tooltip: l10n.profileFeedbackRemovePhoto,
                      onPressed: () => setState(() {
                        _photo = null;
                        _photoBytes = null;
                      }),
                    ),
                  ],
                )
              else
                Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.image_outlined, size: 18),
                    label: Text(l10n.profileFeedbackAddPhoto),
                    onPressed: _pickPhoto,
                  ),
                ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _controller.text.trim().length < 3 || _sending
                    ? null
                    : _submit,
                child: _sending
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(l10n.commonSubmit),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
