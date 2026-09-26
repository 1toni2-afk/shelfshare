import { useRef, useState } from 'react';
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { Link } from 'react-router-dom';
import { useTranslation } from 'react-i18next';
import {
  ArrowRight,
  BadgeCheck,
  BookMarked,
  BookOpen,
  BookOpenCheck,
  Camera,
  CalendarDays,
  Globe,
  Heart,
  Library,
  MapPin,
  Pencil,
  QrCode,
  Repeat,
  Settings as SettingsIcon,
  Share2,
  ShieldCheck,
  Star,
  Target,
} from 'lucide-react';
import { ScreenHeader, HeaderAction } from '@/components/layout/ScreenHeader';
import { profileKeys, profileRepository } from './profileRepository';
import { booksKeys, booksRepository } from '@/features/books/booksRepository';
import { listsKeys, collectionsRepository, wishlistRepository } from '@/features/lists/listsRepository';
import { shelfKeys, shelfRepository } from '@/features/shelf/shelfRepository';
import { BookCover } from '@/components/ui/BookCover';
import { Avatar } from '@/components/ui/Avatar';
import { ErrorNotice, Spinner } from '@/components/ui';
import { useToast } from '@/components/ui/Toast';
import { useAuth } from '@/features/auth/AuthProvider';
import { ProfileQrDialog } from '@/components/ui/ProfileQrDialog';
import { shareAppLink } from '@/lib/utils/shareLink';
import { cn } from '@/lib/utils/cn';
import { ProgressBar, readingFraction } from './ReadingProgress';
import { BadgesCard } from './Badges';
import type { AppUser, CurrentlyReading, GenreCount, UserBook } from '@/types/models';

/**
 * Profilul propriu.
 *
 * Coloana principală: header (avatar, nume, trust, statistici), „Citesc acum"
 * și provocarea anuală, apoi raftul - vedeta paginii, cu coperți mari -,
 * colecțiile și activitatea recentă. Pe ecran lat se adaugă coloana din
 * dreapta: acțiunile, „Despre mine", informațiile de cont și un singur card
 * „Profil de cititor" cu statistici care NU repetă ce e deja în header.
 *
 * Setările, deconectarea și ștergerea contului stau pe `/settings`, accesibil
 * prin „⚙" din bară - profilul rămâne scurt și scanabil.
 */
