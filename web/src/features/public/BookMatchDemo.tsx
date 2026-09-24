import { useEffect, useMemo, useRef, useState, type PointerEvent, type ReactNode } from 'react';
import { Link } from 'react-router-dom';
import { useQuery } from '@tanstack/react-query';
import { useTranslation } from 'react-i18next';
import {
  Bell,
  Compass,
  Heart,
  Home,
  Info,
  RotateCcw,
  SkipForward,
  Sparkles,
  UserRound,
  X,
} from 'lucide-react';
import { booksKeys, booksRepository } from '@/features/books/booksRepository';
import { BookCover } from '@/components/ui/BookCover';
import { Spinner } from '@/components/ui';
import type { Book } from '@/types/models';

/** Câte cărți are teancul de probă. */
const DEMO_SIZE = 20;

/** Cerem mai multe: anunțurile repetă aceeași carte, iar unele n-au copertă. */
const DEMO_FETCH_LIMIT = 60;

/** Același prag ca în aplicație (`_swipeThreshold` din book_match_screen.dart). */
const SWIPE_THRESHOLD = 110;

/** Cât durează zborul cardului / revenirea lui, în ms. */
const FLIGHT_MS = 260;

type Decision = 'YES' | 'NO' | 'SKIP';

interface Offset {
  x: number;
  y: number;
}

/**
 * Book Match de probă pentru vizitatorul fără cont.
 *
 * Stânga: ce e Book Match și ce schimbă în aplicație. Dreapta: o copie 1:1 a
 * ecranului din aplicație (frontend/lib/features/book_match/presentation/
 * book_match_screen.dart) - teanc de carduri, tras stânga/dreapta/sus, cu
 * ștampilele DA/NU/SKIP și aceleași trei butoane rotunde.
 *
 * Teancul vine din anunțurile publice, deciziile rămân în memorie, iar la
 * final omul primește un rezumat cu grafic în locul teancului.
 */
