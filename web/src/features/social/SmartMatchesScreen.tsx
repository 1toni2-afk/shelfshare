import { useState, type CSSProperties } from 'react';
import { useQuery } from '@tanstack/react-query';
import { Link } from 'react-router-dom';
import { useTranslation } from 'react-i18next';
import { ScreenHeader } from '@/components/layout/ScreenHeader';
import { ArrowLeftRight, ArrowUpDown, Check, MapPin } from 'lucide-react';
import { socialKeys, statsRepository, type SmartMatch, type SmartMatchBook } from './socialRepository';
import { BookCover } from '@/components/ui/BookCover';
import { Avatar } from '@/components/ui/Avatar';
import { Button, ErrorNotice, Spinner } from '@/components/ui';
import { RequestExchangeSheet } from '@/features/books/BookActionSheets';
import { cn } from '@/lib/utils/cn';

/**
 * Câte coperți arată o parte a schimbului înainte de pastila „+N". Peste atât
 * cardul ar crește pe orizontală până iese din coloană pe telefon.
 */
const MAX_VISIBLE_COVERS = 3;

/**
 * Lățimea copertelor, aceeași pe ambele părți ale unui card: altfel, pe două
 * coloane, coperțile de înălțimi diferite nu se mai aliniază. Unu la unu
 * primește coperți mai mari - e cazul obișnuit și e tot schimbul.
 */
const COVER_WIDTH_ONE_FOR_ONE = 96;
const COVER_WIDTH = 76;
/**
 * Textul de sub o copertă singură poate ieși puțin în lateral: la 76px un
 * autor ca „Patrick Rothfuss" s-ar tăia. Trei coperți + „+N" (3×76 + 40 +
 * spații) încap în jumătatea de card de la 560px și pe telefon.
 */
const SINGLE_TEXT_WIDTH = 128;

/**
 * Potriviri: useri care au o carte pe care o vreau ȘI vor o carte pe care o
 * am. Fiecare card e un „deal" - ce primești ⇄ ce poți oferi - nu două liste
 * paralele, ca schimbul concret să se vadă dintr-o privire.
 */
export function SmartMatchesScreen() {
  const { t } = useTranslation();

  const matches = useQuery({
    queryKey: socialKeys.smartMatches(),
    queryFn: ({ signal }) => statsRepository.smartMatches(signal),
  });

  const header = <ScreenHeader title={t('smartMatchesTitle')} back />;

  if (matches.isPending) {
    return (
      <div className="flex min-h-dvh items-center justify-center text-accent">
        {header}
        <Spinner size={28} />
      </div>
    );
  }

  if (matches.isError) {
    return (
      <div className="mx-auto max-w-2xl p-6">
        {header}
        <ErrorNotice
          message={t('smartMatchesLoadError')}
          onRetry={() => void matches.refetch()}
        />
      </div>
    );
  }

  return (
    <div className="mx-auto w-full max-w-[760px] px-4 pb-16 pt-2 min-[900px]:px-8">
      {header}
      {matches.data.length === 0 ? (
        <p className="py-16 text-center text-muted-foreground">{t('smartMatchesEmpty')}</p>
      ) : (
        <ul className="flex flex-col gap-4">
          {matches.data.map((match) => (
            <MatchCard key={match.owner.id} match={match} />
          ))}
        </ul>
      )}
    </div>
  );
}