export function MyProfileScreen() {
  const { t } = useTranslation();
  const { user, setUser } = useAuth();
  const queryClient = useQueryClient();
  const toast = useToast();
  const fileInput = useRef<HTMLInputElement>(null);
  const [qrOpen, setQrOpen] = useState(false);

  const profile = useQuery({
    queryKey: profileKeys.me(),
    queryFn: ({ signal }) => profileRepository.me(signal),
    // Userul din context vine deja de la /profile/me la restaurarea sesiunii.
    // Îl folosim ca date inițiale ca ecranul să se deseneze instant, iar
    // reîmprospătarea să se facă în fundal.
    initialData: user ?? undefined,
  });

  const photo = useMutation({
    mutationFn: (file: File) => profileRepository.uploadPhoto(file),
    onSuccess: (updated) => {
      setUser(updated);
      queryClient.setQueryData(profileKeys.me(), updated);
    },
    onError: () => toast.show(t('profilePhotoError'), 'danger'),
  });

  const header = (
    <ScreenHeader
      title={t('profileTitle')}
      actions={
        <HeaderAction to="/settings" label={t('profileSettings')}>
          <SettingsIcon size={22} />
        </HeaderAction>
      }
    />
  );

  if (profile.isPending) {
    return (
      <>
        {header}
        <div className="flex min-h-[60vh] items-center justify-center text-accent">
          <Spinner size={28} />
        </div>
      </>
    );
  }

  if (profile.isError) {
    return (
      <>
        {header}
        <div className="mx-auto max-w-2xl p-6">
          <ErrorNotice message={t('profileLoadError')} onRetry={() => void profile.refetch()} />
        </div>
      </>
    );
  }

  const me = profile.data;
  const displayName = me.name?.trim() ? me.name : me.email;

  const actions = (
    <div className="flex gap-2">
      <Link
        to="/profile/edit"
        className="flex flex-1 items-center justify-center gap-2 rounded-[12px] bg-primary px-5 py-2.5 text-sm font-bold text-primary-foreground hover:brightness-110"
      >
        <Pencil size={16} />
        {t('profileEditProfile')}
      </Link>
      <IconButton label={t('profileQrTooltip')} onClick={() => setQrOpen(true)}>
        <QrCode size={20} />
      </IconButton>
      <IconButton
        label={t('profileCopyLink')}
        onClick={() => void shareAppLink(`/users/${me.id}`, toast.show)}
      >
        <Share2 size={20} />
      </IconButton>
    </div>
  );

  return (
    <>
      {header}
      {/*
        Două coloane doar de la 1180px în sus: sub prag, coloana laterală de
        380px ar strânge raftul sub lățimea la care coperțile mai arată a
        coperți. Conținutul principal crește până la ~900px, cât să nu lase
        jumătate de monitor goală, dar nici să întindă rândurile de text.
      */}
      <div className="mx-auto grid w-full max-w-[1320px] grid-cols-1 items-start gap-x-8 px-4 pb-16 pt-4 sm:px-6 min-[1180px]:grid-cols-[minmax(0,1fr)_360px] min-[1180px]:px-8">
        <div className="min-w-0">
          <input
            ref={fileInput}
            type="file"
            accept="image/*"
            hidden
            onChange={(event) => {
              const file = event.target.files?.[0];
              if (file) photo.mutate(file);
              event.target.value = '';
            }}
          />

          <div className="flex items-center gap-4 sm:gap-6">
            {/* Avatarul e și butonul de schimbare a pozei - insigna cu aparatul
                de fotografiat e singurul indiciu că se poate apăsa. */}
            <button
              onClick={() => fileInput.current?.click()}
              disabled={photo.isPending}
              aria-label={t('profilePhotoChoose')}
              className="relative shrink-0"
            >
              <span className="sm:hidden">
                <Avatar src={me.profileImage} name={displayName} size={80} />
              </span>
              <span className="hidden sm:block">
                <Avatar src={me.profileImage} name={displayName} size={112} />
              </span>
              <span className="absolute bottom-0.5 right-0.5 flex size-7 items-center justify-center rounded-full border-2 border-background bg-primary text-primary-foreground">
                {photo.isPending ? <Spinner size={12} /> : <Camera size={13} />}
              </span>
            </button>

            <div className="min-w-0 flex-1">
              <h1 className="flex items-center gap-2">
                <span className="min-w-0 truncate font-display text-2xl font-bold leading-tight sm:text-[34px]">
                  {displayName}
                </span>
                {me.isEmailVerified && (
                  <BadgeCheck size={22} className="shrink-0 text-accent" />
                )}
              </h1>
              <p className="mt-0.5 truncate text-muted-foreground sm:text-lg">
                {[me.username ? `@${me.username}` : null, me.city].filter(Boolean).join(' · ')}
              </p>
              {me.trustScore && (
                <p
                  title={t('profileTrustTooltip')}
                  className="mt-2 inline-flex items-center gap-1.5 rounded-full border border-accent/40 bg-accent/10 px-2.5 py-0.5 text-xs font-semibold text-accent"
                >
                  <ShieldCheck size={13} />
                  {t('profileTrustBadge', { score: me.trustScore.score })}
                </p>
              )}
            </div>
          </div>

          {/* Bio-ul stă aici doar cât nu se vede coloana din dreapta; acolo
              are cardul „Despre mine" și ar apărea de două ori. */}
          {me.bio?.trim() && (
            <p className="mt-4 leading-snug text-muted-foreground min-[1180px]:hidden">
              {me.bio.trim()}
            </p>
          )}

          <div className="mt-5 grid grid-cols-3 border-y border-border py-4 text-center">
            <Stat
              icon={<BookOpen size={20} />}
              value={String(me.booksSharedCount)}
              label={t('profileStatBooks')}
            />
            <Stat
              icon={<Repeat size={20} />}
              value={String(me.booksExchangedCount)}
              label={t('profileStatSwaps')}
            />
            <Stat
              icon={<Star size={20} className="fill-warning text-warning" />}
              value={me.rating > 0 ? me.rating.toFixed(1) : '—'}
              label={t('profileStatRating')}
            />
          </div>

          <div className="mt-5 min-[1180px]:hidden">{actions}</div>

          <ReadingNow current={me.currentlyReading ?? null} />
          <LibraryPreview />
          <CollectionsPreview />
          <RecentActivityPreview />

          {/* Sub pragul de două coloane, cardul de cititor coboară aici - altfel
              statisticile lui nu s-ar vedea nicăieri pe ecran îngust. */}
          <div className="mt-8 flex flex-col gap-4 min-[1180px]:hidden">
            <ReadingProfileCard me={me} />
            <BadgesCard achievements={me.achievements ?? []} />
          </div>

          <p className="mt-8 text-center text-xs text-muted-foreground">
            {t('profileMoreInSettings')}
          </p>
        </div>

        <aside className="hidden flex-col gap-4 min-[1180px]:flex">
          {actions}
          <SideCards me={me} />
        </aside>
      </div>

      {qrOpen && <ProfileQrDialog userId={me.id} onClose={() => setQrOpen(false)} />}
    </>
  );
}

