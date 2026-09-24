import { useQuery } from '@tanstack/react-query';
import { Link } from 'react-router-dom';
import { useTranslation } from 'react-i18next';
import { ScreenHeader } from '@/components/layout/ScreenHeader';
import { profileKeys, profileRepository, type ActivityEntry } from './profileRepository';
import { BookCover } from '@/components/ui/BookCover';
import { Avatar } from '@/components/ui/Avatar';
import { ErrorNotice, Spinner } from '@/components/ui';
import { formatRelativeTime } from '@/lib/utils/time';

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

        {entry.type === 'reading_progress' && entry.currentPage !== undefined && (
          <p className="mt-1 text-xs text-muted-foreground">
            {entry.totalPages
              ? t('bookshelfProgressLabel', {
                  current: entry.currentPage,
                  total: entry.totalPages,
                })
              : t('bookshelfProgressLabelNoTotal', { current: entry.currentPage })}
          </p>
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
      // Textul complet („X a schimbat A cu B, de la Y") are nevoie de ambele
      // cărți. Fără cartea oferită - schimb cu bani, nu carte-pe-carte - cade
      // pe formularea scurtă.
      return entry.offeredBookTitle && entry.counterpartyName
        ? t('activitySwapCaption', {
            name: entry.userName ?? '',
            bookA: entry.offeredBookTitle,
            bookB: entry.bookTitle,
            counterparty: entry.counterpartyName,
          })
        : t('activityCompletedExchange');
  }
}
