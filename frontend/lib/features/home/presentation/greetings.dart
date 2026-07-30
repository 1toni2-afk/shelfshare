import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/typewriter_text.dart';

/// Salutul rotativ din bara de sus a paginii principale, construit din ora și
/// data de pe telefon.
///
/// Ordinea nu e întâmplătoare: mai întâi ocaziile speciale (ziua ta, sărbători),
/// pentru că sunt cele care surprind; apoi mesajele potrivite cu ora; la final
/// contextul de zi a săptămânii. `TypewriterText` le rulează în buclă, deci
/// primul din listă e și primul văzut.
///
/// Funcția e pură - primește `now`, nu îl citește singură - ca să poată fi
/// testată pe orice moment din an fără să ne atingem de ceasul sistemului.
List<TypewriterPhrase> buildGreetings({
  required AppLocalizations l10n,
  required DateTime now,
  String? name,
  int? birthdayMonth,
  int? birthdayDay,
}) {
  final displayName = (name != null && name.trim().isNotEmpty)
      ? name.trim()
      : l10n.greetReaderFallback;

  const occasionHold = Duration(seconds: 8);
  const normalHold = Duration(seconds: 3);

  final phrases = <TypewriterPhrase>[
    for (final text in _occasions(l10n, now, birthdayMonth, birthdayDay))
      TypewriterPhrase(text, occasionHold),
    for (final text in _forHour(l10n, now.hour, displayName))
      TypewriterPhrase(text, normalHold),
    for (final text in _forWeekday(l10n, now)) TypewriterPhrase(text, normalHold),
  ];

  // Prima frază stă mai mult: e cea pe care o vede oricine deschide aplicația
  // și pleacă în câteva secunde.
  return [
    TypewriterPhrase(phrases.first.text, const Duration(seconds: 10)),
    ...phrases.skip(1),
  ];
}

/// Sărbători și aniversări. Pot fi mai multe într-o zi (ex. ziua ta pe 1
/// Decembrie), deci întoarcem o listă, nu o singură valoare.
List<String> _occasions(
  AppLocalizations l10n,
  DateTime now,
  int? birthdayMonth,
  int? birthdayDay,
) {
  final occasions = <String>[];

  if (birthdayMonth == now.month && birthdayDay == now.day) {
    occasions.add(l10n.greetBirthday);
  }
  // 1 Decembrie - Ziua Națională.
  if (now.month == 12 && now.day == 1) {
    occasions.add(l10n.greetNationalDay);
  }
  // Crăciunul ține trei zile: ajunul plus prima și a doua zi.
  if (now.month == 12 && now.day >= 24 && now.day <= 26) {
    occasions.add(l10n.greetChristmas);
  }
  // Anul Nou: 31 decembrie și primele două zile din ianuarie.
  if ((now.month == 12 && now.day == 31) ||
      (now.month == 1 && now.day <= 2)) {
    occasions.add(l10n.greetNewYear);
  }
  // 23 aprilie - Ziua Internațională a Cărții.
  if (now.month == 4 && now.day == 23) {
    occasions.add(l10n.greetBookDay);
  }

  final easter = orthodoxEaster(now.year);
  final easterMonday = easter.add(const Duration(days: 1));
  if (_sameDay(now, easter) || _sameDay(now, easterMonday)) {
    occasions.add(l10n.greetEaster);
  }

  return occasions;
}

/// Cele cinci intervale de zi cerute în Milestone 14.
List<String> _forHour(AppLocalizations l10n, int hour, String name) {
  if (hour >= 5 && hour < 10) {
    return [
      l10n.greetMorningSun,
      l10n.greetMorningNamed(name),
      l10n.greetMorningCoffeeBook,
      l10n.greetMorningCoffee,
      l10n.greetMorningStartStory,
      l10n.greetMorningAdventure,
      l10n.greetMorningSleptWell,
      l10n.greetMorningPerfectBook,
      l10n.greetMorningNicer,
    ];
  }
  if (hour >= 10 && hour < 17) {
    return [
      l10n.greetDayNamed(name),
      l10n.greetDayDiscover,
      l10n.greetDayAdventure,
      l10n.greetDayLibrary,
      l10n.greetDayCorporateCoffee,
      l10n.greetDayWhatsNext,
      l10n.greetDaySwappedToday,
      l10n.greetDayNewReader,
      l10n.greetDayFindNext,
    ];
  }
  if (hour >= 17 && hour < 21) {
    return [
      l10n.greetEveningHello,
      l10n.greetEveningHowWasDay,
      l10n.greetEveningPerfectNow,
      l10n.greetEveningFewPages,
      l10n.greetEveningRelax,
      l10n.greetEveningQuiet,
      l10n.greetEveningWhatTonight,
      l10n.greetEveningBeforeBed,
    ];
  }
  if (hour >= 21) {
    return [
      l10n.greetNightGoodNight,
      l10n.greetNightSandman,
      l10n.greetNightCloseBook,
      l10n.greetNightSleepWell(name),
      l10n.greetNightOneMoreChapter,
      l10n.greetNightSeeYouTomorrow,
      l10n.greetNightNiceDay,
      l10n.greetNightQuiet,
    ];
  }
  // 00:00 - 05:00
  return [
    l10n.greetLateAwake,
    l10n.greetLateNightOwl,
    l10n.greetLateMidnightReads,
    l10n.greetLateOneChapter,
    l10n.greetLateNeverSleeps,
    l10n.greetLateCompany,
    l10n.greetLateLastChapter,
    l10n.greetLateForgotSleep,
  ];
}

List<String> _forWeekday(AppLocalizations l10n, DateTime now) {
  switch (now.weekday) {
    case DateTime.saturday:
    case DateTime.sunday:
      return [l10n.greetWeekend];
    case DateTime.monday:
      return [l10n.greetMonday];
    case DateTime.friday:
      // Doar seara - vineri la 9 dimineața mesajul n-are sens.
      return now.hour >= 17 ? [l10n.greetFridayEvening] : const [];
    default:
      return const [];
  }
}

bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// Data Paștelui ortodox (cel sărbătorit în România), ca dată gregoriană.
///
/// Algoritmul lui Meeus pentru calendarul iulian, plus decalajul iulian →
/// gregorian. Decalajul e 13 zile pentru intervalul 1900-2099, ceea ce acoperă
/// orice an în care aplicația asta va rula; în afara lui rezultatul ar fi
/// greșit cu o zi sau mai mult.
DateTime orthodoxEaster(int year) {
  final a = year % 4;
  final b = year % 7;
  final c = year % 19;
  final d = (19 * c + 15) % 30;
  final e = (2 * a + 4 * b - d + 34) % 7;
  final month = (d + e + 114) ~/ 31; // 3 = martie, 4 = aprilie
  final day = ((d + e + 114) % 31) + 1;
  return DateTime(year, month, day).add(const Duration(days: 13));
}
