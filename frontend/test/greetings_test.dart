import 'package:flutter_test/flutter_test.dart';
import 'package:shelfshare/features/home/presentation/greetings.dart';
import 'package:shelfshare/l10n/app_localizations_ro.dart';

void main() {
  final l10n = AppLocalizationsRo();

  List<String> textsAt(
    DateTime now, {
    String? name,
    int? birthdayMonth,
    int? birthdayDay,
  }) =>
      buildGreetings(
        l10n: l10n,
        now: now,
        name: name,
        birthdayMonth: birthdayMonth,
        birthdayDay: birthdayDay,
      ).map((p) => p.text).toList();

  group('intervale orare', () {
    // O zi de miercuri, ca mesajele de weekend/luni/vineri să nu se amestece.
    DateTime wednesdayAt(int hour) => DateTime(2026, 7, 29, hour);

    test('05:00-10:00 dă mesajele de dimineață', () {
      final texts = textsAt(wednesdayAt(7));
      expect(texts, contains(l10n.greetMorningSun));
      expect(texts, isNot(contains(l10n.greetDayLibrary)));
    });

    test('10:00-17:00 dă mesajele de zi', () {
      final texts = textsAt(wednesdayAt(13));
      expect(texts, contains(l10n.greetDayLibrary));
      expect(texts, isNot(contains(l10n.greetMorningSun)));
    });

    test('17:00-21:00 dă mesajele de seară', () {
      expect(textsAt(wednesdayAt(19)), contains(l10n.greetEveningHello));
    });

    test('21:00-00:00 dă mesajele de noapte', () {
      expect(textsAt(wednesdayAt(22)), contains(l10n.greetNightGoodNight));
    });

    test('00:00-05:00 dă mesajele de noapte târzie', () {
      expect(textsAt(wednesdayAt(2)), contains(l10n.greetLateNightOwl));
    });

    test('granițele cad în intervalul de sus, nu în cel de jos', () {
      expect(textsAt(wednesdayAt(5)), contains(l10n.greetMorningSun));
      expect(textsAt(wednesdayAt(10)), contains(l10n.greetDayLibrary));
      expect(textsAt(wednesdayAt(17)), contains(l10n.greetEveningHello));
      expect(textsAt(wednesdayAt(21)), contains(l10n.greetNightGoodNight));
      expect(textsAt(wednesdayAt(0)), contains(l10n.greetLateNightOwl));
    });
  });

  group('numele userului', () {
    test('e folosit când există', () {
      expect(textsAt(DateTime(2026, 7, 29, 13), name: 'Toni'),
          contains(l10n.greetDayNamed('Toni')));
    });

    test('cade pe „Cititorule" când lipsește sau e gol', () {
      final fallback = l10n.greetDayNamed(l10n.greetReaderFallback);
      expect(textsAt(DateTime(2026, 7, 29, 13)), contains(fallback));
      expect(textsAt(DateTime(2026, 7, 29, 13), name: '   '), contains(fallback));
    });
  });

  group('zile din săptămână', () {
    test('sâmbăta și duminica dau mesajul de weekend', () {
      expect(textsAt(DateTime(2026, 8, 1, 13)), contains(l10n.greetWeekend)); // sâmbătă
      expect(textsAt(DateTime(2026, 8, 2, 13)), contains(l10n.greetWeekend)); // duminică
    });

    test('lunea dă mesajul de luni', () {
      expect(textsAt(DateTime(2026, 7, 27, 13)), contains(l10n.greetMonday));
    });

    test('vineri, mesajul apare doar seara', () {
      expect(textsAt(DateTime(2026, 7, 31, 19)), contains(l10n.greetFridayEvening));
      expect(textsAt(DateTime(2026, 7, 31, 9)), isNot(contains(l10n.greetFridayEvening)));
    });
  });

  group('ocazii speciale', () {
    test('ziua de naștere se potrivește pe zi și lună', () {
      expect(
        textsAt(DateTime(2026, 3, 14, 13), birthdayMonth: 3, birthdayDay: 14),
        contains(l10n.greetBirthday),
      );
      expect(
        textsAt(DateTime(2026, 3, 15, 13), birthdayMonth: 3, birthdayDay: 14),
        isNot(contains(l10n.greetBirthday)),
      );
    });

    test('1 Decembrie', () {
      expect(textsAt(DateTime(2026, 12, 1, 13)), contains(l10n.greetNationalDay));
    });

    test('Crăciunul ține de pe 24 pe 26', () {
      for (final day in [24, 25, 26]) {
        expect(textsAt(DateTime(2026, 12, day, 13)), contains(l10n.greetChristmas));
      }
      expect(textsAt(DateTime(2026, 12, 27, 13)), isNot(contains(l10n.greetChristmas)));
    });

    test('Anul Nou, de pe 31 decembrie pe 2 ianuarie', () {
      expect(textsAt(DateTime(2026, 12, 31, 13)), contains(l10n.greetNewYear));
      expect(textsAt(DateTime(2027, 1, 1, 13)), contains(l10n.greetNewYear));
      expect(textsAt(DateTime(2027, 1, 3, 13)), isNot(contains(l10n.greetNewYear)));
    });

    test('23 aprilie - Ziua Internațională a Cărții', () {
      expect(textsAt(DateTime(2026, 4, 23, 13)), contains(l10n.greetBookDay));
    });

    test('ocazia stă prima în listă, ca să fie prima văzută', () {
      final texts = textsAt(DateTime(2026, 12, 1, 13));
      expect(texts.first, l10n.greetNationalDay);
    });
  });

  group('Paștele ortodox', () {
    // Date verificate: Paștele ortodox (cel din România), nu cel catolic.
    test('calculează corect datele cunoscute', () {
      expect(orthodoxEaster(2024), DateTime(2024, 5, 5));
      expect(orthodoxEaster(2025), DateTime(2025, 4, 20));
      expect(orthodoxEaster(2026), DateTime(2026, 4, 12));
      expect(orthodoxEaster(2027), DateTime(2027, 5, 2));
      expect(orthodoxEaster(2028), DateTime(2028, 4, 16));
    });

    test('mesajul apare în ziua de Paște și a doua zi', () {
      expect(textsAt(DateTime(2026, 4, 12, 13)), contains(l10n.greetEaster));
      expect(textsAt(DateTime(2026, 4, 13, 13)), contains(l10n.greetEaster));
      expect(textsAt(DateTime(2026, 4, 14, 13)), isNot(contains(l10n.greetEaster)));
    });
  });

  test('lista nu e niciodată goală, la orice oră din an', () {
    for (var day = 0; day < 366; day++) {
      final date = DateTime(2026, 1, 1).add(Duration(days: day));
      for (final hour in [0, 4, 5, 9, 10, 16, 17, 20, 21, 23]) {
        final texts = textsAt(DateTime(date.year, date.month, date.day, hour));
        expect(texts, isNotEmpty, reason: 'gol la $date ora $hour');
      }
    }
  });
}
