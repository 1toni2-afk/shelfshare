import { useQuery } from '@tanstack/react-query';
import { Link } from 'react-router-dom';
import { useTranslation } from 'react-i18next';
import { ScreenHeader } from '@/components/layout/ScreenHeader';
import { followRepository, profileKeys } from './profileRepository';
import { Avatar } from '@/components/ui/Avatar';
import { ErrorNotice, Spinner } from '@/components/ui';

/** Lista celor urmăriți („vânzători favoriți"). Port al following_screen.dart. */
export function FollowingScreen() {
  const { t } = useTranslation();

  const following = useQuery({
    queryKey: profileKeys.following(),
    queryFn: ({ signal }) => followRepository.following(signal),
  });

  const header = <ScreenHeader title={t('favoriteSellersTitle')} back />;

  if (following.isPending) {
    return (
      <div className="flex min-h-dvh items-center justify-center text-accent">
        {header}
        <Spinner size={28} />
      </div>
    );
  }

  if (following.isError) {
    return (
      <div className="mx-auto max-w-2xl p-6">
        {header}
        <ErrorNotice
          message={t('favoriteSellersLoadError')}
          onRetry={() => void following.refetch()}
        />
      </div>
    );
  }

  return (
    <div className="mx-auto w-full max-w-[680px] px-5 pb-16 pt-2 min-[900px]:px-8">
      {header}
      {following.data.length === 0 ? (
        <p className="py-16 text-center text-muted-foreground">{t('favoriteSellersEmpty')}</p>
      ) : (
        <ul className="flex flex-col gap-2">
          {following.data.map((person) => {
            const name = person.name ?? person.username ?? t('commonUnknownUser');
            return (
              <li key={person.id}>
                <Link
                  to={`/users/${person.id}`}
                  className="flex items-center gap-3 rounded-[16px] border border-border bg-card p-3 hover:bg-muted"
                >
                  <Avatar src={person.profileImage} name={name} size={44} />
                  <div className="min-w-0 flex-1">
                    <p className="truncate font-semibold">{name}</p>
                    {person.city && (
                      <p className="truncate text-sm text-muted-foreground">{person.city}</p>
                    )}
                  </div>
                </Link>
              </li>
            );
          })}
        </ul>
      )}
    </div>
  );
}
