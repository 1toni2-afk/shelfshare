import 'package:flutter/material.dart';

/// Un rând orizontal scrolabil care nu se rupe pe mai multe linii pe ecrane
/// înguste. Marginile primesc un fade care apare doar în partea în care mai
/// există conținut de derulat, ca semnal vizual că bara continuă.
class FadingScrollRow extends StatefulWidget {
  const FadingScrollRow({
    super.key,
    required this.children,
    this.spacing = 8,
    this.padding = EdgeInsets.zero,
    this.fadeWidth = 24,
  });

  final List<Widget> children;
  final double spacing;
  final EdgeInsets padding;
  final double fadeWidth;

  @override
  State<FadingScrollRow> createState() => _FadingScrollRowState();
}

class _FadingScrollRowState extends State<FadingScrollRow> {
  final _controller = ScrollController();
  double _leading = 0;
  double _trailing = 0;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_updateFades);
    WidgetsBinding.instance.addPostFrameCallback((_) => _updateFades());
  }

  @override
  void didUpdateWidget(covariant FadingScrollRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    WidgetsBinding.instance.addPostFrameCallback((_) => _updateFades());
  }

  @override
  void dispose() {
    _controller.removeListener(_updateFades);
    _controller.dispose();
    super.dispose();
  }

  void _updateFades() {
    if (!mounted || !_controller.hasClients) return;
    final position = _controller.position;
    // Fade-ul crește progresiv pe primii câțiva pixeli de scroll, ca să nu
    // apară brusc la prima atingere.
    final leading = (position.pixels / widget.fadeWidth).clamp(0.0, 1.0);
    final remaining = position.maxScrollExtent - position.pixels;
    final trailing = (remaining / widget.fadeWidth).clamp(0.0, 1.0);
    if (leading != _leading || trailing != _trailing) {
      setState(() {
        _leading = leading;
        _trailing = trailing;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[];
    for (var i = 0; i < widget.children.length; i++) {
      if (i > 0) children.add(SizedBox(width: widget.spacing));
      children.add(widget.children[i]);
    }

    final row = SingleChildScrollView(
      controller: _controller,
      scrollDirection: Axis.horizontal,
      padding: widget.padding,
      physics: const ClampingScrollPhysics(),
      child: Row(mainAxisSize: MainAxisSize.min, children: children),
    );

    if (_leading == 0 && _trailing == 0) return row;

    final fade = widget.fadeWidth;
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        // Lățimile fade-ului exprimate ca fracțiuni din lățimea totală, ca să
        // putem folosi un singur gradient orizontal ca mască alpha.
        final stop = width > 0 ? (fade / width).clamp(0.0, 0.5) : 0.0;
        return ShaderMask(
          blendMode: BlendMode.dstIn,
          shaderCallback: (rect) => LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [
              Colors.white.withValues(alpha: 1 - _leading),
              Colors.white,
              Colors.white,
              Colors.white.withValues(alpha: 1 - _trailing),
            ],
            stops: [0, stop, 1 - stop, 1],
          ).createShader(rect),
          child: row,
        );
      },
    );
  }
}
