import { useEffect, useMemo, useRef, useState, type PointerEvent } from 'react';
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { useTranslation } from 'react-i18next';
import { HeaderAction, ScreenHeader } from '@/components/layout/ScreenHeader';
import { Heart, SkipForward, SlidersHorizontal, X } from 'lucide-react';
import { bookMatchRepository, socialKeys, type BookMatchCard } from './socialRepository';
import { listsKeys } from '@/features/lists/listsRepository';
import { BookCover } from '@/components/ui/BookCover';
import { Button, ErrorNotice, Spinner } from '@/components/ui';
import { useToast } from '@/components/ui/Toast';
import { useCompleteOnboardingTodo } from '@/features/home/onboardingTodo';

/** Același prag ca demo-ul public și `_swipeThreshold` din aplicația Flutter. */
const SWIPE_THRESHOLD = 110;

/** Viteza (px/s) peste care o aruncare scurtă contează ca swipe. */
const FLING_VELOCITY = 700;

/** Cât durează zborul cardului / revenirea lui, în ms. */
const FLIGHT_MS = 260;

type Decision = 'YES' | 'NO' | 'SKIP';

/** Câte cărți cerem o dată - backendul acceptă 1-50. */
const BATCH_SIZE = 20;

/**
 * Când mai sunt atâtea cărți nevăzute în teanc, cerem următorul lot. Destul de
 * devreme cât lotul nou să fi ajuns până la ultima carte, și cât coperțile lui
 * să fie deja descărcate.
 */
const PREFETCH_REMAINING = 6;

/** Câte coperți următoare descărcăm dinainte. */
const PRELOAD_AHEAD = 5;

/**
 * Book Match: un teanc de cărți pe care userul le acceptă sau le respinge.
 * Un „da" adaugă cartea în lista de dorințe (sursa BOOK_MATCH).
 */
