import 'dart:async';
import 'package:flutter/material.dart';

class TypewriterPhrase {
  const TypewriterPhrase(this.text, this.hold);
  final String text;
  final Duration hold;
}

/// Text „la mașină de scris": tastează fiecare frază caracter cu caracter, o
/// ține afișată `hold`, apoi o șterge și trece la următoarea, în buclă. Cursor
/// „_" care clipește. Folosit pentru salutul din bara de sus a paginii
/// principale.
class TypewriterText extends StatefulWidget {
  const TypewriterText({
    super.key,
    required this.phrases,
    this.style,
    this.typingSpeed = const Duration(milliseconds: 70),
    this.deletingSpeed = const Duration(milliseconds: 35),
  });

  final List<TypewriterPhrase> phrases;
  final TextStyle? style;
  final Duration typingSpeed;
  final Duration deletingSpeed;

  @override
  State<TypewriterText> createState() => _TypewriterTextState();
}

class _TypewriterTextState extends State<TypewriterText> {
  int _phraseIndex = 0;
  int _charCount = 0;
  bool _cursorOn = true;
  bool _running = false;
  Timer? _cursorTimer;

  @override
  void initState() {
    super.initState();
    _cursorTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      if (mounted) setState(() => _cursorOn = !_cursorOn);
    });
    _running = true;
    _run();
  }

  @override
  void dispose() {
    _running = false;
    _cursorTimer?.cancel();
    super.dispose();
  }

  Future<bool> _wait(Duration d) async {
    await Future<void>.delayed(d);
    return _running && mounted;
  }

  Future<void> _run() async {
    if (widget.phrases.isEmpty) return;
    while (_running && mounted) {
      final phrase = widget.phrases[_phraseIndex];

      // Tastare
      for (var i = 1; i <= phrase.text.length; i++) {
        if (!await _wait(widget.typingSpeed)) return;
        setState(() => _charCount = i);
      }

      // Ține fraza completă afișată
      if (!await _wait(phrase.hold)) return;

      // Ștergere
      for (var i = phrase.text.length - 1; i >= 0; i--) {
        if (!await _wait(widget.deletingSpeed)) return;
        setState(() => _charCount = i);
      }

      _phraseIndex = (_phraseIndex + 1) % widget.phrases.length;
    }
  }

  @override
  Widget build(BuildContext context) {
    final phrase = widget.phrases.isEmpty
        ? const TypewriterPhrase('', Duration.zero)
        : widget.phrases[_phraseIndex];
    final visible = phrase.text.substring(0, _charCount.clamp(0, phrase.text.length));
    return Text(
      '$visible${_cursorOn ? '_' : ' '}',
      style: widget.style,
      maxLines: 1,
      overflow: TextOverflow.clip,
    );
  }
}
