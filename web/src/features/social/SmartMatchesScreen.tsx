import { useQuery } from '@tanstack/react-query';
import { Link } from 'react-router-dom';
import { useTranslation } from 'react-i18next';
import { ScreenHeader } from '@/components/layout/ScreenHeader';
import { ArrowLeftRight } from 'lucide-react';
import { socialKeys, statsRepository, type SmartMatchBook } from './socialRepository';
import { BookCover } from '@/components/ui/BookCover';
import { Avatar } from '@/components/ui/Avatar';
import { ErrorNotice, Spinner } from '@/components/ui';

/**
 * Potriviri de schimb: useri care au o carte pe care o vreau ȘI vor o carte pe
 * care o am. Port al smart_matches_screen.dart.
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
    <div className="mx-auto w-full max-w-[760px] px-5 pb-16 pt-2 min-[900px]:px-8">
      {header}
      {matches.data.length === 0 ? (
        <p className="py-16 text-center text-muted-foreground">{t('smartMatchesEmpty')}</p>
      ) : (
        <ul className="flex flex-col gap-4">
          {matches.data.map((match) => {
            const name = match.owner.name ?? match.owner.username ?? t('commonUnknownUser');
            return (
              <li key={match.owner.id} className="rounded-[16px] border border-border bg-card p-4">
                <Link
                  to={`/users/${match.owner.id}`}
                  className="mb-4 flex items-center gap-3 hover:underline"
                >
                  <Avatar src={match.owner.profileImage} name={name} size={40} />
                  <div className="min-w-0">
                    <p className="truncate font-semibold">{name}</p>
                    {match.owner.city && (
                      <p className="truncate text-sm text-muted-foreground">{match.owner.city}</p>
                    )}
                  </div>
                </Link>

                {/* Cele două coloane sunt simetrice dinadins: potrivirea are
                    sens doar dacă se văd simultan ambele direcții. */}
                <div className="grid gap-4 min-[560px]:grid-cols-[1fr_auto_1fr] min-[560px]:items-center">
                  <BookStrip title={t('smartMatchesTheyHave')} books={match.theirBooks} />
                  <ArrowLeftRight
                    size={20}
                    className="mx-auto hidden shrink-0 text-muted-foreground min-[560px]:block"
                  />
                  <BookStrip title={t('smartMatchesTheyWant')} books={match.myBooksTheyWant} />
                </div>
              </li>
            );
          })}
        </ul>
      )}
    </div>
  );
}

function BookStrip({ title, books }: { title: string; books: SmartMatchBook[] }) {
  return (
    <div className="min-w-0">
      <p className="mb-2 text-xs font-semibold uppercase tracking-wider text-muted-foreground">
        {title}
      </p>
      <div className="flex gap-2 overflow-x-auto pb-1">
        {books.slice(0, 6).map((item) => (
          <Link
            key={item.userBookId}
            to={`/books/${item.userBookId}`}
            className="w-[52px] shrink-0"
          >
            <div className="aspect-[5/7] overflow-hidden rounded-lg bg-muted">
              <BookCover url={item.coverUrl} title={item.title} />
            </div>
          </Link>
        ))}
      </div>
    </div>
  );
}