export function BookMatchDemo() {
  const { t } = useTranslation();
  const [decisions, setDecisions] = useState<Decision[]>([]);

  const params = { limit: DEMO_FETCH_LIMIT, sort: 'recent' };
  const listings = useQuery({
    queryKey: booksKeys.browse(params),
    queryFn: ({ signal }) => booksRepository.browse(params, signal),
  });

  const books = useMemo(() => {
    const seen = new Set<string>();
    const result: Book[] = [];
    for (const item of listings.data?.items ?? []) {
      if (!item.book.coverUrl || seen.has(item.book.id)) continue;
      seen.add(item.book.id);
      result.push(item.book);
      if (result.length === DEMO_SIZE) break;
    }
    return result;
  }, [listings.data]);

  // Fără cărți (API căzut sau catalog gol) secțiunea dispare - o demonstrație
  // goală ar spune exact opusul a ce vrea să spună.
  if (listings.isError || (!listings.isPending && books.length === 0)) return null;

  const index = decisions.length;
  const done = !listings.isPending && index >= books.length;

  const benefits: { icon: ReactNode; title: string; text: string }[] = [
    {
      icon: <Sparkles size={18} />,
      title: t('landingMatchBenefitMatchesTitle', 'Potriviri de schimb mai bune'),
      text: t(
        'landingMatchBenefitMatchesText',
        'Fiecare „da" ajunge în lista ta de dorințe, iar potrivirile de schimb caută exact oamenii care au acele cărți și vor ceva de pe raftul tău.',
      ),
    },
    {
      icon: <UserRound size={18} />,
      title: t('landingMatchBenefitProfileTitle', 'Profilul tău de cititor'),
      text: t(
        'landingMatchBenefitProfileText',
        'Genurile, autorii și epocile care îți plac se adună într-un profil care se rafinează cu fiecare swipe. Îl poți recalibra oricând.',
      ),
    },
    {
      icon: <Bell size={18} />,
      title: t('landingMatchBenefitNotificationsTitle', 'Notificări care contează'),
      text: t(
        'landingMatchBenefitNotificationsText',
        'Primești un semn când apare lângă tine o carte aleasă de tine sau una din genurile tale preferate - nu la fiecare anunț nou.',
      ),
    },
    {
      icon: <Home size={18} />,
      title: t('landingMatchBenefitHomeTitle', 'Recomandări pe măsura ta'),
      text: t(
        'landingMatchBenefitHomeText',
        'Rândul „Ți s-ar potrivi" de pe Acasă se construiește din gusturile tale, nu doar din ce s-a adăugat ultima dată.',
      ),
    },
    {
      icon: <Compass size={18} />,
      title: t('landingMatchBenefitDiscoveryTitle', 'Descoperiri dincolo de obișnuit'),
      text: t(
        'landingMatchBenefitDiscoveryText',
        'Din când în când apare o carte „Descoperire", din afara zonei tale de confort, ca să nu rămâi mereu la aceleași trei genuri.',
      ),
    },
  ];

  return (
    <section className="mt-14 rounded-[16px] border border-border bg-card p-6 min-[900px]:p-8">
      <div className="grid gap-10 min-[900px]:grid-cols-2 min-[900px]:items-start">
        <div>
          <h2 className="font-display text-2xl font-bold">
            {t('landingMatchDemoTitle', 'Încearcă Book Match')}
          </h2>
          <p className="mt-3 max-w-[60ch] text-muted-foreground">
            {t(
              'landingMatchDemoIntro',
              'Book Match îți arată cărți una câte una: tragi la dreapta dacă te interesează, la stânga dacă nu. Din fiecare alegere, aplicația învață ce fel de cititor ești - și tot restul aplicației se așază după asta.',
            )}
          </p>

          <ul className="mt-6 space-y-4">
            {benefits.map((benefit) => (
              <li key={benefit.title} className="flex gap-3">
                <span className="mt-0.5 inline-flex size-8 shrink-0 items-center justify-center rounded-lg bg-accent/15 text-accent">
                  {benefit.icon}
                </span>
                <div>
                  <p className="font-semibold">{benefit.title}</p>
                  <p className="mt-0.5 text-sm leading-relaxed text-muted-foreground">
                    {benefit.text}
                  </p>
                </div>
              </li>
            ))}
          </ul>

          <p className="mt-6 text-sm font-semibold text-accent">
            {t(
              'landingMatchDemoTryHint',
              'Încearcă alături: {count} cărți, apoi vezi ce fel de cititor ești.',
              { count: DEMO_SIZE },
            )}
          </p>
        </div>

        <div className="mx-auto w-full max-w-[420px]">
          {listings.isPending ? (
            <div className="flex h-[560px] items-center justify-center text-accent">
              <Spinner size={28} />
            </div>
          ) : done ? (
            <DemoResults books={books} decisions={decisions} onRestart={() => setDecisions([])} />
          ) : (
            <SwipeDeck
              books={books}
              index={index}
              onDecide={(decision) => setDecisions((current) => [...current, decision])}
            />
          )}
        </div>
      </div>
    </section>
  );
}

/**
 * Teancul de carduri - comportamentul din `_buildStack` / `_onPanEnd` /
 * `_flyOut` din aplicație: cardul se rotește proporțional cu deplasarea,
 * ștampila crește spre prag, iar la eliberare fie zboară, fie revine.
 */
