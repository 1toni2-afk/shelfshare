import { useState } from 'react';
import { useQuery } from '@tanstack/react-query';
import { Link } from 'react-router-dom';
import { useTranslation } from 'react-i18next';
import { ScreenHeader } from '@/components/layout/ScreenHeader';
import { FolderTabs } from '@/components/ui/FolderTabs';
import { profileKeys, profileRepository } from '@/features/profile/profileRepository';
import { Avatar } from '@/components/ui/Avatar';
import { ErrorNotice, Spinner } from '@/components/ui';
import { cn } from '@/lib/utils/cn';

type Tab = 'national' | 'city' | 'topReaders';

export function LeaderboardScreen() {
  const { t } = useTranslation();
  const [tab, setTab] = useState<Tab>('national');

  const board = useQuery({
    queryKey: profileKeys.leaderboard(tab),
    queryFn: ({ signal }) =>
      tab === 'national'
        ? profileRepository.leaderboardNational(signal)
        : tab === 'topReaders'
          ? profileRepository.topReaders(signal)
          : profileRepository.leaderboardCities(signal),
  });

  const header = <ScreenHeader title={t('profileLeaderboard')} back />;

  return (
    <div className="mx-auto w-full max-w-[680px] px-5 pb-16 pt-2 min-[900px]:px-8">
      {header}
      <FolderTabs
        label={t('profileLeaderboard')}
        value={tab}
        onChange={setTab}
        tabs={[
          { value: 'city' as const, label: t('leaderboardTabCity') },
          { value: 'national' as const, label: t('leaderboardTabNational') },
          { value: 'topReaders' as const, label: t('leaderboardTabTopReaders') },
        ]}
        className="mt-2"
      >
      {/* Filele rămân pe loc cât se încarcă sau pică un clasament - altfel
          sar din pagină la fiecare schimbare de filă. */}
      {board.isPending ? (
        <div className="flex h-40 items-center justify-center text-accent">
          <Spinner size={28} />
        </div>
      ) : board.isError ? (
        <ErrorNotice message={t('leaderboardLoadError')} onRetry={() => void board.refetch()} />
      ) : board.data.length === 0 ? (
        <p className="py-16 text-center text-muted-foreground">{t('leaderboardEmpty')}</p>
      ) : (
        <ol className="flex flex-col gap-2">
          {board.data.map((row, index) => (
            <li
              key={row.id}
              className="flex items-center gap-3 rounded-[16px] border border-border bg-card p-3"
            >
              {/* Primele trei locuri primesc culoarea de accent - restul rămân
                  neutre, ca podiumul să se vadă dintr-o privire. */}
              <span
                className={cn(
                  'w-7 shrink-0 text-center font-display text-lg font-bold',
                  index < 3 ? 'text-accent' : 'text-muted-foreground',
                )}
              >
                {index + 1}
              </span>

              <Avatar
                src={row.profileImage}
                name={row.name ?? row.username ?? ''}
                size={40}
              />
              <Link to={`/users/${row.id}`} className="min-w-0 flex-1">
                <p className="truncate font-semibold hover:underline">
                  {row.name ?? row.username ?? t('commonUnknownUser')}
                </p>
                <p className="truncate text-sm text-muted-foreground">
                  {row.city ?? t('leaderboardUnknownCity')}
                </p>
              </Link>
              {/*
                Metrica diferă de la un clasament la altul: pagini citite la
                „Cititori", schimburi la celelalte două. Câmpul lipsă e afișat
                ca 0, nu omis - un rând fără număr arăta ca un bug (exact ce
                s-a văzut la prima rulare, cu „schimburi" fără cifră).
              */}
              <span className="shrink-0 text-sm font-medium">
                {tab === 'topReaders'
                  ? t('leaderboardPagesCount', { count: row.totalPages ?? 0 })
                  : t('leaderboardExchangesCount', { count: row.booksExchangedCount ?? 0 })}
              </span>
            </li>
          ))}
        </ol>
      )}
      </FolderTabs>
    </div>
  );
}