export function BookMatchScreen() {
  const { t } = useTranslation();
  const queryClient = useQueryClient();
  const toast = useToast();
  const completeTodo = useCompleteOnboardingTodo();

  /**
   * Sesiunea se generează O SINGURĂ dată, la montarea ecranului, și se trimite
   * atât la cerere, cât și la fiecare swipe: backendul leagă teancul servit de
   * acest id, iar fără el nu poate corela răspunsurile cu ce a trimis. Un id
   * nou la fiecare randare ar cere de fiecare dată alt teanc.
   */
  const sessionId = useRef(crypto.randomUUID());

  // Indexul cardului curent e local, nu recitit de la server după fiecare
  // swipe: altfel fiecare decizie ar costa o cerere de listă în plus, iar
  // teancul ar clipi la fiecare card.
  const [index, setIndex] = useState(0);

  const queue = useQuery({
    queryKey: socialKeys.bookMatchQueue(),
    queryFn: ({ signal }) => bookMatchRepository.queue(sessionId.current, BATCH_SIZE, signal),
  });

  /*
    Loturile următoare. Teancul se lungește pe măsură ce omul trage: până acum
    se cerea un singur lot de 20, iar după a 20-a carte ecranul spunea „asta e
    tot" deși catalogul avea încă mii de titluri.
  */
  const [more, setMore] = useState<BookMatchCard[]>([]);
  const [exhausted, setExhausted] = useState(false);
  const [loadingMore, setLoadingMore] = useState(false);
  const cards = useMemo(() => [...(queue.data?.cards ?? []), ...more], [queue.data, more]);

  useEffect(() => {
    if (!queue.data || exhausted || loadingMore) return;
    if (cards.length - index > PREFETCH_REMAINING) return;
    setLoadingMore(true);
    bookMatchRepository
      .queue(sessionId.current, BATCH_SIZE)
      .then((next) => {
        // Serverul exclude ce s-a tras deja în sesiune, dar nu și cărțile din
        // teanc încă netrase - acelea pot reveni, deci le filtrăm aici.
        const known = new Set(cards.map((c) => c.bookId));
        const fresh = next.cards.filter((c) => !known.has(c.bookId));
        if (fresh.length === 0) setExhausted(true);
        else setMore((current) => [...current, ...fresh]);
      })
      .catch(() => setExhausted(true))
      .finally(() => setLoadingMore(false));
  }, [queue.data, cards, index, exhausted, loadingMore]);

  // Coperțile următoarelor cărți se descarcă dinainte: altfel fiecare apărea
  // abia după ce cardul ajungea în față, cu o pauză de 1-2 secunde.
  useEffect(() => {
    for (const next of cards.slice(index + 1, index + 1 + PRELOAD_AHEAD)) {
      if (next.coverUrl) new Image().src = next.coverUrl;
    }
  }, [cards, index]);

  function restart() {
    // Teanc nou = sesiune nouă: swipe-urile de acum nu mai au ce căuta în
    // sesiunea veche.
    sessionId.current = crypto.randomUUID();
    setMore([]);
    setExhausted(false);
    setIndex(0);
  }

  const status = useQuery({
    queryKey: socialKeys.bookMatchStatus(),
    queryFn: ({ signal }) => bookMatchRepository.status(signal),
  });

  const swipe = useMutation({
    mutationFn: (input: { bookId: string; action: 'YES' | 'NO' | 'SKIP'; isDiscovery: boolean }) =>
      bookMatchRepository.swipe({ ...input, sessionId: sessionId.current }),
    onSuccess: (result) => {
      // Invalidăm lista de dorințe doar dacă backendul CHIAR a adăugat ceva.
      // Un „da" pe o carte deja în listă nu schimbă nimic, iar o invalidare
      // inutilă reîncarcă ecranul de wishlist degeaba.
      if (result.addedToWishlist) {
        void queryClient.invalidateQueries({ queryKey: listsKeys.wishlist() });
      }
    },
    onError: () => toast.show(t('commonGenericError'), 'danger'),
  });

  const recalibrate = useMutation({
    mutationFn: () => bookMatchRepository.recalibrate(),
    onSuccess: () => {
      // Sesiune nouă: teancul recalibrat e altul, iar swipe-urile care urmează
      // nu mai au ce căuta în sesiunea veche.
      restart();
      void queryClient.invalidateQueries({ queryKey: socialKeys.bookMatchQueue() });
      void queryClient.invalidateQueries({ queryKey: socialKeys.bookMatchStatus() });
      toast.show(t('bookMatchRecalibrateDone'));
    },
    onError: () => toast.show(t('bookMatchRecalibrateError'), 'danger'),
  });

  const header = (
    <ScreenHeader
      title={t('bookMatchTitle')}
      back
      actions={
        <HeaderAction
          label={t('bookMatchRecalibrateTooltip')}
          disabled={!status.data?.canRecalibrate || recalibrate.isPending}
          onClick={() => {
            if (window.confirm(t('bookMatchRecalibrateConfirm'))) recalibrate.mutate();
          }}
        >
          <SlidersHorizontal size={22} />
        </HeaderAction>
      }
    />
  );

  if (queue.isPending) {
    return (
      <div className="flex min-h-dvh items-center justify-center text-accent">
        {header}
        <Spinner size={28} />
      </div>
    );
  }

  if (queue.isError) {
    return (
      <div className="mx-auto max-w-2xl p-6">
        {header}
        <ErrorNotice message={t('bookMatchLoadError')} onRetry={() => void queue.refetch()} />
      </div>
    );
  }

  const card = cards[index];

  function decide(action: Decision) {
    // „Încearcă Book Match" din lista „Descoperă ShelfShare" e făcut din clipa
    // în care omul chiar a dat un swipe - nu doar a deschis ecranul și a ieșit.
    completeTodo('bookMatch');
    if (!card) return;
    swipe.mutate({ bookId: card.bookId, action, isDiscovery: card.isDiscovery });
    setIndex((current) => current + 1);
  }

  return (
    <div className="mx-auto flex w-full max-w-[440px] flex-col px-5 pb-16 pt-2 min-[900px]:px-8">
      {header}
      {!card && !exhausted ? (
        // Lotul următor e pe drum: nu anunțăm „asta e tot" înainte să știm.
        <div className="flex justify-center py-24 text-accent">
          <Spinner size={28} />
        </div>
      ) : !card ? (
        <div className="flex flex-col items-center gap-3 py-16 text-center">
          <p className="font-display text-lg font-bold">{t('bookMatchEmptyTitle')}</p>
          <p className="text-muted-foreground">{t('bookMatchEmptyBody')}</p>
          <Button
            variant="outline"
            onClick={() => {
              restart();
              void queue.refetch();
            }}
          >
            {t('commonRetry')}
          </Button>
        </div>
      ) : (
        <>
          <SwipeDeck key={card.bookId} card={card} next={cards[index + 1]} onDecide={decide} />

          <p className="mt-4 text-center text-xs text-muted-foreground">
            {index + 1} / {exhausted ? cards.length : `${cards.length}+`}
          </p>
        </>
      )}
    </div>
  );
}