function SwipeDeck({
  books,
  index,
  onDecide,
}: {
  books: Book[];
  index: number;
  onDecide: (decision: Decision) => void;
}) {
  const { t } = useTranslation();
  const [offset, setOffset] = useState<Offset>({ x: 0, y: 0 });
  const [animating, setAnimating] = useState(false);
  const [infoOpen, setInfoOpen] = useState(false);
  const drag = useRef<{ start: Offset; last: Offset; lastTime: number; vx: number } | null>(null);
  const deckRef = useRef<HTMLDivElement>(null);
  const timer = useRef<number | undefined>(undefined);

  useEffect(() => () => window.clearTimeout(timer.current), []);

  const card = books[index];
  const next = books[index + 1];

  function flyOut(decision: Decision) {
    if (!card || animating) return;
    const width = deckRef.current?.offsetWidth ?? 400;
    const height = deckRef.current?.offsetHeight ?? 560;
    const target =
      decision === 'YES'
        ? { x: width * 1.4, y: offset.y }
        : decision === 'NO'
          ? { x: -width * 1.4, y: offset.y }
          : { x: offset.x, y: -height * 1.1 };
    setAnimating(true);
    setInfoOpen(false);
    setOffset(target);
    timer.current = window.setTimeout(() => {
      // Fără tranziție la resetare: cardul următor trebuie să apară pe loc,
      // nu să „zboare înapoi" din colț.
      setAnimating(false);
      setOffset({ x: 0, y: 0 });
      onDecide(decision);
    }, FLIGHT_MS);
  }

  function springBack() {
    setAnimating(true);
    setOffset({ x: 0, y: 0 });
    timer.current = window.setTimeout(() => setAnimating(false), FLIGHT_MS);
  }

  function onPointerDown(event: PointerEvent<HTMLDivElement>) {
    if (animating) return;
    event.currentTarget.setPointerCapture(event.pointerId);
    const point = { x: event.clientX, y: event.clientY };
    drag.current = { start: point, last: point, lastTime: event.timeStamp, vx: 0 };
  }

  function onPointerMove(event: PointerEvent<HTMLDivElement>) {
    const state = drag.current;
    if (!state) return;
    const dt = Math.max(event.timeStamp - state.lastTime, 1);
    state.vx = ((event.clientX - state.last.x) / dt) * 1000;
    state.last = { x: event.clientX, y: event.clientY };
    state.lastTime = event.timeStamp;
    setOffset({ x: event.clientX - state.start.x, y: event.clientY - state.start.y });
  }

  function onPointerUp() {
    const state = drag.current;
    if (!state) return;
    drag.current = null;
    const right = offset.x > SWIPE_THRESHOLD || state.vx > 700;
    const left = offset.x < -SWIPE_THRESHOLD || state.vx < -700;
    // Swipe în sus = skip, doar dacă mișcarea a fost clar verticală.
    const up = offset.y < -SWIPE_THRESHOLD && Math.abs(offset.x) < SWIPE_THRESHOLD;
    if (right) flyOut('YES');
    else if (left) flyOut('NO');
    else if (up) flyOut('SKIP');
    else springBack();
  }

  const progress = Math.max(-1, Math.min(1, offset.x / SWIPE_THRESHOLD));
  const skipProgress = Math.max(0, Math.min(1, -offset.y / SWIPE_THRESHOLD));
  const angle = ((offset.x / 1400) * Math.PI) / 4;

  return (
    <div className="flex flex-col">
      <div ref={deckRef} className="relative h-[480px] select-none">
        {next && (
          <div
            className="absolute inset-0 opacity-60"
            style={{ transform: `scale(${0.94 + 0.06 * Math.abs(progress)})` }}
          >
            <MatchCard book={next} />
          </div>
        )}
        {card && (
          <div
            className="absolute inset-0 cursor-grab touch-none active:cursor-grabbing"
            style={{
              transform: `translate(${offset.x}px, ${offset.y}px) rotate(${angle}rad)`,
              transition: animating
                ? `transform ${FLIGHT_MS}ms ${offset.x === 0 && offset.y === 0 ? 'ease-out' : 'ease-in'}`
                : 'none',
            }}
            onPointerDown={onPointerDown}
            onPointerMove={onPointerMove}
            onPointerUp={onPointerUp}
            onPointerCancel={onPointerUp}
          >
            <MatchCard
              book={card}
              yes={progress > 0 ? progress : 0}
              no={progress < 0 ? -progress : 0}
              skip={Math.abs(offset.x) < SWIPE_THRESHOLD ? skipProgress : 0}
              info={infoOpen}
              onCloseInfo={() => setInfoOpen(false)}
            />
          </div>
        )}
      </div>

      {/* Butoanele: ✕ și ⓘ la margini, inima centrată pe toată lățimea -
          același layout ca `_buildActions` din aplicație. */}
      <div className="relative mt-3 flex items-start justify-between px-2">
        <RoundAction
          label={t('bookMatchNoLabel', 'Nu')}
          tooltip={t('bookMatchNoTooltip', 'Nu mă interesează')}
          tone="destructive"
          disabled={animating}
          onClick={() => flyOut('NO')}
        >
          <X size={24} />
        </RoundAction>
        <div className="absolute left-1/2 top-0 -translate-x-1/2">
          <RoundAction
            label={t('bookMatchYesLabel', 'Da')}
            tooltip={t('bookMatchYesTooltip', 'Îmi place')}
            tone="success"
            disabled={animating}
            onClick={() => flyOut('YES')}
          >
            <Heart size={24} fill="currentColor" />
          </RoundAction>
        </div>
        <RoundAction
          label={t('bookMatchInfoLabel', 'Detalii')}
          tooltip={t('bookMatchInfoTooltip', 'Detalii carte')}
          tone="muted"
          disabled={!card}
          onClick={() => setInfoOpen((open) => !open)}
        >
          <Info size={24} />
        </RoundAction>
      </div>

      <button
        onClick={() => flyOut('SKIP')}
        disabled={animating}
        className="mx-auto mt-1 inline-flex items-center gap-1.5 py-1.5 text-sm font-semibold text-muted-foreground hover:text-foreground disabled:opacity-50"
      >
        <SkipForward size={16} />
        {t('bookMatchSkip', 'Sari peste')}
      </button>
      <p className="mt-0.5 text-center text-xs text-muted-foreground">
        {t(
          'bookMatchHint',
          'Trage cardul la dreapta pentru da, la stânga pentru nu sau în sus ca să sari peste.',
        )}
      </p>
      <p className="mt-2 text-center text-xs font-semibold text-muted-foreground">
        {Math.min(index + 1, books.length)} / {books.length}
      </p>
    </div>
  );
}

