import { useState } from 'react';
import { useQuery } from '@tanstack/react-query';
import { Link, useNavigate } from 'react-router-dom';
import { useTranslation } from 'react-i18next';
import {
  ArrowDownUp,
  CalendarDays,
  Flame,
  Gem,
  Layers,
  ListFilter,
  MapPin,
  Search,
  Sparkles,
  UserRound,
} from 'lucide-react';
import { booksKeys, booksRepository } from './booksRepository';
import { BookRail } from './BookRail';
import { BookCover } from '@/components/ui/BookCover';
import { HeaderAction, ScreenHeader } from '@/components/layout/ScreenHeader';
import { api } from '@/lib/api/client';
import { useAuth } from '@/features/auth/AuthProvider';
import { cn } from '@/lib/utils/cn';

interface UpcomingRelease {
  id: string;
  title: string;
  author: string | null;
  coverUrl: string | null;
  releaseDate: string;
}

/**
 * Descoperă. Port al discover_screen.dart.
 *
 * Fiecare secțiune are propria cerere, lansată în paralel cu celelalte și
 * randată independent: secțiunile lente (recomandările fac muncă reală pe
 * backend) nu mai țin în loc restul ecranului, iar cele goale dispar complet.
 *
 * Ordinea secțiunilor e cea din Flutter și nu e întâmplătoare: întâi ce e al
 * tău (recomandări), apoi ce e al pieței, iar listele de text (căutări, autori)
 * la coadă.
 */
export function DiscoverScreen() {
  const { t } = useTranslation();
  const { user } = useAuth();
  const [sheet, setSheet] = useState<'filter' | 'sort' | null>(null);

  const trending = useQuery({
    queryKey: booksKeys.trending(),
    queryFn: ({ signal }) => booksRepository.getTrendingListings(signal),
  });

  const recommended = useQuery({
    queryKey: booksKeys.recommended(),
    queryFn: ({ signal }) => booksRepository.getRecommended(signal),
    enabled: !!user,
  });

  const nearby = useQuery({
    queryKey: booksKeys.nearby(user?.city ?? ''),
    queryFn: ({ signal }) => booksRepository.getNearbyToday(user!.city!, signal),
    // Fără oraș în profil, endpointul n-are după ce filtra. În Flutter
    // providerul întorcea listă goală; aici pur și simplu nu cerem nimic.
    enabled: !!user?.city,
  });

  const mostWished = useQuery({
    queryKey: booksKeys.mostWished(),
    queryFn: ({ signal }) => booksRepository.getMostWished(signal),
  });

  const hiddenGems = useQuery({
    queryKey: booksKeys.hiddenGems(),
    queryFn: ({ signal }) => booksRepository.getHiddenGems(signal),
  });

  const popularSearches = useQuery({
    queryKey: booksKeys.popularSearches(),
    queryFn: ({ signal }) => booksRepository.getPopularSearches(signal),
  });

  const popularAuthors = useQuery({
    queryKey: booksKeys.popularAuthors(),
    queryFn: ({ signal }) => booksRepository.getPopularAuthors(signal),
  });

  const upcoming = useQuery({
    queryKey: ['upcoming-releases'],
    queryFn: ({ signal }) => api.get<UpcomingRelease[]>('/upcoming-releases', { signal }),
  });

  return (
    <>
      <ScreenHeader
        title={t('navSearch')}
        actions={
          <>
            {/* Intrarea în Book Match stă lângă lupă ca să nu concureze cu bara
                Filtrează/Sortează din corpul ecranului. */}
            <HeaderAction to="/book-match" label={t('bookMatchEntryTooltip')}>
              <Layers size={22} />
            </HeaderAction>
            <HeaderAction to="/browse" label={t('discoverSearchTooltip')}>
              <Search size={22} />
            </HeaderAction>
          </>
        }
      />

      <div className="mx-auto w-full max-w-[1350px] px-4 pb-16 pt-2">
        {/*
          Două butoane, nu o bară de chip-uri: filtrele rapide vechi („doar
          schimb" / „licitații" / hartă) acopereau arbitrar câteva combinații;
          „Filtrează" + „Sortează" le acoperă pe toate, cu aceleași taxonomii.
        */}
        <div className="flex gap-3">
          <BarButton onClick={() => setSheet('filter')}>
            <ListFilter size={20} />
            {t('discoverFilterButton')}
          </BarButton>
          <BarButton onClick={() => setSheet('sort')}>
            <ArrowDownUp size={20} />
            {t('discoverSortButton')}
          </BarButton>
        </div>

        <BookRail
          title={t('discoverRecommendedForYou')}
          items={recommended.data}
          icon={<Sparkles size={22} />}
          tone="accent"
        />

        <BookRail
          title={t('discoverMostLookedFor')}
          items={trending.data}
          loading={trending.isPending}
          icon={<Flame size={22} />}
          tone="accent"
        />

        <BookRail
          title={
            user?.city ? `${t('discoverNearYou')} · ${user.city}` : t('discoverNearYou')
          }
          items={nearby.data}
          icon={<MapPin size={22} />}
          tone="primary"
        />

        <BookRail
          title={t('discoverMostWishedFor')}
          items={mostWished.data}
          loading={mostWished.isPending}
        />

        <BookRail
          title={t('discoverHiddenGems')}
          items={hiddenGems.data}
          loading={hiddenGems.isPending}
          icon={<Gem size={22} />}
          tone="accent"
        />

        <ChipRail
          title={t('discoverTopSearches')}
          items={popularSearches.data?.map((stat) => ({
            label: stat.query,
            count: stat.count,
            // Căutarea populară duce în răsfoire cu termenul precompletat, nu
            // într-o listă preconstruită: userul poate apoi rafina filtrele.
            href: `/browse?title=${encodeURIComponent(stat.query)}`,
          }))}
        />

        <ChipRail
          title={t('discoverPopularAuthors')}
          icon={<UserRound size={18} className="text-accent" />}
          items={popularAuthors.data?.map((stat) => ({
            label: stat.author,
            count: stat.count,
            href: `/browse?author=${encodeURIComponent(stat.author)}`,
          }))}
        />

        {upcoming.data && upcoming.data.length > 0 && (
          <section className="mt-10">
            <h2 className="mb-4 flex items-center gap-2 font-display text-lg font-bold">
              <CalendarDays size={18} className="text-accent" />
              {t('homeUpcomingBooks')}
            </h2>
            <ul>
              {upcoming.data.map((release) => (
                <UpcomingRow key={release.id} release={release} />
              ))}
            </ul>
          </section>
        )}
      </div>

      {sheet && <DiscoverSheet mode={sheet} onClose={() => setSheet(null)} />}
    </>
  );
}

