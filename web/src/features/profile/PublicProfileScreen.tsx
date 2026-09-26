import { useMemo, useRef, useState } from 'react';
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { useNavigate, useParams } from 'react-router-dom';
import { useTranslation } from 'react-i18next';
import { HeaderAction, ScreenHeader } from '@/components/layout/ScreenHeader';
import { ProfileQrDialog } from '@/components/ui/ProfileQrDialog';
import { shareAppLink } from '@/lib/utils/shareLink';
import {
  ArrowRight,
  BookOpen,
  CalendarDays,
  ChevronDown,
  MapPin,
  MessageSquare,
  QrCode,
  Repeat,
  Share2,
  Star,
  UserMinus,
  UserPlus,
  X,
} from 'lucide-react';
import {
  followRepository,
  profileKeys,
  profileRepository,
  type Compatibility,
  type PublicReview,
} from './profileRepository';
import { chatRepository } from '@/features/chat/chatRepository';
import { BookCard } from '@/features/books/BookCard';
import { BookGrid } from '@/features/books/BookGrid';
import { BookCover } from '@/components/ui/BookCover';
import { Avatar } from '@/components/ui/Avatar';
import { Button, ErrorNotice, Spinner } from '@/components/ui';
import { useToast } from '@/components/ui/Toast';
import { useAuth } from '@/features/auth/AuthProvider';
import { useDocumentMeta } from '@/lib/seo/useDocumentMeta';
import { profileTitle } from '@/lib/seo/routes';
import { cn } from '@/lib/utils/cn';
import { toNumber, type UserBook } from '@/types/models';
import { ProgressBar, readingFraction } from './ReadingProgress';

type Filter = 'all' | 'swap' | 'sale' | 'matches';
type Sort = 'newest' | 'oldest' | 'title';

/**
 * Profilul altui user. Scopul lui e diferit de al profilului propriu: cine
 * intră aici vrea să afle repede cine e omul, dacă e de încredere și, mai ales,
 * ce cărți poate lua de la el. De aceea headerul e scurt (rating, schimburi,
 * bio, genuri), urmat de „Tu & X" - potrivirile de wishlist - și de grila de
 * cărți, care domină pagina. Statisticile personale (cărți primite/date) nu
 * mai apar: nu ajută pe nimeni să decidă un schimb.
 */