/** Cardul din `_BookMatchCardView`: copertă mare, titlu, autor, gen · an, ștampile. */
function MatchCard({
  book,
  yes = 0,
  no = 0,
  skip = 0,
  info = false,
  onCloseInfo,
}: {
  book: Book;
  yes?: number;
  no?: number;
  skip?: number;
  info?: boolean;
  onCloseInfo?: () => void;
}) {
  const { t } = useTranslation();
  const meta = [book.genre, book.publishedYear].filter(Boolean).join(' · ');

  return (
    <article className="relative flex h-full flex-col overflow-hidden rounded-[20px] border border-border bg-background shadow-lg">
      <div className="flex min-h-0 flex-1 items-center justify-center px-4 pt-2">
        <div className="relative aspect-[5/7] h-full max-w-full overflow-hidden rounded-md bg-muted">
          <BookCover url={book.coverUrl} title={book.title} eager />
        </div>
      </div>
      <div className="px-4 pb-4 pt-3">
        <h3 className="line-clamp-2 font-display text-xl font-bold leading-tight">{book.title}</h3>
        {book.author && (
          <p className="mt-0.5 truncate text-sm text-muted-foreground">{book.author}</p>
        )}
        {meta && <p className="mt-1.5 text-xs text-muted-foreground">{meta}</p>}
      </div>

      <Stamp text={t('bookMatchStampYes', 'DA')} tone="success" opacity={yes} angle={-0.32} className="left-4 top-5" />
      <Stamp text={t('bookMatchStampNo', 'NU')} tone="destructive" opacity={no} angle={0.32} className="right-4 top-5" />
      <Stamp
        text={t('bookMatchStampSkip', 'SKIP')}
        tone="muted"
        opacity={skip}
        angle={0}
        className="bottom-5 left-1/2 -translate-x-1/2"
      />

      {/* Detaliile cărții - în aplicație sunt un bottom sheet; aici un strat
          peste card, ca să nu iasă din secțiune. */}
      {info && (
        <div
          className="absolute inset-0 flex flex-col bg-card/95 p-5 backdrop-blur-sm"
          onPointerDown={(event) => event.stopPropagation()}
        >
          <div className="flex items-start justify-between gap-3">
            <div>
              <p className="font-display text-lg font-bold leading-tight">{book.title}</p>
              {book.author && <p className="mt-0.5 text-sm text-muted-foreground">{book.author}</p>}
              {meta && <p className="mt-1 text-xs text-muted-foreground">{meta}</p>}
            </div>
            <button
              onClick={onCloseInfo}
              aria-label={t('commonClose', 'Închide')}
              className="rounded-full p-1.5 text-muted-foreground hover:bg-muted"
            >
              <X size={18} />
            </button>
          </div>
          <p className="mt-4 min-h-0 flex-1 overflow-y-auto text-sm leading-relaxed">
            {book.description || t('landingMatchDemoNoDescription', 'Cartea nu are încă o descriere.')}
          </p>
        </div>
      )}
    </article>
  );
}

