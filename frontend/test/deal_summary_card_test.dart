import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shelfshare/data/models/book.dart';
import 'package:shelfshare/data/models/user.dart';
import 'package:shelfshare/data/models/user_book.dart';
import 'package:shelfshare/l10n/app_localizations.dart';
import 'package:shelfshare/shared/widgets/deal_summary_card.dart';

/// Cardul din capul paginii de finalizare spunea, citit literal, că dai o
/// carte și 20 de lei ca să primești un OM: suma stătea pe partea de „You
/// give", iar la „You receive" era avatarul celuilalt user. Pe deasupra arăta
/// identic pentru ambele părți, deși cumpărătorul dă banii, nu cartea.
///
/// Testele de aici fixează exact asta: fiecare rol vede pe partea lui ce
/// îi revine, iar celălalt om nu mai apare ca marfă.
void main() {
  final book = Book(id: 'b1', title: 'The Little Prince', author: 'Antoine de Saint-Exupery');
  final otherBook = Book(id: 'b2', title: 'Dune', author: 'Frank Herbert');

  UserBook userBook(Book value, String owner) => UserBook(
        id: 'ub-${value.id}',
        userId: owner,
        book: value,
        condition: BookCondition.buna,
        createdAt: DateTime(2026, 9, 1),
      );

  const seller = PublicUser(id: 'u1', name: 'Andrada Petrar', city: 'Cluj-Napoca');
  const buyer = PublicUser(id: 'u2', name: 'Andrei Popescu', city: 'București');

  Future<void> pump(WidgetTester tester, Widget child) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: Scaffold(body: Center(child: SizedBox(width: 420, child: child))),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Textul afișat sub o etichetă, până la eticheta următoare - ca să putem
  /// spune „pe partea de You give scrie X", nu doar „X apare undeva în card".
  List<String> textsBetween(WidgetTester tester, String from, String to) {
    final all = tester
        .widgetList<Text>(find.byType(Text))
        .map((t) => t.data ?? '')
        .toList();
    final start = all.indexOf(from);
    final end = all.indexOf(to);
    if (start < 0) return const [];
    return all.sublist(start + 1, end > start ? end : all.length);
  }

  testWidgets('vânzătorul dă cartea și primește banii', (tester) async {
    await pump(
      tester,
      DealSummaryCard(
        give: DealPayload(books: [userBook(book, 'u1')]),
        receive: const DealPayload(amount: 20),
        other: buyer,
      ),
    );

    expect(textsBetween(tester, 'You give', 'You receive'), contains('The Little Prince'));
    expect(textsBetween(tester, 'You receive', 'Andrei Popescu'), contains('20 lei'));
  });

  testWidgets('cumpărătorul dă banii și primește cartea', (tester) async {
    await pump(
      tester,
      DealSummaryCard(
        give: const DealPayload(amount: 20),
        receive: DealPayload(books: [userBook(book, 'u1')]),
        other: seller,
      ),
    );

    expect(textsBetween(tester, 'You give', 'You receive'), contains('20 lei'));
    expect(textsBetween(tester, 'You receive', 'Andrada Petrar'), contains('The Little Prince'));
  });

  testWidgets('celălalt user apare o singură dată, sub târg, nu ca marfă',
      (tester) async {
    await pump(
      tester,
      DealSummaryCard(
        give: DealPayload(books: [userBook(book, 'u1')]),
        receive: const DealPayload(amount: 20),
        other: buyer,
      ),
    );

    // Numele NU are voie să stea între cele două etichete: acolo e doar ce
    // se schimbă.
    expect(
      textsBetween(tester, 'You give', 'You receive'),
      isNot(contains('Andrei Popescu')),
    );
    expect(find.text('Andrei Popescu'), findsOneWidget);
    expect(find.text('from București'), findsOneWidget);
  });

  testWidgets('schimb carte-pe-carte cu diferență în bani și cărți în plus',
      (tester) async {
    await pump(
      tester,
      DealSummaryCard(
        give: DealPayload(
          books: [userBook(otherBook, 'u2')],
          extraBooks: 2,
          amount: 15,
        ),
        receive: DealPayload(books: [userBook(book, 'u1')]),
        other: seller,
      ),
    );

    final given = textsBetween(tester, 'You give', 'You receive');
    expect(given, contains('Dune'));
    expect(given, contains('+2'));
    expect(given, contains('15 lei'));
    expect(textsBetween(tester, 'You receive', 'Andrada Petrar'),
        contains('The Little Prince'));
  });
}