/**
 * Cardul curent, tras cu degetul sau cu mouse-ul - același comportament ca
 * demo-ul de pe pagina publică și ca `_onPanEnd`/`_flyOut` din Flutter: se
 * rotește după deplasare, ștampila DA/NU/SKIP crește spre prag, iar la
 * eliberare zboară (peste prag sau aruncat repede) ori revine la loc.
 *
 * Butoanele trec prin același `flyOut`, ca un click să arate la fel ca un
 * swipe. `key={card.bookId}` din părinte resetează starea la fiecare carte.
 */
function SwipeDeck({
  card,
  next,
  onDecide,
}: {
  card: BookMatchCard;
  next?: BookMatchCard;
  onDecide: (decision: Decision) => void;
}) {
  const { t } = useTranslation();
  const [offset, setOffset] = useState({ x: 0, y: 0 });
  const [animating, setAnimating] = useState(false);
  const drag = useRef<{
    start: { x: number; y: number };
    lastX: number;
    lastTime: number;
    vx: number;
  } | null>(null);
  const deckRef = useRef<HTMLDivElement>(null);
  const timer = useRef<number | undefined>(undefined);

  useEffect(() => () => window.clearTimeout(timer.current), []);

  function flyOut(decision: Decision) {
    if (animating) return;
    const width = deckRef.current?.offsetWidth ?? 400;
    const height = deckRef.current?.offsetHeight ?? 600;
    setAnimating(true);
    setOffset(
      decision === 'YES'
        ? { x: width * 1.4, y: offset.y }
        : decision === 'NO'
          ? { x: -width * 1.4, y: offset.y }
          : { x: offset.x, y: -height * 1.1 },
    );
    timer.current = window.setTimeout(() => onDecide(decision), FLIGHT_MS);
  }

  function springBack() {
    setAnimating(true);
    setOffset({ x: 0, y: 0 });
    timer.current = window.setTimeout(() => setAnimating(false), FLIGHT_MS);
  }

  function onPointerDown(event: PointerEvent<HTMLDivElement>) {
    if (animating) return;
    event.currentTarget.setPointerCapture(event.pointerId);
    drag.current = {
      start: { x: event.clientX, y: event.clientY },
      lastX: event.clientX,
      lastTime: event.timeStamp,
      vx: 0,
    };
  }

  function onPointerMove(event: PointerEvent<HTMLDivElement>) {
    const state = drag.current;
    if (!state) return;
    const dt = Math.max(event.timeStamp - state.lastTime, 1);
    state.vx = ((event.clientX - state.lastX) / dt) * 1000;
    state.lastX = event.clientX;
    state.lastTime = event.timeStamp;
    setOffset({
      x: event.clientX - state.start.x,
      y: event.clientY - state.start.y,
    });
  }

  function onPointerUp() {
    const state = drag.current;
    if (!state) return;
    drag.current = null;
    if (offset.x > SWIPE_THRESHOLD || state.vx > FLING_VELOCITY) flyOut('YES');
    else if (offset.x < -SWIPE_THRESHOLD || state.vx < -FLING_VELOCITY) flyOut('NO');
    // Sus = skip, doar când mișcarea a fost clar verticală.
    else if (offset.y < -SWIPE_THRESHOLD && Math.abs(offset.x) < SWIPE_THRESHOLD) flyOut('SKIP');
    else springBack();
  }

  const progress = Math.max(-1, Math.min(1, offset.x / SWIPE_THRESHOLD));
  const skipProgress = Math.abs(offset.x) < SWIPE_THRESHOLD ? Math.max(0, Math.min(1, -offset.y / SWIPE_THRESHOLD)) : 0;
  const angle = ((offset.x / 1400) * Math.PI) / 4;

  return (
    <>
      <div ref={deckRef} className="relative select-none">
        {next && (
          <div
            aria-hidden
            className="absolute inset-0 opacity-60"
            style={{ transform: `scale(${0.94 + 0.06 * Math.abs(progress)})` }}
          >
            <MatchCardView card={next} />
          </div>
        )}
        <div
          className="relative cursor-grab touch-none active:cursor-grabbing"
          style={{
            transform: `translate(${offset.x}px, ${offset.y}px) rotate(${angle}rad)`,
            transition: animating
              ? `transform ${FLIGHT_MS}ms ${offset.x === 0 && offset.y === 0 ? 'ease-out' : 'ease-in'}`
              : 'none',
          }}
          onPointerDown={onPointerDown}
          // Fără asta, cu mouse-ul browserul pornește drag-ul nativ al copertei
          // și înghite mișcarea în loc să arunce cartea.
          onDragStart={(event) => event.preventDefault()}
          onPointerMove={onPointerMove}
          onPointerUp={onPointerUp}
          onPointerCancel={onPointerUp}
        >
          <MatchCardView card={card} />
          <Stamp
            text={t('bookMatchYesLabel')}
            opacity={Math.max(0, progress)}
            className="left-4 top-6 -rotate-12 border-success text-success"
          />
          <Stamp
            text={t('bookMatchNoLabel')}
            opacity={Math.max(0, -progress)}
            className="right-4 top-6 rotate-12 border-destructive text-destructive"
          />
          <Stamp
            text={t('bookMatchSkip')}
            opacity={skipProgress}
            className="bottom-28 left-1/2 -translate-x-1/2 border-muted-foreground text-muted-foreground"
          />
        </div>
      </div>

      <p className="mt-4 text-center text-sm text-muted-foreground">{t('bookMatchHint')}</p>

      <div className="mt-4 flex items-center justify-center gap-4">
        <ActionButton
          onClick={() => flyOut('NO')}
          label={t('bookMatchNoLabel')}
          tone="border-destructive text-destructive"
          disabled={animating}
        >
          <X size={26} />
        </ActionButton>

        <ActionButton
          onClick={() => flyOut('SKIP')}
          label={t('bookMatchSkip')}
          tone="border-border text-muted-foreground"
          disabled={animating}
        >
          <SkipForward size={20} />
        </ActionButton>

        <ActionButton
          onClick={() => flyOut('YES')}
          label={t('bookMatchYesLabel')}
          tone="border-success text-success"
          disabled={animating}
        >
          <Heart size={26} />
        </ActionButton>
      </div>
    </>
  );
}

