@Tags(['demo'])
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shelfshare/core/theme/app_theme.dart';
import 'package:shelfshare/data/models/book.dart';
import 'package:shelfshare/data/models/user.dart';
import 'package:shelfshare/data/models/user_book.dart';
import 'package:shelfshare/l10n/app_localizations.dart';
import 'package:shelfshare/shared/widgets/deal_summary_card.dart';

/// Nu e un test de regresie, e un GENERATOR DE CAPTURI: randează cardul cu
/// motorul real Flutter, cu fonturile aplicației și la lățime de telefon, ca
/// să se poată vedea cum arată fără să treci prin login, chat și o ofertă
/// acceptată.
///
/// Rulează-l explicit când vrei imaginile:
///   flutter test test/deal_summary_card_demo_test.dart --update-goldens
///
/// E marcat cu `@Tags(['demo'])` și exclus din `flutter test` normal prin
/// dart_test.yaml - altfel ar scrie fișiere PNG la fiecare rulare a suitei.
void main() {
  setUpAll(() async {
    // Fără fonturile reale, motorul de test desenează dreptunghiuri în loc de
    // litere și de iconițe, iar captura devine inutilizabilă. Trei fonturi:
    // cele două ale aplicației, plus MaterialIcons din SDK (săgeata de schimb,
    // bancnota, silueta din avatar) - pe care Flutter nu-l încarcă singur în
    // teste.
    Future<void> load(String family, String path) async {
      final loader = FontLoader(family)
        ..addFont(
          File(path).readAsBytes().then((bytes) => ByteData.sublistView(bytes)),
        );
      await loader.load();
    }

    await load('DM Sans', 'assets/fonts/DMSans-Variable.ttf');
    await load('Playfair Display', 'assets/fonts/PlayfairDisplay-Variable.ttf');

    // `flutter test` rulează dart-ul din SDK
    // (<flutter>/bin/cache/dart-sdk/bin/dart), iar fontul de iconițe stă în
    // <flutter>/bin/cache/artifacts/material_fonts. Urcăm din executabil până
    // dăm de folderul „cache", în loc să numărăm nivele - structura SDK-ului
    // s-a mai schimbat între versiuni.
    Directory? dir = File(Platform.resolvedExecutable).parent;
    while (dir != null && !dir.path.endsWith('cache')) {
      final parent = dir.parent;
      dir = parent.path == dir.path ? null : parent;
    }
    final icons = dir == null
        ? null
        : File('${dir.path}/artifacts/material_fonts/MaterialIcons-Regular.otf');
    if (icons == null || !icons.existsSync()) {
      fail('Nu am gasit MaterialIcons in SDK - captura ar iesi cu patrate '
          'in loc de iconite. Cautat pornind de la ${Platform.resolvedExecutable}');
    }
    await load('MaterialIcons', icons.path);
  });

  final littlePrince = Book(
    id: 'b1',
    title: 'The Little Prince',
    author: 'Antoine de Saint-Exupery',
  );
  final dune = Book(id: 'b2', title: 'Dune', author: 'Frank Herbert');

  UserBook userBook(Book book) => UserBook(
        id: 'ub-${book.id}',
        userId: 'u1',
        book: book,
        condition: BookCondition.buna,
        createdAt: DateTime(2026, 9, 1),
      );

  const other = PublicUser(
    id: 'u2',
    name: 'Andrada Petrar',
    city: 'Cluj-Napoca',
  );

  Future<void> shoot(
    WidgetTester tester,
    String name,
    DealPayload give,
    DealPayload receive,
  ) async {
    // 393 logical lățime: un telefon obișnuit. Înălțimea e generoasă
    // DINADINS - rama demo-ului nu are voie să strângă cardul și să raporteze
    // un overflow care în aplicație nu există (acolo cardul stă într-un
    // ListView, deci poate fi oricât de înalt).
    tester.view.physicalSize = const Size(393 * 3, 380 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.dark,
        locale: const Locale('en'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: Scaffold(
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: DealSummaryCard(
                give: give,
                receive: receive,
                other: other,
              ),
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

  testWidgets('vanzator - da cartea, primeste 20 lei', (tester) async {
    await shoot(
      tester,
      'vanzator',
      DealPayload(books: [userBook(littlePrince)]),
      const DealPayload(amount: 20),
    );
  });

  testWidgets('cumparator - da 20 lei, primeste cartea', (tester) async {
    await shoot(
      tester,
      'cumparator',
      const DealPayload(amount: 20),
      DealPayload(books: [userBook(littlePrince)]),
    );
  });

  testWidgets('schimb carte pe carte, cu diferenta in bani', (tester) async {
    await shoot(
      tester,
      'schimb',
      DealPayload(books: [userBook(dune)], extraBooks: 2, amount: 15),
      DealPayload(books: [userBook(littlePrince)]),
    );
  });
}
