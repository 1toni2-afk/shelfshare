@Tags(['demo'])
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shelfshare/core/theme/app_theme.dart';

/// Generator de imagini pentru sigla din antetul meniului.
///
/// Compoziția de mai jos e aceeași cu cea din
/// `lib/shared/widgets/main_scaffold.dart` („// Antet cu logo."), unde sigla e
/// scrisă inline în `_Sidebar` - un widget privat, deci nu se poate importa
/// aici. Dacă se schimbă acolo, trebuie schimbată și aici, altfel imaginile
/// generate nu mai seamănă cu aplicația.
///
/// Rulează:
///   flutter test test/app_logo_demo_test.dart --update-goldens --run-skipped
void main() {
  setUpAll(() async {
    Future<void> load(String family, String path) async {
      final loader = FontLoader(family)
        ..addFont(
          File(path).readAsBytes().then((bytes) => ByteData.sublistView(bytes)),
        );
      await loader.load();
    }

    await load('DM Sans', 'assets/fonts/DMSans-Variable.ttf');

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
    await load('MaterialIcons', icons.path);
  });

  /// Sigla, scalabilă. `scale` 1 = exact dimensiunile din aplicație.
  Widget logo(double scale) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: EdgeInsets.all(6 * scale),
          decoration: BoxDecoration(
            color: AppColors.accent.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8 * scale),
          ),
          child: Icon(
            Icons.menu_book_rounded,
            color: AppColors.accent,
            size: 20 * scale,
          ),
        ),
        SizedBox(width: 10 * scale),
        Text(
          'ShelfShare',
          style: TextStyle(
            fontFamily: 'DM Sans',
            fontSize: 16 * scale,
            fontWeight: FontWeight.bold,
            color: AppColors.foreground,
          ),
        ),
      ],
    );
  }

  Future<void> shoot(
    WidgetTester tester,
    String name, {
    required Color background,
    double scale = 8,
    double padding = 24,
  }) async {
    // Rama e generoasă, iar imaginea se decupează după aceea la conținut
    // (vezi scripts-ul de conversie) - altfel ar trebui ghicită aici lățimea
    // exactă a textului, care depinde de font.
    tester.view.physicalSize = const Size(1600, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.dark,
        // `Material`, nu `ColoredBox`: un `Text` fără strămoș Material primește
        // de la Flutter o subliniere galbenă de avertisment, care ajungea în
        // imaginea generată. În aplicație sigla stă într-un Scaffold, deci
        // acolo n-a existat niciodată.
        home: Material(
          color: background,
          child: Center(
            child: Padding(
              padding: EdgeInsets.all(padding),
              child: logo(scale),
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

  testWidgets('logo pe fundalul cardului', (tester) async {
    // AppColors.card în dark - același gri pe care stă sigla în meniu.
    await shoot(tester, 'logo_dark', background: const Color(0xFF19191B));
  });

  testWidgets('logo pe fundal transparent', (tester) async {
    await shoot(tester, 'logo_transparent', background: const Color(0x00000000));
  });
}
