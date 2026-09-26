import 'package:flutter_test/flutter_test.dart';
import 'package:shelfshare/features/books/data/import_template.dart';
import 'package:shelfshare/features/profile/application/onboarding_todo_controller.dart';

/// Șablonul descărcabil e singura documentație pe care o citesc majoritatea
/// oamenilor înainte să-și scrie fișierul de import, deci un rând cu o
/// coloană în plus sau în minus e mai rău decât niciun șablon: mută tăcut
/// valorile pe coloane greșite (prețul ajunge în „city" etc.).
void main() {
  group('șablonul de import', () {
    final lines = buildImportTemplateCsv()
        .split('\r\n')
        .where((l) => l.isNotEmpty)
        .toList();

    test('antetul e exact lista de coloane citite de backend', () {
      // BOM-ul e pentru Excel; nu face parte din numele primei coloane.
      expect(lines.first.replaceFirst('\u{FEFF}', ''),
          kImportCsvColumns.join(','));
    });

    test('fiecare rând de exemplu are exact atâtea câmpuri câte coloane', () {
      for (final row in lines.skip(1)) {
        expect(row.split(',').length, kImportCsvColumns.length,
            reason: 'rând cu alt număr de câmpuri: $row');
      }
    });

    test('exemplele acoperă cele trei destinații posibile', () {
      final shelfIndex = kImportCsvColumns.indexOf('shelf');
      final shelves = [
        for (final row in lines.skip(1)) row.split(',')[shelfIndex],
      ];
      // Aceleași valori pe care le traduce classifyImportRow în backend.
      expect(shelves, containsAll(<String>['swap', 'read', 'to-read']));
    });

    test('starea din exemplu e o valoare acceptată, nu o etichetă tradusă', () {
      final conditionIndex = kImportCsvColumns.indexOf('condition');
      for (final row in lines.skip(1)) {
        final value = row.split(',')[conditionIndex];
        if (value.isEmpty) continue;
        expect(kImportConditions, contains(value));
      }
    });
  });

  group('lista de primii pași', () {
    test('nu se vede până nu s-a citit ce s-a bifat', () {
      // Altfel cineva care a terminat demult toți pașii vede cardul gol
      // pentru o clipă la fiecare pornire.
      const state = OnboardingTodoState();
      expect(state.loaded, isFalse);
      expect(state.visible, isFalse);
    });

    test('e ascunsă când s-au bifat toți pașii', () {
      final state =
          OnboardingTodoState(done: OnboardingTodo.values.toSet(), loaded: true);
      expect(state.allDone, isTrue);
      expect(state.visible, isFalse);
    });

    test('e ascunsă manual chiar dacă mai sunt pași de făcut', () {
      const state = OnboardingTodoState(
        done: {OnboardingTodo.tutorial},
        dismissed: true,
        loaded: true,
      );
      expect(state.allDone, isFalse);
      expect(state.visible, isFalse);
    });

    test('se vede cât timp mai e ceva de făcut și n-a fost ascunsă', () {
      const state =
          OnboardingTodoState(done: {OnboardingTodo.tutorial}, loaded: true);
      expect(state.visible, isTrue);
      expect(state.isDone(OnboardingTodo.tutorial), isTrue);
      expect(state.isDone(OnboardingTodo.import), isFalse);
    });
  });
}