const TONES = {
  success: { text: 'text-success', border: 'border-success', bg: 'bg-success/[0.12]' },
  destructive: { text: 'text-destructive', border: 'border-destructive', bg: 'bg-destructive/[0.12]' },
  muted: { text: 'text-muted-foreground', border: 'border-muted-foreground', bg: 'bg-muted-foreground/[0.12]' },
} as const;

function Stamp({
  text,
  tone,
  opacity,
  angle,
  className,
}: {
  text: string;
  tone: keyof typeof TONES;
  opacity: number;
  angle: number;
  className: string;
}) {
  if (opacity <= 0.01) return null;
  return (
    <div className={`pointer-events-none absolute ${className}`} style={{ opacity: Math.min(opacity, 1) }}>
      <div
        className={`rounded-[10px] border-4 px-3 py-1.5 text-[28px] font-extrabold tracking-[2px] ${TONES[tone].border} ${TONES[tone].text}`}
        style={{ transform: `rotate(${angle}rad)` }}
      >
        {text}
      </div>
    </div>
  );
}

/** Butonul rotund cu etichetă dedesubt (`_RoundAction`). */
function RoundAction({
  label,
  tooltip,
  tone,
  disabled,
  onClick,
  children,
}: {
  label: string;
  tooltip: string;
  tone: keyof typeof TONES;
  disabled?: boolean;
  onClick: () => void;
  children: ReactNode;
}) {
  return (
    <div className="flex flex-col items-center gap-1">
      <button
        onClick={onClick}
        disabled={disabled}
        title={tooltip}
        aria-label={tooltip}
        className={`flex size-[52px] items-center justify-center rounded-full transition hover:scale-105 disabled:opacity-50 ${TONES[tone].bg} ${TONES[tone].text}`}
      >
        {children}
      </button>
      <span className={`text-xs font-medium ${disabled ? 'text-muted-foreground/50' : ''}`}>{label}</span>
    </div>
  );
}

/**
 * Rezumatul de la final, în locul teancului: câte „da"/„nu"/„sari", un
 * grafic cu genurile care i-au plăcut și autorii preferați.
 */
