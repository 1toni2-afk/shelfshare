import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../../core/locale/l10n_extensions.dart';

/// Scanează codul de bare de pe coperta a patra și întoarce ISBN-ul, sau
/// `null` dacă userul a renunțat.
///
/// Aceeași bibliotecă folosită de „adaugă mai multe cărți" (bulk_add_screen),
/// dar aici oprim la PRIMUL cod valid: fluxul de adăugare a unei singure
/// cărți continuă imediat cu completarea formularului, deci un al doilea cod
/// citit din aceeași imagine n-ar avea unde să ajungă.
Future<String?> showIsbnScanner(BuildContext context) {
  return Navigator.of(context).push<String>(
    MaterialPageRoute(builder: (_) => const _IsbnScannerScreen(), fullscreenDialog: true),
  );
}

class _IsbnScannerScreen extends StatefulWidget {
  const _IsbnScannerScreen();

  @override
  State<_IsbnScannerScreen> createState() => _IsbnScannerScreenState();
}

class _IsbnScannerScreenState extends State<_IsbnScannerScreen> {
  final _controller = MobileScannerController();
  // Camera livrează zeci de cadre pe secundă: fără asta, același cod ar
  // închide ecranul de mai multe ori (Navigator.pop pe o rută deja scoasă).
  bool _handled = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Codul de bare de pe cărți e EAN-13, adică exact ISBN-ul cu prefix
  /// 978/979. Orice altceva (coduri interne de magazin, QR-uri) e ignorat, ca
  /// să nu pornim o căutare care oricum n-ar întoarce nimic.
  String? _isbnFrom(String raw) {
    final digits = raw.replaceAll(RegExp(r'[^0-9Xx]'), '');
    if (digits.length == 13 && (digits.startsWith('978') || digits.startsWith('979'))) {
      return digits;
    }
    if (digits.length == 10) return digits;
    return null;
  }

  void _onDetect(BarcodeCapture capture) {
    if (_handled) return;
    for (final barcode in capture.barcodes) {
      final raw = barcode.rawValue;
      if (raw == null) continue;
      final isbn = _isbnFrom(raw);
      if (isbn == null) continue;
      _handled = true;
      Navigator.of(context).pop(isbn);
      return;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.bulkAddScanTooltip)),
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(controller: _controller, onDetect: _onDetect),
          // Indiciu discret peste imagine: fără el, ecranul e doar o cameră
          // deschisă și nu e evident ce anume așteaptă de la user.
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: Text(
                    l10n.shareScanHint,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
