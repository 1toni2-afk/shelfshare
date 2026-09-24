import type { TypewriterPhrase } from '@/components/ui/TypewriterText';

type Translate = (key: string, params?: Record<string, unknown>) => string;

const OCCASION_HOLD = 8000;
const NORMAL_HOLD = 3000;
const MOTTO_HOLD = 5000;

/** Prima frază stă mai mult: e cea pe care o citește oricine deschide aplicația. */
const FIRST_HOLD = 10000;

const MORNING = [
  'greetMorningSun',
  'greetMorningNamed',
  'greetMorningCoffeeBook',
  'greetMorningCoffee',
  'greetMorningStartStory',
  'greetMorningAdventure',
  'greetMorningSleptWell',
  'greetMorningPerfectBook',
  'greetMorningNicer',
];

const DAY = [
  'greetDayNamed',
  'greetDayDiscover',
  'greetDayAdventure',
  'greetDayLibrary',
  'greetDayCorporateCoffee',
  'greetDayWhatsNext',
  'greetDaySwappedToday',
  'greetDayNewReader',
  'greetDayFindNext',
];

const EVENING = [
  'greetEveningHello',
  'greetEveningHowWasDay',
  'greetEveningPerfectNow',
  'greetEveningFewPages',
  'greetEveningRelax',
  'greetEveningQuiet',
  'greetEveningWhatTonight',
  'greetEveningBeforeBed',
];

const NIGHT = [
  'greetNightGoodNight',
  'greetNightSandman',
  'greetNightCloseBook',
  'greetNightSleepWell',
  'greetNightOneMoreChapter',
  'greetNightSeeYouTomorrow',
  'greetNightNiceDay',
  'greetNightQuiet',
];

const MOTTOS = [
  'greetMottoStandingTree',
  'greetMottoWhyBuyNew',
  'greetMottoMoreSustainable',
  'greetMottoEuropeanMovement',
  'greetMottoCirculating',
];

/**
 * Frazele de salut din antetul paginii principale. Port al
 * home/presentation/greetings.dart.
 *
 * `now` e ora LOCALĂ a dispozitivului, nu a serverului: salutul trebuie să
 * urmeze fusul userului, altfel „bună dimineața" ar apărea la miezul nopții
 * pentru cine e în alt fus.
 */
export function buildGreetings({
  t,
  now,
  name,
  birthdayMonth,
  birthdayDay,
}: {
  t: Translate;
  now: Date;
  name?: string | null;
  birthdayMonth?: number | null;
  birthdayDay?: number | null;
}): TypewriterPhrase[] {
  const displayName = name?.trim() ? name.trim() : t('greetReaderFallback');

  const phrases: TypewriterPhrase[] = [
    ...occasions(t, now, birthdayMonth, birthdayDay).map((text) => ({
      text,
      holdMs: OCCASION_HOLD,
    })),
    ...forHour(t, now.getHours(), displayName).map((text) => ({
      text,
      holdMs: NORMAL_HOLD,
    })),
    ...forWeekday(t, now).map((text) => ({ text, holdMs: NORMAL_HOLD })),
    ...MOTTOS.map((key) => ({ text: t(key), holdMs: MOTTO_HOLD })),
  ];

  if (phrases.length === 0) return [];
  return [{ text: phrases[0].text, holdMs: FIRST_HOLD }, ...phrases.slice(1)];
}

function occasions(
  t: Translate,
  now: Date,
  birthdayMonth?: number | null,
  birthdayDay?: number | null,
): string[] {
  const month = now.getMonth() + 1;
  const day = now.getDate();
  const result: string[] = [];

  if (birthdayMonth === month && birthdayDay === day) result.push(t('greetBirthday'));
  if (month === 12 && day === 1) result.push(t('greetNationalDay'));
  if (month === 12 && day >= 24 && day <= 26) result.push(t('greetChristmas'));
  if ((month === 12 && day === 31) || (month === 1 && day <= 2)) {
    result.push(t('greetNewYear'));
  }
  if (month === 4 && day === 23) result.push(t('greetBookDay'));

  const easter = orthodoxEaster(now.getFullYear());
  const easterMonday = new Date(easter);
  easterMonday.setDate(easterMonday.getDate() + 1);
  if (sameDay(now, easter) || sameDay(now, easterMonday)) result.push(t('greetEaster'));

  return result;
}

function forHour(t: Translate, hour: number, name: string): string[] {
  // Cheile „Named" primesc numele; restul îl ignoră. Îl trimitem la toate -
  // ICU ignoră un parametru nefolosit, iar alternativa ar fi o listă de
  // excepții care se desincronizează la prima cheie adăugată.
  const translate = (key: string) => t(key, { name });

  if (hour >= 5 && hour < 10) return MORNING.map(translate);
  if (hour >= 10 && hour < 17) return DAY.map(translate);
  if (hour >= 17 && hour < 21) return EVENING.map(translate);
  return NIGHT.map(translate);
}

function forWeekday(t: Translate, now: Date): string[] {
  const weekday = now.getDay();
  if (weekday === 0 || weekday === 6) return [t('greetWeekend')];
  if (weekday === 1) return [t('greetMonday')];
  if (weekday === 5 && now.getHours() >= 17) return [t('greetFridayEvening')];
  return [];
}

function sameDay(a: Date, b: Date): boolean {
  return (
    a.getFullYear() === b.getFullYear() &&
    a.getMonth() === b.getMonth() &&
    a.getDate() === b.getDate()
  );
}

/**
 * Paștele ortodox (Meeus, calendar iulian convertit la gregorian). E singura
 * sărbătoare din listă care se mută de la an la an, deci nu poate fi o dată
 * fixă ca celelalte.
 */
function orthodoxEaster(year: number): Date {
  const a = year % 4;
  const b = year % 7;
  const c = year % 19;
  const d = (19 * c + 15) % 30;
  const e = (2 * a + 4 * b - d + 34) % 7;
  const month = Math.floor((d + e + 114) / 31);
  const day = ((d + e + 114) % 31) + 1;

  // Rezultatul e în calendarul iulian; decalajul față de cel gregorian e de
  // 13 zile pentru secolele XX-XXI.
  const julian = new Date(year, month - 1, day);
  julian.setDate(julian.getDate() + 13);
  return julian;
}
