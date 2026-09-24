import { useRef, useState } from 'react';
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { Link } from 'react-router-dom';
import { useTranslation } from 'react-i18next';
import {
  BadgeCheck,
  BookOpen,
  Camera,
  CalendarDays,
  Globe,
  MapPin,
  Pencil,
  QrCode,
  Settings as SettingsIcon,
  Share2,
  Star,
} from 'lucide-react';
import { ScreenHeader, HeaderAction } from '@/components/layout/ScreenHeader';
import { profileKeys, profileRepository } from './profileRepository';
import { booksKeys, booksRepository } from '@/features/books/booksRepository';
import { listsKeys, collectionsRepository, wishlistRepository } from '@/features/lists/listsRepository';
import { BookCover } from '@/components/ui/BookCover';
import { Avatar } from '@/components/ui/Avatar';
import { ErrorNotice, Spinner } from '@/components/ui';
import { useToast } from '@/components/ui/Toast';
import { useAuth } from '@/features/auth/AuthProvider';
import { ProfileQrDialog } from '@/components/ui/ProfileQrDialog';
import { shareAppLink } from '@/lib/utils/shareLink';
import type { AppUser, GenreCount, UserBook } from '@/types/models';

/**
 * Lățimea unei coperte din rândurile de preview. Fixă intenționat: calculată ca
 * fracțiune din ecran, pe desktop patru cărți acopereau o treime de pagină.
 */
const COVER_TILE_WIDTH = 74;

/**
 * Profilul propriu. Port al `my_profile_screen.dart`: header cu avatar și trust
 * score, o linie de statistici, acțiunile principale, apoi preview-urile
 * (challenge, bibliotecă, colecții, activitate). Pe desktop se adaugă coloana
 * din dreapta cu „Despre / Info / Statistici / Top genuri".
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

  return (
    <>
      {header}
      {/* Două coloane peste pragul de desktop: conținutul la 560px și cardurile
          laterale la 340px - aceleași valori ca `kProfileContentMaxWidth` și
          `kProfileSideColumnWidth`. */}
      <div className="mx-auto flex w-full max-w-[1024px] flex-col items-start gap-0 px-0 pb-16 min-[900px]:flex-row">
        <div className="mx-auto w-full max-w-[560px] px-5 py-5">
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

          <div className="flex items-start gap-4">
            {/* Avatarul e și butonul de schimbare a pozei - insigna cu aparatul
                de fotografiat e singurul indiciu că se poate apăsa. */}
            <button
              onClick={() => fileInput.current?.click()}
              disabled={photo.isPending}
              aria-label={t('profilePhotoChoose')}
              className="relative shrink-0"
            >
              <Avatar src={me.profileImage} name={displayName} size={72} />
              <span className="absolute -bottom-0.5 -right-0.5 flex size-6 items-center justify-center rounded-full border-2 border-background bg-primary text-primary-foreground">
                {photo.isPending ? <Spinner size={12} /> : <Camera size={12} />}
              </span>
            </button>

            <div className="min-w-0 flex-1">
              <p className="flex items-center gap-1.5">
                <span className="min-w-0 truncate font-display text-xl font-bold">
                  {displayName}
                </span>
                {me.isEmailVerified && (
                  <BadgeCheck size={16} className="shrink-0 text-accent" />
                )}
              </p>
              <p className="truncate text-sm text-muted-foreground">
                {[me.username ? `@${me.username}` : null, me.city].filter(Boolean).join(' · ')}
              </p>
            </div>

            {me.trustScore && (
              <div className="shrink-0 text-center">
                <p className="text-xl font-semibold text-accent">{me.trustScore.score}</p>
                <p className="text-[10px] text-muted-foreground">trust</p>
              </div>
            )}
          </div>

          {/* Bio-ul stă inline doar pe mobil; pe desktop e pe cardul „Despre
              mine" din dreapta, deci aici ar apărea de două ori. */}
          {me.bio?.trim() && (
            <p className="mt-3 text-[13px] leading-snug text-muted-foreground min-[900px]:hidden">
              {me.bio.trim()}
            </p>
          )}

          <div className="mt-4 grid grid-cols-3 gap-2 border-y border-border py-3 text-center">
            <Stat value={String(me.booksSharedCount)} label={t('profileStatBooks')} />
            <Stat value={String(me.booksExchangedCount)} label={t('profileStatSwaps')} />
            <Stat
              value={me.rating > 0 ? me.rating.toFixed(1) : '—'}
              label={t('profileStatRating')}
              icon={<Star size={14} className="fill-warning text-warning" />}
            />
          </div>

          <div className="mt-5 flex gap-2">
            <Link
              to="/profile/edit"
              className="flex flex-1 items-center justify-center gap-2 rounded-[12px] bg-primary px-5 py-2.5 text-sm font-bold text-primary-foreground hover:brightness-110"
            >
              <Pencil size={16} />
              {t('profileEditProfile')}
            </Link>
            <button
              onClick={() => setQrOpen(true)}
              aria-label={t('profileQrTooltip')}
              title={t('profileQrTooltip')}
              className="flex size-11 shrink-0 items-center justify-center rounded-[8px] border border-border hover:bg-muted"
            >
              <QrCode size={20} />
            </button>
            <button
              onClick={() => void shareAppLink(`/users/${me.id}`, toast.show)}
              aria-label={t('profileCopyLink')}
              title={t('profileCopyLink')}
              className="flex size-11 shrink-0 items-center justify-center rounded-[8px] border border-border hover:bg-muted"
            >
              <Share2 size={20} />
            </button>
          </div>

          <ReadingChallengeMini />
          <LibraryPreview />
          <CollectionsPreview />
          <RecentActivityPreview />

          <p className="mt-8 text-center text-xs text-muted-foreground">
            {t('profileMoreInSettings')}
          </p>
        </div>

        <aside className="hidden w-[340px] shrink-0 flex-col gap-4 px-3 py-5 min-[900px]:flex">
          <SideCards me={me} />
        </aside>
      </div>

      {qrOpen && <ProfileQrDialog userId={me.id} onClose={() => setQrOpen(false)} />}
    </>
  );
}