function BarButton({ onClick, children }: { onClick: () => void; children: React.ReactNode }) {
  return (
    <button
      onClick={onClick}
      className="flex flex-1 items-center justify-center gap-2 rounded-[12px] border border-border px-4 py-2.5 text-sm font-medium hover:bg-muted"
    >
      {children}
    </button>
  );
}

function UpcomingRow({ release }: { release: UpcomingRelease }) {
  const { i18n } = useTranslation();
  const date = new Intl.DateTimeFormat(i18n.language, {
    day: 'numeric',
    month: 'short',
    year: 'numeric',
  }).format(new Date(release.releaseDate));

  return (
    <li className="flex items-center gap-4 rounded-[12px] px-2 py-2 hover:bg-muted">
      <div className="h-[68px] w-12 shrink-0 overflow-hidden rounded-lg bg-muted">
        <BookCover url={release.coverUrl} title={release.title} />
      </div>
      <div className="min-w-0 flex-1">
        <p className="truncate">{release.title}</p>
        <p className="truncate text-sm text-muted-foreground">
          {[release.author, date].filter(Boolean).join(' · ')}
        </p>
      </div>
      <CalendarDays size={18} className="shrink-0 text-muted-foreground" />
    </li>
  );
}

const LISTING_TYPES = ['swap', 'sale', 'auction', 'donation'] as const;
const LISTING_TYPE_KEYS: Record<(typeof LISTING_TYPES)[number], string> = {
  swap: 'shareListingModeSwap',
  sale: 'shareListingModeSale',
  auction: 'shareListingModeAuction',
  donation: 'shareListingModeDonation',
};

const SORTS = ['popularity', 'recent', 'oldest', 'distance'] as const;
const SORT_KEYS: Record<(typeof SORTS)[number], string> = {
  popularity: 'discoverSortPopular',
  recent: 'discoverSortNewest',
  oldest: 'discoverSortOldest',
  distance: 'discoverSortNearest',
};

/**
 * Foaia de filtrare/sortare. Nu filtrează pe loc: duce rezultatul pe ecranul de
 * răsfoire, singurul cu paginare și filtre reale - exact ca
 * `showDiscoverFilterSheet` / `showDiscoverSortSheet`.
 */