export function PublicProfileScreen() {
  const { userId = '' } = useParams();
  const { t, i18n } = useTranslation();
  const { user } = useAuth();
  const navigate = useNavigate();
  const queryClient = useQueryClient();
  const toast = useToast();
  const [qrOpen, setQrOpen] = useState(false);
  const [reviewsOpen, setReviewsOpen] = useState(false);
  const [filter, setFilter] = useState<Filter>('all');
  const [sort, setSort] = useState<Sort>('newest');
  const booksSection = useRef<HTMLElement>(null);

  const profile = useQuery({
    queryKey: profileKeys.public(userId),
    queryFn: ({ signal }) => profileRepository.publicProfile(userId, signal),
    enabled: !!userId,
  });

  const isOther = !!user && !!userId && userId !== user.id;

  const following = useQuery({
    queryKey: ['follow', userId],
    queryFn: ({ signal }) => followRepository.isFollowing(userId, signal),
    // Pe propriul profil n-are sens: backendul ar răspunde, dar butonul nici
    // nu se afișează. Fără cont, endpointul cere autentificare - cererea ar
    // pleca degeaba și ar întoarce 401 la fiecare deschidere a paginii, care
    // acum e publică.
    enabled: isOther,
  });

  // Aceeași regulă: potrivirile se calculează față de wishlist-ul TĂU, deci
  // n-au sens nici fără cont, nici pe propriul profil.
  const compatibility = useQuery({
    queryKey: profileKeys.compatibility(userId),
    queryFn: ({ signal }) => profileRepository.compatibility(userId, signal),
    enabled: isOther,
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

  // `availableBooks` e lista completă (și vânzare/donație); `listedBooks`
  // rămâne doar ca rezervă pentru un backend care nu trimite încă noul câmp.
  const books = useMemo(
    () => profile.data?.availableBooks ?? profile.data?.listedBooks ?? [],
    [profile.data],
  );

  /*
    Structured data doar cu ce e deja vizibil pe pagină: numele, poza, orașul.
    Fără email, telefon sau orice se vede numai după autentificare - un
    `Person` marcat corect nu înseamnă un `Person` complet.
  */
  useDocumentMeta(
    profile.data
      ? {
          title: profileTitle(profile.data.name ?? profile.data.username ?? 'Cititor'),
          // Tradusă - vezi nota din GroupDetailScreen.
          description:
            profile.data.bio ||
            t('seoProfileDescription', {
              name: profile.data.name ?? profile.data.username,
              city: profile.data.city ? ` (${profile.data.city})` : '',
              count: books.length,
            }),
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
          <HeaderAction label={t('profileQrTooltip')} onClick={() => setQrOpen(true)}>
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

  const matchIds = useMemo(
    () => new Set((compatibility.data?.theirBooksYouWant ?? []).map((item) => item.id)),
    [compatibility.data],
  );

  const visibleBooks = useMemo(() => {
    const filtered = books.filter((item) => {
      if (filter === 'swap') return item.availableForSwap;
      if (filter === 'sale') return isForSale(item);
      if (filter === 'matches') return matchIds.has(item.id);
      return true;
    });
    return [...filtered].sort((a, b) => {
      if (sort === 'title') return a.book.title.localeCompare(b.book.title, i18n.language);
      const diff = new Date(a.createdAt).getTime() - new Date(b.createdAt).getTime();
      return sort === 'oldest' ? diff : -diff;
    });
  }, [books, filter, sort, matchIds, i18n.language]);

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
  const isFollowing = following.data?.isFollowing ?? false;
  const reviews = person.reviews ?? [];
  const genres = (person.readingStats?.topGenres ?? []).slice(0, 4);
  const current = person.currentlyReading ?? null;
  const memberSince = person.memberSince
    ? new Intl.DateTimeFormat(i18n.language, { month: 'short', year: 'numeric' }).format(
        new Date(person.memberSince),
      )
    : null;

  const swapCount = books.filter((item) => item.availableForSwap).length;
  const saleCount = books.filter(isForSale).length;
  const matchCount = books.filter((item) => matchIds.has(item.id)).length;

  const showMatches = () => {
    setFilter('matches');
    booksSection.current?.scrollIntoView({ behavior: 'smooth', block: 'start' });
  };

  /* Butoanele nu apar pe propriul profil: nu te poți urmări sau scrie ție
     însuți, iar backendul ar refuza oricum.

     Pentru vizitatorul fără cont duc la autentificare, nu la o cerere care
     s-ar întoarce 401: pagina e publică, dar a urmări pe cineva și a-i scrie
     sunt acțiuni care cer un cont. */
  const actions = !user ? (
    <div className="grid grid-cols-2 gap-2 lg:flex">
      <Button variant="primary" className="whitespace-nowrap px-3 py-3 text-sm" onClick={() => void navigate('/login')}>
        <UserPlus size={16} />
        {t('publicProfileFollow')}
      </Button>
      <Button variant="outline" className="whitespace-nowrap px-3 py-3 text-sm" onClick={() => void navigate('/login')}>
        <MessageSquare size={16} />
        {t('commonSendMessage')}
      </Button>
    </div>
  ) : (
    !isMe && (
      <div className="grid grid-cols-2 gap-2 lg:flex">
        <Button
          variant={isFollowing ? 'outline' : 'primary'}
          className="whitespace-nowrap px-3 py-3 text-sm"
          loading={toggleFollow.isPending}
          onClick={() => toggleFollow.mutate(!isFollowing)}
        >
          {isFollowing ? <UserMinus size={16} /> : <UserPlus size={16} />}
          {t(isFollowing ? 'publicProfileUnfollow' : 'publicProfileFollow')}
        </Button>
        <Button
          variant="outline"
          className="whitespace-nowrap px-3 py-3 text-sm"
          loading={startChat.isPending}
          onClick={() => startChat.mutate()}
        >
          <MessageSquare size={16} />
          {t('commonSendMessage')}
        </Button>
      </div>
    )
  );

  return (
    <div className="mx-auto w-full max-w-[1180px] px-4 pb-16 pt-2 sm:px-6 min-[900px]:px-8">
      {header}

      <section className="rounded-[18px] border border-border bg-card p-5 sm:p-6">
        <div className="flex flex-col gap-5 lg:flex-row lg:items-start">
          <div className="flex min-w-0 flex-1 items-start gap-4 sm:gap-6">
            <span className="sm:hidden">
              <Avatar src={person.profileImage} name={displayName} size={80} />
            </span>
            <span className="hidden sm:block">
              <Avatar src={person.profileImage} name={displayName} size={120} />
            </span>

            <div className="min-w-0 flex-1">
              <h1 className="truncate font-display text-2xl font-bold leading-tight sm:text-[32px]">
                {displayName}
              </h1>
              <p className="mt-0.5 truncate text-muted-foreground">
                {[person.username ? `@${person.username}` : null, person.city]
                  .filter(Boolean)
                  .join(' · ')}
              </p>

              <div className="mt-2 flex flex-wrap items-center gap-x-5 gap-y-1 text-sm">
                {person.rating > 0 &&
                  (reviews.length > 0 ? (
                    // Ratingul e un link spre recenzii: pentru o comunitate de
                    // schimburi, ce spun ceilalți cântărește mai mult decât cifra.
                    <button
                      onClick={() => setReviewsOpen(true)}
                      className="flex items-center gap-1.5 rounded-md hover:underline"
                    >
                      <Star size={16} className="fill-warning text-warning" />
                      <span className="font-semibold">{person.rating.toFixed(1)}</span>
                      <span className="text-muted-foreground">
                        ({t('publicProfileReviewsLink', { count: reviews.length })})
                      </span>
                    </button>
                  ) : (
                    // Notă fără text: „(0 recenzii)" lângă 5.0 ar părea o
                    // contradicție, iar un link spre o listă goală n-ajută.
                    <span className="flex items-center gap-1.5">
                      <Star size={16} className="fill-warning text-warning" />
                      <span className="font-semibold">{person.rating.toFixed(1)}</span>
                    </span>
                  ))}
                {person.booksExchangedCount > 0 && (
                  <span className="flex items-center gap-1.5">
                    <Repeat size={15} className="text-muted-foreground" />
                    {t('publicProfileSuccessfulExchanges', { count: person.booksExchangedCount })}
                  </span>
                )}
              </div>

              {person.bio && (
                <p className="mt-3 whitespace-pre-line text-[15px] leading-relaxed text-muted-foreground">
                  {person.bio}
                </p>
              )}

              {genres.length > 0 && (
                <div className="mt-3 flex flex-wrap gap-2">
                  {genres.map((genre) => (
                    <span
                      key={genre.genre}
                      className="rounded-full border border-border bg-muted/40 px-3 py-1 text-xs"
                    >
                      {genre.genre}
                    </span>
                  ))}
                </div>
              )}
            </div>
          </div>

          <div className="flex shrink-0 flex-col gap-4 lg:items-end">
            {actions}
            {(person.city || memberSince) && (
              <ul className="flex flex-wrap gap-x-5 gap-y-2 text-sm text-muted-foreground lg:flex-col lg:border-l lg:border-border lg:pl-5">
                {person.city && (
                  <li className="flex items-center gap-2">
                    <MapPin size={16} className="shrink-0" />
                    {person.city}, {t('countryRomania')}
                  </li>
                )}
                {memberSince && (
                  <li className="flex items-center gap-2">
                    <CalendarDays size={16} className="shrink-0" />
                    {t('publicProfileMemberSinceDate', { date: memberSince })}
                  </li>
                )}
              </ul>
            )}
          </div>
        </div>

        {current && (
          <div className="mt-5 flex items-center gap-3 border-t border-border pt-4">
            <div className="aspect-[2/3] w-9 shrink-0 overflow-hidden rounded-[3px] bg-muted">
              <BookCover url={current.book.coverUrl} title={current.book.title} />
            </div>
            <div className="min-w-0 flex-1">
              <p className="flex items-center gap-1.5 text-xs text-muted-foreground">
                <BookOpen size={13} />
                {t('publicProfileCurrentlyReading')}
              </p>
              <p className="truncate text-sm">
                <span className="font-semibold">{current.book.title}</span>
                {current.book.author && (
                  <span className="text-muted-foreground"> · {current.book.author}</span>
                )}
              </p>
            </div>
            {readingFraction(current) !== null && (
              <div className="w-40 shrink-0 max-sm:hidden">
                <ProgressBar fraction={readingFraction(current)!} />
              </div>
            )}
          </div>
        )}
      </section>

      {compatibility.data && (
        <MatchesBanner
          name={displayName}
          data={compatibility.data}
          onViewMatches={matchCount > 0 ? showMatches : undefined}
        />
      )}

      <section ref={booksSection} className="mt-8 scroll-mt-20">
        <div className="flex flex-wrap items-center justify-between gap-3">
          <h2 className="font-display text-2xl font-bold">
            {t('publicProfileBooksAvailable', { count: books.length })}
          </h2>
          {books.length > 1 && (
            <label className="flex items-center gap-2 text-sm text-muted-foreground">
              {t('publicProfileSortBy')}
              <span className="relative">
                <select
                  value={sort}
                  onChange={(event) => setSort(event.target.value as Sort)}
                  className="appearance-none rounded-[10px] border border-border bg-card py-2 pl-3 pr-9 text-foreground"
                >
                  <option value="newest">{t('discoverSortNewest')}</option>
                  <option value="oldest">{t('discoverSortOldest')}</option>
                  <option value="title">{t('publicProfileSortTitle')}</option>
                </select>
                <ChevronDown
                  size={16}
                  className="pointer-events-none absolute right-3 top-1/2 -translate-y-1/2"
                />
              </span>
            </label>
          )}
        </div>

        {books.length === 0 ? (
          <p className="mt-4 text-muted-foreground">
            {t('publicProfileNoBooks', { name: displayName })}
          </p>
        ) : (
          <>
            {/* Filtrele apar doar când chiar separă ceva: la un user cu toate
                cărțile la schimb, „Schimb (7)" ar fi doar „Toate" a doua oară. */}
            {(swapCount > 0 && saleCount > 0) || matchCount > 0 ? (
              <div className="mt-4 flex flex-wrap gap-2">
                <Chip active={filter === 'all'} onClick={() => setFilter('all')}>
                  {t('publicProfileFilterAll', { count: books.length })}
                </Chip>
                {swapCount > 0 && swapCount < books.length && (
                  <Chip active={filter === 'swap'} onClick={() => setFilter('swap')}>
                    {t('publicProfileFilterSwap', { count: swapCount })}
                  </Chip>
                )}
                {saleCount > 0 && saleCount < books.length && (
                  <Chip active={filter === 'sale'} onClick={() => setFilter('sale')}>
                    {t('publicProfileFilterSale', { count: saleCount })}
                  </Chip>
                )}
                {matchCount > 0 && (
                  <Chip active={filter === 'matches'} onClick={() => setFilter('matches')}>
                    {t('publicProfileFilterMatches', { count: matchCount })}
                  </Chip>
                )}
              </div>
            ) : null}

            {visibleBooks.length === 0 ? (
              <p className="mt-6 text-muted-foreground">{t('publicProfileFilterEmpty')}</p>
            ) : (
              <BookGrid className="mt-5">
                {visibleBooks.map((item, index) => (
                  <BookCard key={item.id} item={item} eager={index < 5} hideLocation />
                ))}
              </BookGrid>
            )}
          </>
        )}
      </section>

      {qrOpen && <ProfileQrDialog userId={userId} onClose={() => setQrOpen(false)} />}
      {reviewsOpen && (
        <ReviewsDialog
          rating={person.rating}
          reviews={reviews}
          onClose={() => setReviewsOpen(false)}
        />
      )}
    </div>
  );
}

/** Vânzare, donație sau licitație - tot ce se ia pe bani, nu la schimb. */
function isForSale(item: UserBook): boolean {
  return item.isForSale || item.isAuction || (toNumber(item.swapSalePrice) ?? 0) > 0;
}

function Chip({
  active,
  onClick,
  children,
}: {
  active: boolean;
  onClick: () => void;
  children: React.ReactNode;
}) {
  return (
    <button
      onClick={onClick}
      aria-pressed={active}
      className={cn(
        'rounded-full px-4 py-2 text-sm font-medium transition-colors',
        active
          ? 'bg-primary text-primary-foreground'
          : 'border border-border bg-card text-muted-foreground hover:bg-muted',
      )}
    >
      {children}
    </button>
  );
}

/**
 * „Tu & X": leagă profilul direct de funcția principală a aplicației - putem
 * face schimb? Nu apare deloc când nu există nicio potrivire, ca să nu
 * devină un banner gol pe fiecare profil vizitat.
 */
function MatchesBanner({
  name,
  data,
  onViewMatches,
}: {
  name: string;
  data: Compatibility;
  onViewMatches?: () => void;
}) {
  const { t } = useTranslation();
  const theirs = data.theirBooksYouWant.length;
  const yours = data.yourBooksTheyWant.length;
  if (theirs === 0 && yours === 0) return null;

  const description =
    theirs > 0 && yours > 0
      ? t('publicProfileMatchesBoth', { name, theirs, yours })
      : theirs > 0
        ? t('publicProfileMatchesTheirs', { name, count: theirs })
        : t('publicProfileMatchesYours', { name, count: yours });

  // Coperțile arătate: întâi ce are el și vrei tu - acolo e acțiunea.
  const covers = (theirs > 0 ? data.theirBooksYouWant : data.yourBooksTheyWant).slice(0, 3);

  return (
    <section className="mt-4 flex flex-col gap-4 rounded-[18px] border border-accent/30 bg-gradient-to-r from-accent/15 via-accent/5 to-transparent p-5 sm:flex-row sm:items-center">
      <MatchRings />
      <div className="min-w-0 flex-1">
        <h2 className="font-display text-xl font-bold">{t('publicProfileYouAnd', { name })}</h2>
        {theirs > 0 && yours > 0 && (
          <p className="mt-0.5 font-semibold">
            {t('publicProfileMatchesHeadline', { count: Math.min(theirs, yours) })}
          </p>
        )}
        <p className="mt-0.5 text-sm text-muted-foreground">{description}</p>
      </div>
      <div className="flex shrink-0 items-center gap-4">
        <div className="flex gap-1.5">
          {covers.map((item) => (
            <div
              key={item.id}
              className="aspect-[2/3] w-11 overflow-hidden rounded-[4px] bg-muted shadow-md"
            >
              <BookCover
                url={item.mainPhotoUrl ?? item.book.coverUrl}
                fallbackUrl={item.book.coverUrl}
                title={item.book.title}
              />
            </div>
          ))}
        </div>
        {onViewMatches && (
          <Button variant="primary" onClick={onViewMatches}>
            {t('publicProfileViewMatches')}
            <ArrowRight size={16} />
          </Button>
        )}
      </div>
    </section>
  );
}

/** Două inele care se intersectează - semnul vizual al potrivirii. */
function MatchRings() {
  return (
    <svg width="56" height="40" viewBox="0 0 56 40" aria-hidden className="shrink-0 text-accent">
      <circle cx="20" cy="20" r="15" fill="none" stroke="currentColor" strokeWidth="4" opacity="0.55" />
      <circle cx="36" cy="20" r="15" fill="none" stroke="currentColor" strokeWidth="4" />
    </svg>
  );
}

function ReviewsDialog({
  rating,
  reviews,
  onClose,
}: {
  rating: number;
  reviews: PublicReview[];
  onClose: () => void;
}) {
  const { t, i18n } = useTranslation();
  const format = new Intl.DateTimeFormat(i18n.language, {
    day: 'numeric',
    month: 'short',
    year: 'numeric',
  });

  return (
    <div role="dialog" aria-modal className="fixed inset-0 z-50 flex items-center justify-center p-5">
      <button aria-label={t('commonClose')} onClick={onClose} className="absolute inset-0 bg-black/50" />
      <div className="relative flex max-h-[80vh] w-full max-w-[520px] flex-col rounded-[20px] bg-card">
        <div className="flex items-center gap-3 border-b border-border p-5">
          <Star size={20} className="fill-warning text-warning" />
          <h2 className="flex-1 font-display text-lg font-bold">
            {rating.toFixed(1)} · {t('publicProfileReviewsLink', { count: reviews.length })}
          </h2>
          <button
            onClick={onClose}
            aria-label={t('commonClose')}
            className="rounded-md p-1.5 text-muted-foreground hover:bg-muted"
          >
            <X size={20} />
          </button>
        </div>
        <div className="overflow-y-auto p-5">
          {reviews.length === 0 ? (
            <p className="text-muted-foreground">{t('publicProfileNoReviews')}</p>
          ) : (
            <ul className="flex flex-col gap-5">
              {reviews.map((review, index) => (
                <li key={`${review.reviewerId}-${index}`} className="flex gap-3">
                  <Avatar
                    src={review.reviewerImage}
                    name={review.reviewerName ?? '?'}
                    size={36}
                  />
                  <div className="min-w-0 flex-1">
                    <div className="flex items-center gap-2">
                      <span className="truncate font-semibold">
                        {review.reviewerName ?? t('commonUnknownUser')}
                      </span>
                      {review.rating != null && (
                        <span className="flex items-center gap-0.5 text-sm">
                          <Star size={13} className="fill-warning text-warning" />
                          {review.rating}
                        </span>
                      )}
                      <span className="ml-auto shrink-0 text-xs text-muted-foreground">
                        {format.format(new Date(review.date))}
                      </span>
                    </div>
                    {review.comment && (
                      <p className="mt-1 whitespace-pre-line text-sm text-muted-foreground">
                        {review.comment}
                      </p>
                    )}
                  </div>
                </li>
              ))}
            </ul>
          )}
        </div>
      </div>
    </div>
  );
}
