import { useMemo, useState } from 'react';
import { Link } from 'react-router-dom';
import { useQuery } from '@tanstack/react-query';
import { useTranslation } from 'react-i18next';
import { Heart, RotateCcw, SkipForward, X } from 'lucide-react';
import { booksKeys, booksRepository } from '@/features/books/booksRepository';
import { BookCover } from '@/components/ui/BookCover';
import { Spinner } from '@/components/ui';
import type { Book } from '@/types/models';

/** Câte cărți are teancul de probă. */
const DEMO_SIZE = 20;

/** Cerem mai multe: anunțurile repetă aceeași carte, iar unele n-au copertă. */
const DEMO_FETCH_LIMIT = 60;

type Decision = 'YES' | 'NO' | 'SKIP';

/**
 * Book Match de probă pentru vizitatorul fără cont.
 *
 * Adevăratul Book Match cere cont (teancul e personalizat și un „da" scrie în
 * lista de dorințe). Aici teancul vine din anunțurile publice, deciziile rămân
 * doar în memorie, iar la final omul primește un rezumat cu grafic - gustul lui
 * de cititor, într-un minut, plus invitația de a-l păstra într-un cont.
 */
export function BookMatchDemo() {
  const { t } = useTranslation();
  const [index, setIndex] = useState(0);
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

  function decide(decision: Decision) {
    setDecisions((current) => [...current, decision]);
    setIndex((current) => current + 1);
  }

  function restart() {
    setDecisions([]);
    setIndex(0);
  }

  // Fără cărți (API căzut sau catalog gol) secțiunea dispare - o demonstrație
  // goală ar spune exact opusul a ce vrea să spună.
  if (listings.isError || (!listings.isPending && books.length === 0)) return null;

  const card = books[index];
  const done = !listings.isPending && !card;

  return (
    <section className="mt-14 rounded-[16px] border border-border bg-card p-6 min-[900px]:p-8">
      <div className="grid gap-8 min-[900px]:grid-cols-[1fr_380px] min-[900px]:items-start">
        <div>
          <h2 className="font-display text-2xl font-bold">
            {t('landingMatchDemoTitle', 'Încearcă Book Match')}
          </h2>
          <p className="mt-3 max-w-[60ch] text-muted-foreground">
            {t(
              'landingMatchDemoText',
              'Îți arătăm {count} cărți. Spui „da", „nu" sau „sari peste", iar la final vezi ce fel de cititor ești. În aplicație, fiecare „da" ajunge direct în lista ta de dorințe.',
              { count: DEMO_SIZE },
            )}
          </p>
          {done && <DemoResults books={books} decisions={decisions} onRestart={restart} />}
        </div>

        {listings.isPending ? (
          <div className="flex min-h-[420px] items-center justify-center text-accent">
            <Spinner size={28} />
          </div>
        ) : card ? (
          <div className="mx-auto w-full max-w-[340px]">
            <article className="overflow-hidden rounded-[16px] border border-border bg-background">
              <div className="relative mx-auto aspect-[5/7] max-h-[340px] bg-muted">
                <BookCover url={card.coverUrl} title={card.title} eager />
              </div>
              <div className="p-4">
                <h3 className="line-clamp-2 font-display text-lg font-bold leading-tight">
                  {card.title}
                </h3>
                {card.author && (
                  <p className="mt-1 truncate text-sm text-muted-foreground">{card.author}</p>
                )}
              </div>
            </article>

            <div className="mt-4 flex items-center justify-center gap-4">
              <DemoButton
                onClick={() => decide('NO')}
                label={t('bookMatchNoLabel', 'Nu')}
                tone="border-destructive text-destructive"
              >
                <X size={24} />
              </DemoButton>
              <DemoButton
                onClick={() => decide('SKIP')}
                label={t('bookMatchSkip', 'Sari peste')}
                tone="border-border text-muted-foreground"
              >
                <SkipForward size={18} />
              </DemoButton>
              <DemoButton
                onClick={() => decide('YES')}
                label={t('bookMatchYesLabel', 'Da')}
                tone="border-success text-success"
              >
                <Heart size={24} />
              </DemoButton>
            </div>

            {/* Bara de progres: 20 de cărți e mult fără să vezi cât mai ai. */}
            <div className="mt-4 h-1.5 overflow-hidden rounded-full bg-muted">
              <div
                className="h-full rounded-full bg-accent transition-all"
                style={{ width: `${(index / books.length) * 100}%` }}
              />
            </div>
            <p className="mt-2 text-center text-xs text-muted-foreground">
              {index + 1} / {books.length}
            </p>
          </div>
        ) : null}
      </div>
    </section>
  );
}

/**
 * Rezumatul de la final: câte „da"/„nu"/„sari", un grafic cu genurile care
 * i-au plăcut și autorii preferați.
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
    <div className="mt-6">
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

function DemoButton({
  onClick,
  label,
  tone,
  children,
}: {
  onClick: () => void;
  label: string;
  tone: string;
  children: React.ReactNode;
}) {
  return (
    <button
      onClick={onClick}
      aria-label={label}
      title={label}
      className={`flex size-14 items-center justify-center rounded-full border-2 bg-card transition hover:scale-105 ${tone}`}
    >
      {children}
    </button>
  );
}