function DiscoverSheet({ mode, onClose }: { mode: 'filter' | 'sort'; onClose: () => void }) {
  const { t } = useTranslation();
  const navigate = useNavigate();
  const [genre, setGenre] = useState<string | null>(null);
  const [listingType, setListingType] = useState<string | null>(null);
  const [sort, setSort] = useState<string>('popularity');

  const genres = useQuery({
    queryKey: booksKeys.genres(),
    queryFn: ({ signal }) => booksRepository.getGenres(signal),
  });

  function apply() {
    const params = new URLSearchParams();
    if (genre) params.set('genre', genre);
    if (mode === 'filter') {
      if (listingType) params.set('listingType', listingType);
    } else if (sort !== 'popularity') {
      params.set('sort', sort);
    }
    onClose();
    void navigate(`/browse${params.size > 0 ? `?${params}` : ''}`);
  }

  return (
    <div className="fixed inset-0 z-50 flex items-end justify-center min-[560px]:items-center">
      <button aria-label={t('commonCancel')} onClick={onClose} className="absolute inset-0 bg-black/50" />

      <div className="relative max-h-[85dvh] w-full max-w-[520px] overflow-y-auto rounded-t-[20px] bg-card p-5 min-[560px]:rounded-[20px]">
        <h2 className="mb-4 font-display text-lg font-bold">
          {t(mode === 'filter' ? 'filtersTitle' : 'discoverSortTitle')}
        </h2>

        <SheetLabel>{t(mode === 'filter' ? 'discoverFilterCategory' : 'discoverSortGenre')}</SheetLabel>
        <ChoiceChips
          options={(genres.data ?? []).map((item) => ({ value: item.genre, label: item.genre }))}
          selected={genre}
          onSelect={setGenre}
        />

        {mode === 'filter' ? (
          <>
            <SheetLabel>{t('discoverFilterListingType')}</SheetLabel>
            <ChoiceChips
              options={LISTING_TYPES.map((value) => ({ value, label: t(LISTING_TYPE_KEYS[value]) }))}
              selected={listingType}
              onSelect={setListingType}
            />
          </>
        ) : (
          <>
            <SheetLabel>{t('discoverSortDate')}</SheetLabel>
            <div className="flex flex-col">
              {SORTS.map((value) => (
                <label key={value} className="flex cursor-pointer items-center gap-3 py-2.5">
                  <input
                    type="radio"
                    name="discover-sort"
                    checked={sort === value}
                    onChange={() => setSort(value)}
                    className="size-4 accent-[var(--ss-accent)]"
                  />
                  {t(SORT_KEYS[value])}
                </label>
              ))}
            </div>
          </>
        )}

        <div className="mt-5 flex justify-end gap-2">
          <button onClick={onClose} className="rounded-[12px] px-4 py-2.5 text-sm hover:bg-muted">
            {t('commonCancel')}
          </button>
          <button
            onClick={apply}
            className="rounded-[12px] bg-primary px-5 py-2.5 text-sm font-bold text-primary-foreground"
          >
            {t('filtersApply')}
          </button>
        </div>
      </div>
    </div>
  );
}

function SheetLabel({ children }: { children: React.ReactNode }) {
  return (
    <p className="mb-2 mt-4 text-[11px] font-semibold uppercase tracking-[0.1em] text-muted-foreground">
      {children}
    </p>
  );
}

function ChoiceChips({
  options,
  selected,
  onSelect,
}: {
  options: Array<{ value: string; label: string }>;
  selected: string | null;
  onSelect: (value: string | null) => void;
}) {
  return (
    <div className="flex flex-wrap gap-2">
      {options.map((option) => (
        <button
          key={option.value}
          // Re-apăsarea deselectează: altfel, odată ales un gen, n-ar mai exista
          // nicio cale de a reveni la „toate".
          onClick={() => onSelect(selected === option.value ? null : option.value)}
          className={cn(
            'rounded-full border px-4 py-2 text-sm transition',
            selected === option.value
              ? 'border-accent bg-accent/15 font-semibold text-accent'
              : 'border-border hover:bg-muted',
          )}
        >
          {option.label}
        </button>
      ))}
    </div>
  );
}

/**
 * Rând de pastile (căutări populare, autori). Aceeași regulă ca la BookRail:
 * dispare complet când e gol.
 */
function ChipRail({
  title,
  items,
  icon,
}: {
  title: string;
  items: Array<{ label: string; count: number; href: string }> | undefined;
  icon?: React.ReactNode;
}) {
  if (!items || items.length === 0) return null;

  return (
    <section className="mt-10">
      <h2 className="mb-4 flex items-center gap-2 font-display text-lg font-bold">
        {icon}
        {title}
      </h2>
      <div className="flex flex-wrap gap-2">
        {items.map((item) => (
          <Link
            key={item.href}
            to={item.href}
            // `rounded-full`, nu un radius fix: e aceeași formă de pastilă
            // (StadiumBorder) folosită de toate chip-urile din aplicație.
            className="flex items-center gap-2 rounded-full border border-border px-4 py-2 text-sm hover:bg-muted"
          >
            <span className="max-w-[220px] truncate">{item.label}</span>
            <span className="text-xs text-muted-foreground">{item.count}</span>
          </Link>
        ))}
      </div>
    </section>
  );
}