function Stat({ value, label, icon }: { value: string; label: string; icon?: React.ReactNode }) {
  return (
    <div>
      <p className="flex items-center justify-center gap-1 font-display text-lg font-bold">
        {icon}
        {value}
      </p>
      <p className="text-xs text-muted-foreground">{label}</p>
    </div>
  );
}

/**
 * Reading challenge condensat: „anul challenge · x/goal" plus o bară subțire.
 * Ascuns dacă userul n-a setat obiectivul anual.
 */
function ReadingChallengeMini() {
  const challenge = useQuery({
    queryKey: profileKeys.readingChallenge(),
    queryFn: ({ signal }) => profileRepository.readingChallenge(signal),
  });

  if (!challenge.data?.goal) return null;
  const progress = Math.min(1, challenge.data.progress / challenge.data.goal);

  return (
    <section className="mt-6">
      <div className="flex items-center justify-between text-xs text-muted-foreground">
        <span>{challenge.data.year} challenge</span>
        <span>
          {challenge.data.progress} / {challenge.data.goal}
        </span>
      </div>
      <div className="mt-2 h-1 overflow-hidden rounded-sm bg-muted">
        <div className="h-full rounded-sm bg-accent" style={{ width: `${progress * 100}%` }} />
      </div>
    </section>
  );
}

/**
 * Preview bibliotecă: titlu, „N disponibile", și un rând de coperți de lățime
 * fixă, câte încap, urmat de un tile „+N".
 */
function LibraryPreview() {
  const { t } = useTranslation();

  const library = useQuery({
    queryKey: booksKeys.myLibrary(),
    queryFn: ({ signal }) => booksRepository.getMyLibrary(signal),
  });

  const active = (library.data ?? []).filter((item) => !item.permanentlyTransferred);
  if (active.length === 0) return null;

  // Șase sloturi la 560px de coloană; ultimul e tile-ul cu restul.
  const slots = 6;
  const covers = active.slice(0, slots - 1);
  const remaining = active.length - covers.length;

  return (
    <Link to="/library" className="mt-6 block">
      <div className="flex items-center justify-between">
        <h2 className="font-semibold">{t('libraryTitle')}</h2>
        <span className="text-[11px] text-muted-foreground">
          {t('profileLibraryAvailable', { n: active.length })}
        </span>
      </div>
      <div className="mt-2.5 flex gap-[7px]">
        {covers.map((item: UserBook) => (
          <div
            key={item.id}
            style={{ width: COVER_TILE_WIDTH }}
            className="aspect-[2/3] shrink-0 overflow-hidden rounded-[5px] bg-muted"
          >
            <BookCover url={item.book.coverUrl} fallbackUrl={item.mainPhotoUrl} title={item.book.title} />
          </div>
        ))}
        <div
          style={{ width: COVER_TILE_WIDTH }}
          className="flex aspect-[2/3] shrink-0 items-center justify-center rounded-[5px] bg-muted text-xs text-muted-foreground"
        >
          {remaining > 0 ? `+${remaining}` : '—'}
        </div>
      </div>
    </Link>
  );
}