function IconButton({
  label,
  onClick,
  children,
}: {
  label: string;
  onClick: () => void;
  children: React.ReactNode;
}) {
  return (
    <button
      onClick={onClick}
      aria-label={label}
      title={label}
      className="flex size-11 shrink-0 items-center justify-center rounded-[12px] border border-border hover:bg-muted"
    >
      {children}
    </button>
  );
}

function Stat({ value, label, icon }: { value: string; label: string; icon: React.ReactNode }) {
  return (
    <div className="flex flex-col items-center">
      <p className="flex items-center gap-2 font-display text-2xl font-bold">
        <span className="text-muted-foreground">{icon}</span>
        {value}
      </p>
      <p className="text-xs text-muted-foreground">{label}</p>
    </div>
  );
}

/**
 * „Citesc acum" și provocarea anuală, alăturate pe ecran lat. Fiecare dispare
 * singur când n-are date; dacă rămâne doar unul, ocupă tot rândul.
 */
function ReadingNow({ current }: { current: CurrentlyReading | null }) {
  const challenge = useQuery({
    queryKey: profileKeys.readingChallenge(),
    queryFn: ({ signal }) => profileRepository.readingChallenge(signal),
  });
  const hasChallenge = !!challenge.data?.goal;

  if (!current && !hasChallenge) return null;

  return (
    // `grid-cols-1` (= minmax(0,1fr)) e obligatoriu: fără el coloana implicită
    // e `auto` și se lățește după conținut - un titlu lung în „Citesc acum"
    // (pe care `truncate` ar trebui să-l taie) împingea cardurile peste
    // marginea ecranului și pagina se putea trage lateral.
    <div
      className={cn('mt-6 grid grid-cols-1 gap-4', current && hasChallenge && 'md:grid-cols-2')}
    >
      {current && <CurrentlyReadingCard current={current} />}
      {hasChallenge && challenge.data && (
        <ReadingChallengeCard
          year={challenge.data.year}
          goal={challenge.data.goal!}
          progress={challenge.data.progress}
        />
      )}
    </div>
  );
}

function CurrentlyReadingCard({ current }: { current: CurrentlyReading }) {
  const { t, i18n } = useTranslation();
  const fraction = readingFraction(current);

  return (
    <Link
      to="/bookshelf"
      className="flex gap-4 rounded-[16px] border border-border bg-card p-4 transition-colors hover:bg-muted/40"
    >
      <div className="aspect-[2/3] w-[72px] shrink-0 overflow-hidden rounded-[6px] bg-muted shadow-md">
        <BookCover url={current.book.coverUrl} title={current.book.title} />
      </div>
      <div className="flex min-w-0 flex-1 flex-col">
        <p className="font-display text-lg font-bold">{t('profileCurrentlyReading')}</p>
        <p className="mt-1 truncate font-semibold">{current.book.title}</p>
        {current.book.author && (
          <p className="truncate text-sm text-muted-foreground">{current.book.author}</p>
        )}
        <div className="mt-auto pt-2">
          {fraction !== null ? (
            <ProgressBar fraction={fraction} />
          ) : (
            current.currentPage > 0 && (
              <p className="text-xs text-muted-foreground">
                {t('profileReadingPageOf', { current: current.currentPage, total: '?' })}
              </p>
            )
          )}
          <p className="mt-1.5 text-xs text-muted-foreground">
            {t('profileReadingStarted', {
              date: new Intl.DateTimeFormat(i18n.language, {
                day: 'numeric',
                month: 'short',
                year: 'numeric',
              }).format(new Date(current.startedAt)),
            })}
          </p>
        </div>
      </div>
    </Link>
  );
}

