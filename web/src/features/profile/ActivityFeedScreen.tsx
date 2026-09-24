import { Fragment, type ReactNode } from 'react';
import { useQuery } from '@tanstack/react-query';
import { Link } from 'react-router-dom';
import { useTranslation } from 'react-i18next';
import { ArrowLeftRight } from 'lucide-react';
import { ScreenHeader } from '@/components/layout/ScreenHeader';
import { profileKeys, profileRepository, type ActivityEntry } from './profileRepository';
import { BookCover } from '@/components/ui/BookCover';
import { Avatar } from '@/components/ui/Avatar';
import { ErrorNotice, Spinner } from '@/components/ui';
import { formatRelativeTime } from '@/lib/utils/time';
import { useAuth } from '@/features/auth/AuthProvider';

const BADGE_KEYS: Record<ActivityEntry['type'], string> = {
  new_listing: 'activityBadgeNew',
  finished_book: 'activityBadgeFinished',
  completed_exchange: 'activityBadgeExchange',
  sale: 'activityBadgeSale',
  reading_progress: 'activityBadgeProgress',
};

export function ActivityFeedScreen() {
  const { t, i18n } = useTranslation();

  const feed = useQuery({
    queryKey: profileKeys.activityFeed(),
    queryFn: ({ signal }) => profileRepository.activityFeed(signal),
  });

  const header = <ScreenHeader title={t('activityFeedTitle')} />;

  if (feed.isPending) {
    return (
      <div className="flex min-h-dvh items-center justify-center text-accent">
        {header}
        <Spinner size={28} />
      </div>
    );
  }

  if (feed.isError) {
    return (
      <div className="mx-auto max-w-2xl p-6">
        {header}
        <ErrorNotice message={t('activityFeedLoadError')} onRetry={() => void feed.refetch()} />
      </div>
    );
  }

  return (
    <div className="mx-auto w-full max-w-[680px] px-5 pb-16 pt-2 min-[900px]:px-8">
      {header}
      {feed.data.length === 0 ? (
        <p className="py-16 text-center text-muted-foreground">{t('activityFeedEmpty')}</p>
      ) : (
        <ul className="flex flex-col gap-3">
          {feed.data.map((entry, index) => (
            // Fluxul n-are id-uri proprii (evenimentele vin din patru tabele
            // diferite, agregate la citire), deci cheia e compusă din ce îl
            // identifică unic: cine, ce carte, când.
            <li key={`${entry.type}-${entry.userId}-${entry.date}-${index}`}>
              <ActivityRow entry={entry} locale={i18n.language} />
            </li>
          ))}
        </ul>
      )}
    </div>
  );
}

function ActivityRow({ entry, locale }: { entry: ActivityEntry; locale: string }) {
  const { t } = useTranslation();
  const name = entry.userName ?? t('commonUnknownUser');

  if (entry.type === 'completed_exchange') {
    return <ExchangeRow entry={entry} locale={locale} />;
  }

  return (
    <div className="flex gap-3 rounded-[16px] border border-border bg-card p-3">
      <div className="h-[72px] w-[52px] shrink-0 overflow-hidden rounded-lg bg-muted">
        <BookCover url={entry.bookCoverUrl} title={entry.bookTitle} />
      </div>

      <div className="min-w-0 flex-1">
        <div className="flex items-center gap-2">
          <Link to={`/users/${entry.userId}`} className="flex min-w-0 items-center gap-2">
            <Avatar src={entry.userAvatar} name={name} size={20} />
            <span className="truncate text-sm font-semibold hover:underline">{name}</span>
          </Link>
          <span className="shrink-0 rounded-full border border-border px-2 py-0.5 text-[11px] text-muted-foreground">
            {t(BADGE_KEYS[entry.type])}
          </span>
        </div>

        <p className="mt-1 text-sm text-muted-foreground">
          <ActivityDescription entry={entry} />
        </p>
        <p className="truncate font-medium">{entry.bookTitle}</p>
        {entry.bookAuthor && (
          <p className="truncate text-sm text-muted-foreground">{entry.bookAuthor}</p>
        )}

        {entry.type === 'new_listing' && entry.caption && (
          <p className="mt-1 line-clamp-2 text-sm italic text-muted-foreground">„{entry.caption}”</p>
        )}

        {entry.type === 'reading_progress' && entry.currentPage !== undefined && (
          <ReadingProgressBar current={entry.currentPage} total={entry.totalPages ?? null} />
        )}

        <p className="mt-1 text-xs text-muted-foreground">
          {formatRelativeTime(entry.date, locale)}
        </p>
      </div>
    </div>
  );
}

function ActivityDescription({ entry }: { entry: ActivityEntry }) {
  const { t } = useTranslation();

  switch (entry.type) {
    case 'new_listing':
      return t('activityNewListing');
    case 'finished_book':
      return t('activityFinishedBook');
    case 'sale':
      // `amount` vine deja ca number de la server (Number(sale.amount)), deci
      // nu mai trece prin conversia pentru Decimal.
      return t('activitySale', { amount: entry.amount ?? 0 });
    case 'reading_progress':
      return t('activityReadingProgress');
    case 'completed_exchange':
      // Randat de ExchangeRow; ramura rămâne doar ca switch-ul să fie complet.
      return t('activityCompletedExchange');
  }
}