/** Preview colecții: pastile „nume · număr". Ascuns dacă nu are colecții. */
function CollectionsPreview() {
  const { t } = useTranslation();

  const collections = useQuery({
    queryKey: listsKeys.collections(),
    queryFn: ({ signal }) => collectionsRepository.mine(signal),
  });

  if (!collections.data || collections.data.length === 0) return null;

  return (
    <section className="mt-6">
      <h2 className="font-semibold">{t('collectionsTitle')}</h2>
      <div className="mt-2.5 flex flex-wrap gap-[7px]">
        {collections.data.slice(0, 6).map((collection) => (
          <Link
            key={collection.id}
            to={`/collections/${collection.id}`}
            className="rounded-full border border-border px-3 py-1 text-xs text-muted-foreground hover:bg-muted"
          >
            {collection.name} · {collection.bookCount}
          </Link>
        ))}
      </div>
    </section>
  );
}

/**
 * „Activitate recentă": ultimele patru cărți adăugate în bibliotecă. Text la
 * stânga, vârstă relativă la dreapta - format compact, ca un timeline.
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
    <section className="mt-6">
      <h2 className="font-semibold">{t('profileRecentActivity')}</h2>
      <ul className="mt-2.5 flex flex-col gap-2.5">
        {events.map((item) => (
          <li key={item.id} className="flex items-center gap-3 text-[12.5px]">
            <span className="min-w-0 flex-1 truncate text-muted-foreground">
              {t('profileActivityAdded')} <span className="text-foreground">{item.book.title}</span>
            </span>
            <span className="shrink-0 text-xs text-muted-foreground">
              {relativeAge(item.createdAt)}
            </span>
          </li>
        ))}
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
 * Coloana din dreapta, doar pe desktop. Fiecare card e independent: dacă unul
 * n-are date, arată starea goală, restul rămân neatinse.
 */
function SideCards({ me }: { me: AppUser }) {
  const { t, i18n } = useTranslation();

  const wishlist = useQuery({
    queryKey: listsKeys.wishlist(),
    queryFn: ({ signal }) => wishlistRepository.list(signal),
  });

  const shelf = useQuery({
    queryKey: booksKeys.myLibrary(),
    queryFn: ({ signal }) => booksRepository.getMyLibrary(signal),
  });

  const bio = me.bio?.trim();
  const genres = me.readingStats?.topGenres?.slice(0, 3) ?? [];
  const finishedCount = me.readingStats?.totalListed ?? (shelf.data?.length ?? 0);

  return (
    <>
      <Card>
        <div className="flex items-start gap-2">
          <h2 className="min-w-0 flex-1 font-semibold">{t('profileAboutMe')}</h2>
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

      <Card>
        <h2 className="mb-3 font-semibold">{t('profileStatsTitle')}</h2>
        <div className="grid grid-cols-2 gap-2">
          <StatTile value={finishedCount} label={t('profileStatBooksRead')} />
          <StatTile value={me.booksExchangedCount} label={t('profileStatSwaps')} />
          <StatTile value={me.booksSharedCount} label={t('profileStatBooksShared')} />
          <StatTile value={wishlist.data?.length ?? 0} label={t('profileStatWishlisted')} />
        </div>
      </Card>

      <Card>
        <h2 className="mb-3 font-semibold">{t('profileTopGenresTitle')}</h2>
        {genres.length === 0 ? (
          <p className="flex items-start gap-2 text-[13px] text-muted-foreground">
            <BookOpen size={18} className="mt-0.5 shrink-0" />
            {t('profileTopGenresEmpty')}
          </p>
        ) : (
          <ul className="flex flex-col gap-2">
            {genres.map((genre: GenreCount) => (
              <li key={genre.genre} className="flex items-center justify-between gap-3">
                <span className="min-w-0 truncate">{genre.genre}</span>
                <span className="shrink-0 text-muted-foreground">{genre.count}</span>
              </li>
            ))}
          </ul>
        )}
      </Card>
    </>
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

function StatTile({ value, label }: { value: number; label: string }) {
  return (
    <div className="rounded-[12px] bg-muted/50 p-3 text-center">
      <p className="font-display text-xl font-bold">{value}</p>
      <p className="text-xs text-muted-foreground">{label}</p>
    </div>
  );
}