function ReadingChallengeCard({
  year,
  goal,
  progress,
}: {
  year: number;
  goal: number;
  progress: number;
}) {
  const { t } = useTranslation();
  const fraction = Math.min(1, progress / goal);
  const left = Math.max(0, goal - progress);

  return (
    <section className="flex flex-col rounded-[16px] border border-border bg-card p-4">
      <p className="flex items-center gap-2 font-display text-lg font-bold">
        <Target size={20} className="shrink-0 text-accent" />
        {t('profileReadingChallengeTitle', { year })}
      </p>
      <p className="mt-2 font-display text-xl font-bold">
        {t('profileChallengeProgress', { progress, goal })}
      </p>
      <div className="mt-auto pt-3">
        <ProgressBar fraction={fraction} />
        <p className="mt-1.5 text-xs text-muted-foreground">
          {left > 0 ? t('profileChallengeToGo', { n: left }) : t('profileChallengeDone')}
        </p>
      </div>
    </section>
  );
}

function SectionHeader({
  title,
  to,
  meta,
}: {
  title: string;
  to?: string;
  meta?: string;
}) {
  const { t } = useTranslation();
  return (
    <div className="flex items-baseline justify-between gap-3">
      <h2 className="font-display text-xl font-bold">{title}</h2>
      <div className="flex shrink-0 items-baseline gap-4 text-sm">
        {meta && <span className="text-muted-foreground">{meta}</span>}
        {to && (
          <Link to={to} className="flex items-center gap-1 font-medium text-accent hover:underline">
            {t('commonSeeAll')}
            <ArrowRight size={14} />
          </Link>
        )}
      </div>
    </div>
  );
}

/**
 * Raftul: cinci coperți mari și un tile final „+N · Vezi raftul". Pe telefon
 * aceleași șase piese se așază pe două rânduri de câte trei, ca fiecare
 * copertă să rămână lizibilă.
 */
function LibraryPreview() {
  const { t } = useTranslation();

  const library = useQuery({
    queryKey: booksKeys.myLibrary(),
    queryFn: ({ signal }) => booksRepository.getMyLibrary(signal),
  });

  const active = (library.data ?? []).filter((item) => !item.permanentlyTransferred);
  if (active.length === 0) return null;

  const covers = active.slice(0, 5);
  const remaining = active.length - covers.length;

  return (
    <section className="mt-8">
      <SectionHeader
        title={t('libraryTitle')}
        to="/library"
        meta={t('profileLibraryAvailable', { n: active.length })}
      />
      <div className="mt-3 grid grid-cols-3 gap-3 sm:grid-cols-6">
        {covers.map((item: UserBook) => (
          <Link
            key={item.id}
            to={`/books/${item.id}`}
            className="group aspect-[2/3] overflow-hidden rounded-[8px] bg-muted shadow-md"
          >
            <BookCover
              url={item.mainPhotoUrl ?? item.book.coverUrl}
              fallbackUrl={item.book.coverUrl}
              title={item.book.title}
              className="transition duration-300 group-hover:scale-[1.03]"
            />
          </Link>
        ))}
        <Link
          to="/library"
          className="flex aspect-[2/3] flex-col items-center justify-center gap-1 rounded-[8px] border border-border bg-card text-center hover:bg-muted"
        >
          {remaining > 0 && (
            <span className="font-display text-2xl font-bold">+{remaining}</span>
          )}
          <span className="px-2 text-sm text-muted-foreground">{t('profileViewShelf')}</span>
        </Link>
      </div>
    </section>
  );
}

/** Colecțiile ca mici carduri: nume, număr și o fâșie de coperți. */
function CollectionsPreview() {
  const { t } = useTranslation();

  const collections = useQuery({
    queryKey: listsKeys.collections(),
    queryFn: ({ signal }) => collectionsRepository.mine(signal),
  });

  if (!collections.data || collections.data.length === 0) return null;

  return (
    <section className="mt-8">
      <SectionHeader title={t('collectionsTitle')} to="/collections" />
      <div className="mt-3 grid grid-cols-1 gap-3 sm:grid-cols-2 lg:grid-cols-3">
        {collections.data.slice(0, 3).map((collection) => (
          <Link
            key={collection.id}
            to={`/collections/${collection.id}`}
            className="rounded-[14px] border border-border bg-card p-3.5 transition-colors hover:bg-muted/40"
          >
            <div className="flex items-start gap-2.5">
              <Library size={20} className="mt-0.5 shrink-0 text-accent" />
              <div className="min-w-0">
                <p className="truncate font-semibold">{collection.name}</p>
                <p className="text-xs text-muted-foreground">
                  {t('profileCollectionBooks', { count: collection.bookCount })}
                </p>
              </div>
            </div>
            {collection.books.length > 0 && (
              <div className="mt-3 flex gap-1.5">
                {collection.books.slice(0, 5).map((book) => (
                  <div
                    key={book.id}
                    className="aspect-[2/3] w-[34px] shrink-0 overflow-hidden rounded-[3px] bg-muted"
                  >
                    <BookCover url={book.coverUrl} title={book.title} />
                  </div>
                ))}
              </div>
            )}
          </Link>
        ))}
      </div>
    </section>
  );
}

