@Tags(['demo'])
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Generator pentru iconițele de Android: iconița de launcher și iconița
/// monocromă din bara de notificări.
///
/// Sursa desenului e `Icons.menu_book_rounded` - EXACT glifa din sigla
/// aplicației (vezi antetul din `main_scaffold.dart` și
/// `app_logo_demo_test.dart`). Înainte, `assets/icon/*` erau două PNG-uri
/// desenate de mână, cu o carte care nu semăna cu glifa din aplicație.
///
/// Rulează:
///   flutter test test/app_icon_demo_test.dart --update-goldens --run-skipped
///
/// După rulare, vezi comentariul de la finalul fișierului pentru pașii de
/// copiere + `dart run flutter_launcher_icons`.
void main() {
  /// Aceleași două culori ca înainte: fundalul adaptive din
  /// `android/app/src/main/res/values/colors.xml` și crema din temă.
  const brown = Color(0xFF7C3A1E);
  const cream = Color(0xFFF8F4EC);

  setUpAll(() async {
    // Fără fontul de iconițe încărcat explicit, `Icon` randează un pătrat gol
    // în harness-ul de test - exact capcana din app_logo_demo_test.dart.
    Directory? dir = File(Platform.resolvedExecutable).parent;
    while (dir != null && !dir.path.endsWith('cache')) {
      final parent = dir.parent;
      dir = parent.path == dir.path ? null : parent;
    }
    final icons = dir == null
        ? null
        : File('${dir.path}/artifacts/material_fonts/MaterialIcons-Regular.otf');
    if (icons == null || !icons.existsSync()) {
      fail('Nu am gasit MaterialIcons in SDK - iconita ar iesi patrat.');
    }
    final loader = FontLoader('MaterialIcons')
      ..addFont(
        icons.readAsBytes().then((bytes) => ByteData.sublistView(bytes)),
      );
    await loader.load();
  });

  /// Randează glifa centrată pe o pânză pătrată de `canvas` pixeli fizici.
  /// `glyphRatio` = cât din latura pânzei ocupă glifa.
  Future<void> shoot(
    WidgetTester tester,
    String name, {
    required double canvas,
    required double glyphRatio,
    required Color glyph,
    Color background = const Color(0x00000000),
  }) async {
    tester.view.physicalSize = Size(canvas, canvas);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: ColoredBox(
          color: background,
          child: Center(
            child: Icon(
              Icons.menu_book_rounded,
              color: glyph,
              size: canvas * glyphRatio,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('demo/$name.png'),
    );
  }

  // ---------- Iconița de launcher ----------

  // `adaptive_icon_foreground`: glifa la 66% din pânză = fix zona sigură a
  // unei iconițe adaptive Android (72dp din 108dp). Peste asta se adaugă
  // `adaptive_icon_foreground_inset: 12` din pubspec.yaml, deci desenul final
  // stă la ~52% - vezi comentariul de acolo.
  testWidgets('adaptive foreground', (tester) async {
    await shoot(tester, 'app_icon_foreground',
        canvas: 1024, glyphRatio: 0.66, glyph: cream);
  });

  // `image_path`: iconița pătrată (legacy, pre-Android 8 și Play Store). N-are
  // mască adaptivă peste ea, deci glifa poate sta mai mare - dar tot cu o ramă
  // de respirație, fiindcă launcherele o rotunjesc.
  testWidgets('iconita patrata', (tester) async {
    await shoot(tester, 'app_icon_square',
        canvas: 1024, glyphRatio: 0.56, glyph: cream, background: brown);
  });

  // ---------- Iconița din bara de notificări ----------

  // Android ia DOAR canalul alfa al acestei iconițe și o desenează în alb pe
  // fundal transparent. `@mipmap/ic_launcher` avea fundalul opac, deci în bara
  // de stare ieșea un pătrat alb plin - de-aia îi trebuie o siluetă proprie.
  //
  // Densitățile sunt cele standard pentru un asset de 24dp:
  // mdpi 24, hdpi 36, xhdpi 48, xxhdpi 72, xxxhdpi 96.
  for (final (density, size) in const [
    ('mdpi', 24.0),
    ('hdpi', 36.0),
    ('xhdpi', 48.0),
    ('xxhdpi', 72.0),
    ('xxxhdpi', 96.0),
  ]) {
    testWidgets('iconita de notificare $density', (tester) async {
      await shoot(tester, 'ic_stat_shelfshare_$density',
          canvas: size, glyphRatio: 0.85, glyph: Colors.white);
    });
  }
}

// Pașii de după generare (nu-i automatizăm: scriu în `android/` și în
// `assets/`, deci vrem să fie o comandă explicită, nu un efect secundar al
// unui `flutter test`):
//
//   cp test/demo/app_icon_foreground.png assets/icon/icon-foreground.png
//   cp test/demo/app_icon_square.png     assets/icon/icon-square.png
//   for d in mdpi hdpi xhdpi xxhdpi xxxhdpi; do \
//     cp test/demo/ic_stat_shelfshare_$d.png \
//        android/app/src/main/res/drawable-$d/ic_stat_shelfshare.png; done
//   dart run flutter_launcher_icons