/**
 * Zona de text are înălțime FIXĂ: cu descrierea variabilă, cardul se lungea
 * sau se scurta de la o carte la alta, iar butonele de dedesubt săreau sub
 * deget exact când omul voia să apese din nou.
 */
function MatchCardView({ card }: { card: BookMatchCard }) {
  const { t } = useTranslation();
  return (
    <article className="overflow-hidden rounded-[16px] border border-border bg-card">
      <div className="relative aspect-[5/7] bg-muted">
        <BookCover url={card.coverUrl} title={card.title} eager />
        {card.isDiscovery && (
          <span className="absolute left-2 top-2 rounded-full bg-accent px-2.5 py-1 text-[11px] font-bold text-accent-foreground">
            {t('bookMatchDiscoveryBadge')}
          </span>
        )}
      </div>

      <div className="flex h-[10.5rem] flex-col overflow-hidden p-4">
        <h2 className="line-clamp-2 shrink-0 font-display text-lg font-bold leading-tight">
          {card.title}
        </h2>
        {card.author && (
          <p className="mt-1 shrink-0 truncate text-muted-foreground">{card.author}</p>
        )}
        {card.description && (
          <p className="mt-2 line-clamp-3 min-h-0 text-sm text-muted-foreground">
            {card.description}
          </p>
        )}
      </div>
    </article>
  );
}

function Stamp({ text, opacity, className }: { text: string; opacity: number; className: string }) {
  if (opacity <= 0) return null;
  return (
    <span
      aria-hidden
      className={`pointer-events-none absolute rounded-lg border-[3px] bg-card/80 px-3 py-1 font-display text-2xl font-extrabold uppercase ${className}`}
      style={{ opacity }}
    >
      {text}
    </span>
  );
}

function ActionButton({
  onClick,
  label,
  tone,
  disabled,
  children,
}: {
  onClick: () => void;
  label: string;
  tone: string;
  disabled?: boolean;
  children: React.ReactNode;
}) {
  return (
    <button
      onClick={onClick}
      disabled={disabled}
      aria-label={label}
      title={label}
      className={`flex size-14 items-center justify-center rounded-full border-2 bg-card transition hover:scale-105 disabled:opacity-60 ${tone}`}
    >
      {children}
    </button>
  );
}
