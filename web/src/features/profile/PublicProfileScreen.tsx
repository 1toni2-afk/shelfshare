import { useState } from 'react';
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { useNavigate, useParams } from 'react-router-dom';
import { useTranslation } from 'react-i18next';
import { HeaderAction, ScreenHeader } from '@/components/layout/ScreenHeader';
import { ProfileQrDialog } from '@/components/ui/ProfileQrDialog';
import { shareAppLink } from '@/lib/utils/shareLink';
import { MessageSquare, QrCode, Share2, Star, UserMinus, UserPlus } from 'lucide-react';
import { followRepository, profileKeys, profileRepository } from './profileRepository';
import { chatRepository } from '@/features/chat/chatRepository';
import { BookCard } from '@/features/books/BookCard';
import { BookGrid } from '@/features/books/BookGrid';
import { Avatar } from '@/components/ui/Avatar';
import { Button, ErrorNotice, Spinner } from '@/components/ui';
import { useToast } from '@/components/ui/Toast';
import { useAuth } from '@/features/auth/AuthProvider';
import { useDocumentMeta } from '@/lib/seo/useDocumentMeta';
import { profileTitle } from '@/lib/seo/routes';

export function PublicProfileScreen() {
  const { userId = '' } = useParams();
  const { t } = useTranslation();
  const { user } = useAuth();
  const navigate = useNavigate();
  const queryClient = useQueryClient();
  const toast = useToast();
  const [qrOpen, setQrOpen] = useState(false);

  const profile = useQuery({
    queryKey: profileKeys.public(userId),
    queryFn: ({ signal }) => profileRepository.publicProfile(userId, signal),
    enabled: !!userId,
  });

  const following = useQuery({
    queryKey: ['follow', userId],
    queryFn: ({ signal }) => followRepository.isFollowing(userId, signal),
    // Pe propriul profil n-are sens: backendul ar răspunde, dar butonul nici
    // nu se afișează. Fără cont, endpointul cere autentificare - cererea ar
    // pleca degeaba și ar întoarce 401 la fiecare deschidere a paginii, care
    // acum e publică.
    enabled: !!user && !!userId && userId !== user.id,
  });

  const toggleFollow = useMutation({
    mutationFn: (next: boolean) =>
      next ? followRepository.follow(userId) : followRepository.unfollow(userId),
    onSuccess: () => {
      void queryClient.invalidateQueries({ queryKey: ['follow', userId] });
      void queryClient.invalidateQueries({ queryKey: profileKeys.following() });
    },
    onError: () => toast.show(t('publicProfileFollowUpdateError'), 'danger'),
  });

  /*
    Structured data doar cu ce e deja vizibil pe pagină: numele, poza, orașul.
    Fără email, telefon sau orice se vede numai după autentificare - un
    `Person` marcat corect nu înseamnă un `Person` complet.
  */
  useDocumentMeta(
    profile.data
      ? {
          title: profileTitle(profile.data.name ?? profile.data.username ?? 'Cititor'),
          description:
            profile.data.bio ||
            `Profilul lui ${profile.data.name ?? profile.data.username} pe ShelfShare${
              profile.data.city ? ` (${profile.data.city})` : ''
            } - ${profile.data.listedBooks?.length ?? 0} cărți listate.`,
          path: `/users/${userId}`,
          image: profile.data.profileImage ?? undefined,
          jsonLd: {
            '@context': 'https://schema.org',
            '@type': 'Person',
            name: profile.data.name ?? profile.data.username,
            ...(profile.data.profileImage ? { image: profile.data.profileImage } : {}),
            ...(profile.data.city ? { address: { '@type': 'PostalAddress', addressLocality: profile.data.city } } : {}),
          },
        }
      : null,
  );

  const startChat = useMutation({
    mutationFn: () => chatRepository.startConversation(userId),
    // Endpointul e idempotent: dacă o conversație există deja, o întoarce pe
    // aceea în loc să creeze o a doua.
    onSuccess: (conversation) => void navigate(`/chat/${conversation.id}`),
    onError: () => toast.show(t('publicProfileMessageError'), 'danger'),
  });

  const header = (
    <ScreenHeader
      title={t('publicProfileTitle')}
      back
      actions={
        <>
        <HeaderAction
          label={t('profileQrTooltip')}
          onClick={() => setQrOpen(true)}
        >
          <QrCode size={22} />
        </HeaderAction>
        <HeaderAction
          label={t('profileCopyLink')}
          onClick={() => void shareAppLink(`/users/${userId}`, toast.show)}
        >
          <Share2 size={22} />
        </HeaderAction>
        </>
      }
    />
  );

  if (profile.isPending) {
    return (
      <div className="flex min-h-dvh items-center justify-center text-accent">
        {header}
        <Spinner size={28} />
      </div>
    );
  }

  if (profile.isError) {
    return (
      <div className="mx-auto max-w-2xl p-6">
        {header}
        <ErrorNotice message={t('profileLoadError')} onRetry={() => void profile.refetch()} />
      </div>
    );
  }

  const person = profile.data;
  const displayName = person.name ?? person.username ?? t('commonUnknownUser');
  const isMe = person.id === user?.id;
  const isFollowing = following.data?.following ?? false;

  return (
    <div className="mx-auto w-full max-w-[900px] px-5 pb-16 pt-2 min-[900px]:px-8">
      {header}
      <section className="rounded-[16px] border border-border bg-card p-5">
        <div className="flex flex-wrap items-center gap-4">
          <Avatar src={person.profileImage} name={displayName} size={80} />

          <div className="min-w-0 flex-1">
            <h1 className="truncate font-display text-xl font-bold">{displayName}</h1>
            {person.username && <p className="truncate text-muted-foreground">@{person.username}</p>}
            {person.city && <p className="truncate text-sm text-muted-foreground">{person.city}</p>}
            {person.rating > 0 && (
              <p className="mt-1 flex items-center gap-1 text-sm">
                <Star size={14} className="fill-warning text-warning" />
                {person.rating.toFixed(1)}
              </p>
            )}
          </div>

          {/* Butoanele nu apar pe propriul profil: nu te poți urmări sau scrie
              ție însuți, iar backendul ar refuza oricum.

              Pentru vizitatorul fără cont duc la autentificare, nu la o cerere
              care s-ar întoarce 401: pagina e publică, dar a urmări pe cineva
              și a-i scrie sunt acțiuni care cer un cont. */}
          {!user ? (
            <Button variant="primary" onClick={() => void navigate('/login')}>
              <UserPlus size={16} />
              {t('publicProfileFollow')}
            </Button>
          ) : (
            !isMe && (
            <div className="flex flex-wrap gap-2">
              <Button
                variant={isFollowing ? 'outline' : 'primary'}
                loading={toggleFollow.isPending}
                onClick={() => toggleFollow.mutate(!isFollowing)}
              >
                {isFollowing ? <UserMinus size={16} /> : <UserPlus size={16} />}
                {t(isFollowing ? 'publicProfileUnfollow' : 'publicProfileFollow')}
              </Button>

              <Button
                variant="outline"
                loading={startChat.isPending}
                onClick={() => startChat.mutate()}
              >
                <MessageSquare size={16} />
                {t('commonSendMessage')}
              </Button>
            </div>
            )
          )}
        </div>

        {person.bio && <p className="mt-4 whitespace-pre-line text-muted-foreground">{person.bio}</p>}

        <div className="mt-5 grid grid-cols-2 gap-3 border-t border-border pt-5 text-center min-[560px]:grid-cols-4">
          <Stat label={t('commonBooksExchanged')} value={person.booksExchangedCount} />
          <Stat label={t('publicProfileBooksShared')} value={person.booksSharedCount} />
          <Stat label={t('publicProfileBooksReceived')} value={person.booksReceivedCount} />
          <Stat
            label={t('publicProfileBooksListed')}
            value={person.listedBooks?.length ?? 0}
          />
        </div>

        {person.createdAt && (
          <p className="mt-4 text-center text-xs text-muted-foreground">
            {t('publicProfileMemberSince', {
              date: new Intl.DateTimeFormat(undefined, {
                month: 'long',
                year: 'numeric',
              }).format(new Date(person.createdAt)),
            })}
          </p>
        )}
      </section>

      {person.listedBooks && person.listedBooks.length > 0 && (
        <section className="mt-8">
          <h2 className="mb-4 font-display text-lg font-bold">
            {t('publicProfileListedBooksCount', { count: person.listedBooks.length })}
          </h2>
          <BookGrid>
            {person.listedBooks.map((item, index) => (
              <BookCard key={item.id} item={item} eager={index < 5} />
            ))}
          </BookGrid>
        </section>
      )}

      {qrOpen && <ProfileQrDialog userId={userId} onClose={() => setQrOpen(false)} />}
    </div>
  );
}

function Stat({ label, value }: { label: string; value: number }) {
  return (
    <div>
      <p className="font-display text-xl font-bold">{value}</p>
      <p className="text-xs text-muted-foreground">{label}</p>
    </div>
  );
}
