import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

/// Cod QR care rămâne vizibil și scanabil pe orice temă.
///
/// `QrImageView` desenează implicit module negre pe fundal transparent, deci pe
/// tema întunecată ieșea negru pe negru - invizibil. Nu inversăm culorile
/// (module albe pe negru): multe scannere presupun modul închis pe fundal
/// deschis și refuză codurile inversate. În schimb, punem mereu un fond alb
/// sub cod, cu o margine liniștită („quiet zone") în jur, care e chiar
/// recomandarea din standardul QR.
class ScannableQr extends StatelessWidget {
  const ScannableQr({super.key, required this.data, this.size = 200});

  final String data;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: QrImageView(
        data: data,
        size: size,
        backgroundColor: Colors.white,
        // Explicit negru, nu culoarea din temă - altfel pe tema întunecată
        // modulele s-ar redesena deschise și am ajunge la aceeași problemă.
        eyeStyle: const QrEyeStyle(
          eyeShape: QrEyeShape.square,
          color: Colors.black,
        ),
        dataModuleStyle: const QrDataModuleStyle(
          dataModuleShape: QrDataModuleShape.square,
          color: Colors.black,
        ),
      ),
    );
  }
}