/**
 * „Activitate recentă": ultimele cărți adăugate, fiecare cu mini-coperta ei -
 * profilul arată viu, nu ca un tabel.
 */
function RecentActivityPreview() {
  const { t } = useTranslation();

  const library = useQuery({
    queryKey: booksKeys.myLibrary(),
    queryFn: ({ signal }) => booksRepository.getMyLibrary(signal),
  });

  const events = (library.data ?? []).slice(0, 4);
  if (events.length === 0) return null;

  return (
    <section className="mt-8">
      <SectionHeader title={t('profileRecentActivity')} to="/library" />
      <ul className="mt-2 divide-y divide-border">
        {events.map((item) => {
          // Titlul e bold în mijlocul propoziției, iar ordinea cuvintelor
          // diferă între limbi - deci se taie traducerea în jurul lui.
          const [before, after = ''] = t('profileActivityAddedToShelf', {
            title: '\u0000',
          }).split('\u0000');
          return (
            <li key={item.id}>
              <Link to={`/books/${item.id}`} className="flex items-center gap-3 py-2.5 hover:bg-muted/30">
                <div className="aspect-[2/3] w-7 shrink-0 overflow-hidden rounded-[3px] bg-muted">
                  <BookCover
                    url={item.mainPhotoUrl ?? item.book.coverUrl}
                    fallbackUrl={item.book.coverUrl}
                    title={item.book.title}
                  />
                </div>
                <span className="min-w-0 flex-1 truncate text-sm text-muted-foreground">
                  {before}
                  <span className="font-medium text-foreground">{item.book.title}</span>
                  {after}
                </span>
                <span className="shrink-0 text-xs text-muted-foreground">
                  {relativeAge(item.createdAt)}
                </span>
              </Link>
            </li>
          );
        })}
      </ul>
    </section>
  );
}

/** `2h`, `5d`, `3w`, `4mo` - forma scurtă din `_relativeAge`. */
function relativeAge(iso: string): string {
  const minutes = Math.max(0, (Date.now() - new Date(iso).getTime()) / 60000);
  if (minutes < 60) return `${Math.floor(minutes)}m`;
  const hours = minutes / 60;
  if (hours < 24) return `${Math.floor(hours)}h`;
  const days = hours / 24;
  if (days < 7) return `${Math.floor(days)}d`;
  if (days < 30) return `${Math.floor(days / 7)}w`;
  return `${Math.floor(days / 30)}mo`;
}

/**
 * Coloana din dreapta, doar pe ecran lat. „Despre mine" și informațiile de
 * cont, apoi cardul de cititor.
 */
function SideCards({ me }: { me: AppUser }) {
  const { t, i18n } = useTranslation();
  const bio = me.bio?.trim();

  return (
    <>
      <Card>
        <div className="flex items-start gap-2">
          <h2 className="min-w-0 flex-1 font-display text-lg font-bold">{t('profileAboutMe')}</h2>
          <Link
            to="/profile/edit"
            aria-label={t('profileEditProfile')}
            title={t('profileEditProfile')}
            className="-mr-1 shrink-0 rounded-md p-1.5 text-muted-foreground hover:bg-muted"
          >
            <Pencil size={18} />
          </Link>
        </div>
        {bio ? (
          <p className="mt-1 leading-relaxed">{bio}</p>
        ) : (
          <p className="mt-1 text-[13px] italic text-muted-foreground">{t('profileAboutEmpty')}</p>
        )}
      </Card>

      <Card>
        <ul className="flex flex-col gap-3">
          {me.createdAt && (
            <InfoRow
              icon={<CalendarDays size={18} />}
              label={t('profileMemberSince')}
              value={new Intl.DateTimeFormat(i18n.language, {
                month: 'short',
                year: 'numeric',
              }).format(new Date(me.createdAt))}
            />
          )}
          {me.city && (
            <InfoRow
              icon={<MapPin size={18} />}
              label={t('profileLocation')}
              value={`${me.city}, ${t('countryRomania')}`}
            />
          )}
          {me.languages.length > 0 && (
            <InfoRow
              icon={<Globe size={18} />}
              label={t('profileLanguages')}
              value={me.languages.join(', ')}
            />
          )}
        </ul>
      </Card>

      <ReadingProfileCard me={me} />
      <BadgesCard achievements={me.achievements ?? []} />
    </>
  );
}

