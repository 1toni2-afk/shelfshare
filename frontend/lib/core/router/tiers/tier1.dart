/// Nivelul 1 - ecranele preîncărcate în fundal, imediat după primul frame.
///
/// Un singur „barrel" per nivel, importat amânat o singură dată din
/// `app_router.dart`. Motivul e practic, nu estetic: cu un `deferred as` per
/// ecran, dart2js sparge codul în fragmente pentru fiecare combinație de
/// importuri amânate care ajung la el - măsurat, 269 de fișiere `.part.js`,
/// din care 124 se descărcau doar pentru preîncărcarea acestui nivel. Grupate
/// pe niveluri, fiecare nivel e un fragment (plus cele partajate), adică
/// aceleași bytes în câteva cereri, nu în peste o sută.
library;

export '../../../features/home/presentation/home_screen.dart';
export '../../../features/books/presentation/discover_screen.dart';
export '../../../features/books/presentation/book_detail_screen.dart';
