import { useState } from 'react';
import { useQuery } from '@tanstack/react-query';
import { Link } from 'react-router-dom';
import { useTranslation } from 'react-i18next';
import { HeaderTabs, ScreenHeader } from '@/components/layout/ScreenHeader';
import { booksKeys, booksRepository } from '@/features/books/booksRepository';
import { socialKeys, statsRepository } from './socialRepository';
import { BookCover } from '@/components/ui/BookCover';
import { ErrorNotice, Spinner } from '@/components/ui';
import { cn } from '@/lib/utils/cn';

type Tab = 'mostShared' | 'trending' | 'popularAuthors';

export function GlobalStatsScreen() {
  const { t } = useTranslation();
  const [tab, setTab] = useState<Tab>('mostShared');

  const books = useQuery({
    queryKey: tab === 'mostShared' ? socialKeys.mostShared() : socialKeys.trending(),
    queryFn: ({ signal }) =>
      tab === 'mostShared'
        ? statsRepository.mostShared(signal)
        : statsRepository.trending(signal),
    enabled: tab !== 'popularAuthors',
  });

  const authors = useQuery({
    queryKey: booksKeys.popularAuthors(),
    queryFn: ({ signal }) => booksRepository.getPopularAuthors(signal),
    enabled: tab === 'popularAuthors',
  });

  const pending = tab === 'popularAuthors' ? authors.isPending : books.isPending;
  const failed = tab === 'popularAuthors' ? authors.isError : books.isError;

  const header = (
    <ScreenHeader
      title={t('globalStatsTitle')}
      back
      bottom={
        <HeaderTabs
          value={tab}
          onChange={setTab}
          tabs={[
            { value: 'mostShared' as const, label: t('globalStatsTabMostShared') },
            { value: 'trending' as const, label: t('globalStatsTabTrending') },
            { value: 'popularAuthors' as const, label: t('globalStatsTabPopularAuthors') },
          ]}
        />
      }
    />
  );

  return (
    <div className="mx-auto w-full max-w-[680px] px-5 pb-16 pt-2 min-[900px]:px-8">
      {header}
      {pending ? (
        <div className="flex h-40 items-center justify-center text-accent">
          <Spinner size={26} />
        </div>
      ) : failed ? (
        <ErrorNotice
          message={t('globalStatsLoadError')}
          onRetry={() =>
            void (tab === 'popularAuthors' ? authors.refetch() : books.refetch())
          }
        />
      ) : tab === 'popularAuthors' ? (
        (authors.data ?? []).length === 0 ? (
          <p className="py-16 text-center text-muted-foreground">{t('globalStatsEmpty')}</p>
        ) : (
          <ol className="flex flex-col gap-2">
            {authors.data?.map((stat, index) => (
              <li
                key={stat.author}
                className="flex items-center gap-3 rounded-[16px] border border-border bg-card p-3"
              >
                <Rank index={index} />
                <Link
                  to={`/browse?author=${encodeURIComponent(stat.author)}`}
                  className="min-w-0 flex-1 truncate font-semibold hover:underline"
                >
                  {stat.author}
                </Link>
                <span className="shrink-0 text-sm text-muted-foreground">{stat.count}</span>
              </li>
            ))}
          </ol>
        )
      ) : (books.data ?? []).length === 0 ? (
        <p className="py-16 text-center text-muted-foreground">{t('globalStatsEmpty')}</p>
      ) : (
        <ol className="flex flex-col gap-2">
          {books.data?.map((entry, index) => (
            <li
              key={entry.book.id}
              className="flex items-center gap-3 rounded-[16px] border border-border bg-card p-3"
            >
              <Rank index={index} />
              <div className="h-[60px] w-[44px] shrink-0 overflow-hidden rounded-lg bg-muted">
                <BookCover url={entry.book.coverUrl} title={entry.book.title} />
              </div>
              <Link to={`/work/${entry.book.id}`} className="min-w-0 flex-1">
                <p className="truncate font-semibold hover:underline">{entry.book.title}</p>
                {entry.book.author && (
                  <p className="truncate text-sm text-muted-foreground">{entry.book.author}</p>
                )}
              </Link>
              <span className="shrink-0 text-sm text-muted-foreground">
                {t(tab === 'mostShared' ? 'globalStatsTransferCount' : 'globalStatsViewCount', {
                  count: entry.count,
                })}
              </span>
            </li>
          ))}
        </ol>
      )}
    </div>
  );
}

function Rank({ index }: { index: number }) {
  return (
    <span
      className={cn(
        'w-7 shrink-0 text-center font-display text-lg font-bold',
        index < 3 ? 'text-accent' : 'text-muted-foreground',
      )}
    >
      {index + 1}
    </span>
  );
}