/**
 * Un schimb finalizat de cineva urmărit, ca o singură propoziție: „Andrada
 * [Schimb] Jane Eyre pe Solenoid cu Alina Dumitru". Partenerul e link spre
 * profil, sau „tine" când e chiar cel care citește. La un schimb fără carte
 * oferită, propoziția spune doar ce a primit / ce a dat.
 */
function ExchangeRow({ entry, locale }: { entry: ActivityEntry; locale: string }) {
  const { t } = useTranslation();
  const { user } = useAuth();
  const name = entry.userName ?? t('commonUnknownUser');
  const counterpartyName = entry.counterpartyName ?? t('commonUnknownUser');
  const withViewer = !!user && entry.counterpartyId === user.id;

  const given = entry.givenBookTitle
    ? { title: entry.givenBookTitle, cover: entry.givenBookCoverUrl ?? null }
    : null;
  const received = entry.receivedBookTitle
    ? { title: entry.receivedBookTitle, cover: entry.receivedBookCoverUrl ?? null }
    : null;
  // Fără câmpurile orientate (backend vechi) rămâne coperta cărții principale.
  const covers =
    given || received
      ? [given, received].filter((b): b is { title: string; cover: string | null } => !!b)
      : [{ title: entry.bookTitle, cover: entry.bookCoverUrl }];

  const you = withViewer ? 'You' : '';
  const [key, values] =
    given && received
      ? [`activityExchangeSwap${you}`, { given: SLOT.given, received: SLOT.received }]
      : received
        ? [`activityExchangeGot${you}`, { book: SLOT.received }]
        : given
          ? [`activityExchangeGave${you}`, { book: SLOT.given }]
          : [`activityExchangeWith${you}`, {}];

  const slots: Record<string, ReactNode> = {
    given: <strong className="font-semibold text-foreground">{given?.title}</strong>,
    received: <strong className="font-semibold text-foreground">{received?.title}</strong>,
    counterparty: entry.counterpartyId ? (
      <Link
        to={`/users/${entry.counterpartyId}`}
        className="inline-flex items-center gap-1 align-middle font-semibold text-foreground hover:underline"
      >
        <Avatar src={entry.counterpartyAvatar} name={counterpartyName} size={18} />
        {counterpartyName}
      </Link>
    ) : (
      <strong className="font-semibold text-foreground">{counterpartyName}</strong>
    ),
  };
  const sentence = fillSlots(t(key, { ...values, counterparty: SLOT.counterparty }), slots);

  return (
    <div className="flex gap-3 rounded-[16px] border border-border bg-card p-3">
      <div className="flex shrink-0 items-center gap-1">
        {covers.map((book, i) => (
          <div key={i} className="flex items-center gap-1">
            {i === 1 && <ArrowLeftRight size={14} className="text-muted-foreground" aria-hidden />}
            <div className="h-[72px] w-[52px] overflow-hidden rounded-lg bg-muted">
              <BookCover url={book.cover} title={book.title} />
            </div>
          </div>
        ))}
      </div>

      <div className="min-w-0 flex-1">
        <p className="text-sm leading-6 text-muted-foreground">
          <Link
            to={`/users/${entry.userId}`}
            className="mr-1.5 inline-flex items-center gap-1.5 align-middle font-semibold text-foreground hover:underline"
          >
            <Avatar src={entry.userAvatar} name={name} size={20} />
            {name}
          </Link>
          <span className="mr-1.5 inline-block rounded-full border border-border px-2 align-middle text-[11px] leading-5">
            {t('activityBadgeExchange')}
          </span>
          {sentence}
        </p>
        <p className="mt-1 text-xs text-muted-foreground">
          {formatRelativeTime(entry.date, locale)}
        </p>
      </div>
    </div>
  );
}

/**
 * Marcaje puse în locul variabilelor la traducere, ca propoziția să poată fi
 * tăiată apoi în bucăți și variabilele înlocuite cu JSX (titluri îngroșate,
 * link spre profil). Ordinea lor diferă de la o limbă la alta, deci nu putem
 * lipi bucăți fixe de text în cod.
 */
const SLOT = {
  given: '[[given]]',
  received: '[[received]]',
  counterparty: '[[counterparty]]',
};

function fillSlots(text: string, slots: Record<string, ReactNode>) {
  return text.split(/\[\[(\w+)\]\]/).map((part, i) =>
    // split cu grup de captură: pozițiile impare sunt numele marcajelor.
    i % 2 === 1 ? <Fragment key={i}>{slots[part]}</Fragment> : part,
  );
}

/** Cât a citit, ca bară plus „pagina X din Y · 47%". Fără total, doar pagina. */
function ReadingProgressBar({ current, total }: { current: number; total: number | null }) {
  const { t } = useTranslation();
  const percent = total ? Math.min(100, Math.round((current / total) * 100)) : null;

  return (
    <div className="mt-1.5">
      {percent !== null && (
        <div
          className="h-1.5 w-full max-w-[260px] overflow-hidden rounded-full bg-muted"
          role="progressbar"
          aria-valuenow={percent}
          aria-valuemin={0}
          aria-valuemax={100}
        >
          <div className="h-full rounded-full bg-accent" style={{ width: `${percent}%` }} />
        </div>
      )}
      <p className="mt-1 text-xs text-muted-foreground">
        {total
          ? t('bookshelfProgressLabel', { current, total })
          : t('bookshelfProgressLabelNoTotal', { current })}
        {percent !== null && ` · ${percent}%`}
      </p>
    </div>
  );
}