/**
 * „Profil de cititor": statistici și genuri într-un singur card, în locul a
 * două dreptunghiuri separate. Deliberat fără cărți/schimburi/rating - acelea
 * sunt deja în header, iar aici ar apărea a doua oară.
 */
function ReadingProfileCard({ me }: { me: AppUser }) {
  const { t } = useTranslation();

  const wishlist = useQuery({
    queryKey: listsKeys.wishlist(),
    queryFn: ({ signal }) => wishlistRepository.list(signal),
  });
  const shelf = useQuery({
    queryKey: shelfKeys.bookshelf(),
    queryFn: ({ signal }) => shelfRepository.mine(signal),
  });
  const challenge = useQuery({
    queryKey: profileKeys.readingChallenge(),
    queryFn: ({ signal }) => profileRepository.readingChallenge(signal),
  });

  const genres = me.readingStats?.topGenres?.slice(0, 3) ?? [];
  const maxGenre = Math.max(1, ...genres.map((genre) => genre.count));

  return (
    <Card>
      <h2 className="mb-3 font-display text-lg font-bold">{t('profileReadingProfile')}</h2>
      <div className="grid grid-cols-2 gap-2">
        <StatTile
          icon={<BookOpenCheck size={20} />}
          value={challenge.data?.progress ?? 0}
          label={t('profileStatReadThisYear')}
        />
        <StatTile
          icon={<BookMarked size={20} />}
          value={shelf.data?.finished.length ?? 0}
          label={t('profileStatFinishedAll')}
        />
        <StatTile
          icon={<BookOpen size={20} />}
          value={shelf.data?.wantToRead.length ?? 0}
          label={t('profileStatWantToRead')}
        />
        <StatTile
          icon={<Heart size={20} />}
          value={wishlist.data?.length ?? 0}
          label={t('profileStatWishlisted')}
        />
      </div>

      <h3 className="mb-2 mt-5 font-display font-bold">{t('profileTopGenresTitle')}</h3>
      {genres.length === 0 ? (
        <p className="flex items-start gap-2 text-[13px] text-muted-foreground">
          <BookOpen size={18} className="mt-0.5 shrink-0" />
          {t('profileTopGenresEmpty')}
        </p>
      ) : (
        <ul className="flex flex-col gap-2.5">
          {genres.map((genre: GenreCount) => (
            <li key={genre.genre} className="grid grid-cols-[minmax(0,7rem)_1fr_1.5rem] items-center gap-3 text-sm">
              <span className="truncate">{genre.genre}</span>
              <span className="h-2 overflow-hidden rounded-full bg-muted">
                <span
                  className="block h-full rounded-full bg-accent"
                  style={{ width: `${(genre.count / maxGenre) * 100}%` }}
                />
              </span>
              <span className="text-right text-muted-foreground">{genre.count}</span>
            </li>
          ))}
        </ul>
      )}
    </Card>
  );
}

function Card({ children }: { children: React.ReactNode }) {
  return <section className="rounded-[16px] border border-border bg-card p-4">{children}</section>;
}

function InfoRow({
  icon,
  label,
  value,
}: {
  icon: React.ReactNode;
  label: string;
  value: string;
}) {
  return (
    <li className="flex items-start gap-3">
      <span className="mt-0.5 shrink-0 text-muted-foreground">{icon}</span>
      <span className="min-w-0">
        <span className="block text-xs text-muted-foreground">{label}</span>
        <span className="block">{value}</span>
      </span>
    </li>
  );
}

function StatTile({
  icon,
  value,
  label,
}: {
  icon: React.ReactNode;
  value: number;
  label: string;
}) {
  return (
    <div className="flex items-center gap-3 rounded-[12px] bg-muted/50 p-3">
      <span className="shrink-0 text-muted-foreground">{icon}</span>
      <span className="min-w-0">
        <span className="block font-display text-xl font-bold leading-tight">{value}</span>
        <span className="block text-xs leading-tight text-muted-foreground">{label}</span>
      </span>
    </div>
  );
}