function MatchCard({ match }: { match: SmartMatch }) {
  const { t } = useTranslation();
  const [proposing, setProposing] = useState(false);

  const name = match.owner.name ?? match.owner.username ?? t('commonUnknownUser');
  // Cererea de schimb pornește de la o carte a LUI; dacă are mai multe din
  // lista ta, prima e cea afișată prima - restul se pot cere din pagina lor.
  const requested = match.theirBooks[0];
  const offered = match.myBooksTheyWant[0];
  const oneForOne = match.theirBooks.length === 1 && match.myBooksTheyWant.length === 1;
  const coverWidth = oneForOne ? COVER_WIDTH_ONE_FOR_ONE : COVER_WIDTH;
  // Eticheta (18px) + rândul de hint rezervat (18px) + spațiul de sub ele (10px),
  // apoi jumătate de copertă 2:3, minus jumătate din cercul de 40px.
  const labelBlock = oneForOne ? 18 + 10 : 18 + 18 + 10;
  const arrowTop = labelBlock + (coverWidth * 1.5) / 2 - 20;

  return (
    <li className="rounded-[16px] border border-border bg-card p-4 min-[560px]:p-5">
      <div className="mb-4 flex items-center gap-3">
        <Link
          to={`/users/${match.owner.id}`}
          className="flex min-w-0 flex-1 items-center gap-3 hover:underline"
        >
          <Avatar src={match.owner.profileImage} name={name} size={44} />
          <div className="min-w-0">
            <p className="truncate font-semibold">{name}</p>
            {match.owner.city && (
              <p className="flex items-center gap-1 truncate text-sm text-muted-foreground">
                <MapPin size={13} className="shrink-0" />
                {match.owner.city}
              </p>
            )}
          </div>
        </Link>
        <span className="flex shrink-0 items-center gap-1 rounded-full bg-accent/10 px-2.5 py-1 text-xs font-semibold text-accent">
          <Check size={13} strokeWidth={3} />
          <span className="hidden min-[400px]:inline">{t('smartMatchesBadge')}</span>
        </span>
      </div>

      {/* Unu la unu încape pe orizontală și pe telefon. Doar când o parte are
          mai multe cărți, sub 560px cele două părți trec una sub alta, cu
          săgeata verticală între ele. Săgeata portocalie rămâne la mijloc în
          ambele variante - ea explică de ce vezi acest user. */}
      <div
        className={cn(
          'grid grid-cols-[1fr_auto_1fr] items-start gap-2',
          !oneForOne && 'max-[559px]:flex max-[559px]:flex-col max-[559px]:items-center max-[559px]:gap-3',
        )}
      >
        <DealSide
          label={t('smartMatchesYouGet')}
          books={match.theirBooks}
          coverWidth={coverWidth}
          reserveHint={!oneForOne}
        />
        {/* Pe două coloane săgeata stă la mijlocul COPERȚILOR, nu al coloanei:
            un titlu pe două rânduri ar coborî-o altfel sub ele. */}
        <div
          style={{ '--arrow-top': `${arrowTop}px` } as CSSProperties}
          className={cn(
            'flex size-10 shrink-0 items-center justify-center rounded-full bg-accent/10 text-accent',
            oneForOne ? 'mt-[var(--arrow-top)]' : 'self-center min-[560px]:mt-[var(--arrow-top)] min-[560px]:self-start',
          )}
        >
          {oneForOne ? (
            <ArrowLeftRight size={20} />
          ) : (
            <>
              <ArrowUpDown size={20} className="min-[560px]:hidden" />
              <ArrowLeftRight size={20} className="hidden min-[560px]:block" />
            </>
          )}
        </div>
        <DealSide
          label={t('smartMatchesYouGive')}
          hint={match.myBooksTheyWant.length > 1 ? t('smartMatchesTheyPickOne', { name }) : undefined}
          books={match.myBooksTheyWant}
          coverWidth={coverWidth}
          reserveHint={!oneForOne}
        />
      </div>

      {requested && (
        <Button
          variant="outline"
          fullWidth
          onClick={() => setProposing(true)}
          className="mt-4 border-accent/50 py-3 text-accent hover:bg-accent/10"
        >
          <ArrowLeftRight size={17} />
          {t('smartMatchesPropose')}
        </Button>
      )}

      {proposing && requested && (
        <RequestExchangeSheet
          book={{ id: requested.userBookId, book: { title: requested.title } }}
          initialOfferedBookId={offered?.userBookId ?? null}
          onClose={() => setProposing(false)}
        />
      )}
    </li>
  );
}

function DealSide({
  label,
  hint,
  books,
  coverWidth,
  reserveHint,
}: {
  label: string;
  hint?: string;
  books: SmartMatchBook[];
  coverWidth: number;
  /** Pe două coloane, rândul gol ține coperțile celor două părți la aceeași înălțime. */
  reserveHint: boolean;
}) {
  const visible = books.slice(0, MAX_VISIBLE_COVERS);
  const hidden = books.length - visible.length;
  const single = books.length === 1;

  return (
    <div className="flex min-w-0 flex-col items-center">
      <div className="mb-2.5 flex flex-col items-center text-center">
        <p className="text-xs font-semibold uppercase leading-[18px] tracking-wider text-muted-foreground">{label}</p>
        {(hint || reserveHint) && (
          <p
            className={cn(
              'text-xs leading-[18px] text-muted-foreground min-[560px]:min-h-[18px]',
              !hint && 'max-[559px]:hidden',
            )}
          >
            {hint}
          </p>
        )}
      </div>
      <div className="flex items-start justify-center gap-1.5">
        {visible.map((item) => (
          <Link
            key={item.userBookId}
            to={`/books/${item.userBookId}`}
            style={{ width: single ? Math.max(coverWidth, SINGLE_TEXT_WIDTH) : coverWidth }}
            className="group shrink-0 text-center"
          >
            <div
              style={{ width: coverWidth }}
              className="mx-auto aspect-[2/3] overflow-hidden rounded-[10px] bg-muted shadow-sm transition group-hover:brightness-110"
            >
              <BookCover url={item.coverUrl} title={item.title} />
            </div>
            <p className="mt-1.5 line-clamp-2 text-[13px] font-semibold leading-tight">{item.title}</p>
            {single && item.author && (
              <p className="mt-0.5 truncate text-xs text-muted-foreground">{item.author}</p>
            )}
          </Link>
        ))}
        {hidden > 0 && (
          <div
            style={{ height: coverWidth * 1.5 }}
            className="flex w-10 shrink-0 items-center justify-center rounded-[10px] bg-muted text-sm font-semibold text-muted-foreground"
          >
            +{hidden}
          </div>
        )}
      </div>
    </div>
  );
}