function DemoResults({
  books,
  decisions,
  onRestart,
}: {
  books: Book[];
  decisions: Decision[];
  onRestart: () => void;
}) {
  const { t } = useTranslation();

  const total = decisions.length;
  const yes = decisions.filter((d) => d === 'YES').length;
  const no = decisions.filter((d) => d === 'NO').length;
  const skip = total - yes - no;

  // Genurile: câte „da" a primit fiecare din câte cărți a văzut omul din el.
  const genres = useMemo(() => {
    const byGenre = new Map<string, { seen: number; liked: number }>();
    books.forEach((book, i) => {
      const genre = book.genre?.trim() || t('landingMatchDemoOtherGenre', 'Altele');
      const entry = byGenre.get(genre) ?? { seen: 0, liked: 0 };
      entry.seen += 1;
      if (decisions[i] === 'YES') entry.liked += 1;
      byGenre.set(genre, entry);
    });
    return [...byGenre.entries()]
      .map(([genre, entry]) => ({ genre, ...entry }))
      .sort((a, b) => b.liked - a.liked || b.seen - a.seen)
      .slice(0, 6);
  }, [books, decisions, t]);

  const likedAuthors = useMemo(
    () => [
      ...new Set(
        books
          .filter((book, i) => decisions[i] === 'YES' && book.author)
          .map((book) => book.author as string),
      ),
    ].slice(0, 5),
    [books, decisions],
  );

  const maxSeen = Math.max(1, ...genres.map((g) => g.seen));
  const percent = (value: number) => (total === 0 ? 0 : Math.round((value / total) * 100));

  return (
    <div className="rounded-[20px] border border-border bg-background p-5 shadow-lg">
      <h3 className="font-display text-xl font-bold">
        {t('landingMatchDemoResultsTitle', 'Rezultatul tău')}
      </h3>

      {/* Distribuția deciziilor, ca o singură bară împărțită. */}
      <div className="mt-4 flex h-3 overflow-hidden rounded-full bg-muted">
        <div className="bg-success" style={{ width: `${percent(yes)}%` }} />
        <div className="bg-destructive" style={{ width: `${percent(no)}%` }} />
        <div className="bg-muted-foreground/40" style={{ width: `${percent(skip)}%` }} />
      </div>
      <div className="mt-3 grid grid-cols-3 gap-3">
        <Stat value={yes} label={t('landingMatchDemoLiked', 'Ți-au plăcut')} tone="text-success" />
        <Stat value={no} label={t('landingMatchDemoRejected', 'Respinse')} tone="text-destructive" />
        <Stat value={skip} label={t('landingMatchDemoSkipped', 'Sărite')} tone="text-muted-foreground" />
      </div>

      <h4 className="mt-6 text-[11px] font-semibold uppercase tracking-[0.1em] text-muted-foreground">
        {t('landingMatchDemoGenres', 'Genurile tale')}
      </h4>
      <ul className="mt-3 space-y-2.5">
        {genres.map((g) => (
          <li key={g.genre}>
            <div className="flex justify-between text-sm">
              <span className="truncate pr-3">{g.genre}</span>
              <span className="shrink-0 text-muted-foreground">
                {g.liked} / {g.seen}
              </span>
            </div>
            {/* Bara întreagă = cărțile văzute din gen, partea plină = cele plăcute. */}
            <div
              className="mt-1 h-2 overflow-hidden rounded-full bg-muted"
              style={{ width: `${(g.seen / maxSeen) * 100}%` }}
            >
              <div
                className="h-full rounded-full bg-accent"
                style={{ width: `${(g.liked / g.seen) * 100}%` }}
              />
            </div>
          </li>
        ))}
      </ul>

      {likedAuthors.length > 0 && (
        <p className="mt-5 text-sm text-muted-foreground">
          <span className="font-semibold text-foreground">
            {t('landingMatchDemoAuthors', 'Autori pe care i-ai ales:')}
          </span>{' '}
          {likedAuthors.join(', ')}
        </p>
      )}

      <p className="mt-6 text-sm text-muted-foreground">
        {t(
          'landingMatchDemoCta',
          'Cu un cont, cărțile care ți-au plăcut ajung în lista ta de dorințe și primești un semn când apar pe site.',
        )}
      </p>
      <div className="mt-4 flex flex-wrap gap-3">
        <Link
          to="/register"
          className="rounded-full bg-primary px-6 py-3 text-sm font-bold text-primary-foreground"
        >
          {t('landingCtaRegister', 'Creează cont gratuit')}
        </Link>
        <button
          onClick={onRestart}
          className="inline-flex items-center gap-1.5 rounded-full border border-border px-5 py-3 text-sm font-bold hover:bg-muted"
        >
          <RotateCcw size={15} />
          {t('landingMatchDemoRestart', 'Încă o dată')}
        </button>
      </div>
    </div>
  );
}

function Stat({ value, label, tone }: { value: number; label: string; tone: string }) {
  return (
    <div className="rounded-[12px] border border-border p-3 text-center">
      <p className={`font-display text-2xl font-bold ${tone}`}>{value}</p>
      <p className="mt-0.5 text-xs text-muted-foreground">{label}</p>
    </div>
  );
}
