import { useEffect, useMemo, useRef, useState } from 'react';
import { useInfiniteQuery, useQuery } from '@tanstack/react-query';
import { useSearchParams } from 'react-router-dom';
import { useTranslation } from 'react-i18next';
import { ScreenHeader, HeaderAction } from '@/components/layout/ScreenHeader';
import { Map as MapIcon, Search, SlidersHorizontal, X } from 'lucide-react';
import { booksKeys, booksRepository, type BrowseParams } from './booksRepository';
import { BookCard } from './BookCard';
import { BookGrid } from './BookGrid';
import { Button, ErrorNotice, Spinner } from '@/components/ui';
import { useAuth } from '@/features/auth/AuthProvider';
import { useDocumentMeta } from '@/lib/seo/useDocumentMeta';
import { BROWSE_META } from '@/lib/seo/routes';
import { cn } from '@/lib/utils/cn';

const PAGE_SIZE = 24;

const SORT_OPTIONS = [
  { value: 'popularity', labelKey: 'discoverSortPopular' },
  { value: 'recent', labelKey: 'discoverSortNewest' },
  { value: 'oldest', labelKey: 'discoverSortOldest' },
  { value: 'distance', labelKey: 'discoverSortNearest' },
] as const;

const LISTING_TYPES = [
  { value: 'swap', labelKey: 'filtersListingTypeSwap' },
  { value: 'sale', labelKey: 'filtersListingTypeSale' },
  { value: 'auction', labelKey: 'filtersListingTypeAuction' },
] as const;

const CONDITIONS = [
  { value: 'NOUA', labelKey: 'bookConditionNew' },
  { value: 'FOARTE_BUNA', labelKey: 'bookConditionVeryGood' },
  { value: 'BUNA', labelKey: 'bookConditionGood' },
  { value: 'ACCEPTABILA', labelKey: 'bookConditionAcceptable' },
] as const;

/**
 * Răsfoirea cu filtre. Port al browse_screen.dart + browse_filters_sheet.dart.
 *
 * Filtrele trăiesc în QUERY STRING, nu în state local. E diferența practică
 * față de Flutter, unde erau argumente de rută: aici o căutare filtrată devine
 * un link care poate fi salvat la favorite, trimis altcuiva sau redeschis cu
 * butonul de back al browserului. Pe web ăsta e comportamentul așteptat, iar
 * ecranul primea oricum deja parametri din Descoperă.
 */
export function BrowseScreen() {
  const { t } = useTranslation();
  const { user } = useAuth();
  // Traduse, din același motiv ca la PublicLandingScreen: serverul livrează
  // deja pagina în limba vizitatorului, iar o constantă românească aici ar
  // răsturna titlul din tab înapoi pe română după încărcare.
  useDocumentMeta({
    ...BROWSE_META,
    title: t('seoBrowseTitle'),
    description: t('seoBrowseDescription'),
  });
  const [params, setParams] = useSearchParams();
  const [filtersOpen, setFiltersOpen] = useState(false);

  // Câmpul de căutare e „necontrolat" față de URL: scrisul nu trebuie să
  // rescrie adresa la fiecare tastă (ar umple istoricul browserului cu zeci de
  // intrări și ar lansa o cerere per literă). Se sincronizează la submit.
  const [titleDraft, setTitleDraft] = useState(params.get('title') ?? '');
  useEffect(() => {
    setTitleDraft(params.get('title') ?? '');
  }, [params]);

  const filters = useMemo<BrowseParams>(() => {
    const sort = params.get('sort') ?? undefined;
    return {
      title: params.get('title') ?? undefined,
      author: params.get('author') ?? undefined,
      genre: params.get('genre') ?? undefined,
      language: params.get('language') ?? undefined,
      city: params.get('city') ?? undefined,
      condition: params.get('condition') ?? undefined,
      listingType: params.get('listingType') ?? undefined,
      sort,
      // Sortarea după distanță are nevoie de un oraș de referință. Fără el,
      // backendul n-are de unde măsura și întoarce ordinea implicită - deci
      // userul ar alege „cele mai apropiate" și n-ar vedea nicio schimbare.
      fromCity: sort === 'distance' ? (user?.city ?? undefined) : undefined,
    };
  }, [params, user?.city]);

  const genres = useQuery({
    queryKey: booksKeys.genres(),
    queryFn: ({ signal }) => booksRepository.getGenres(signal),
    // Lista de genuri se schimbă rar; o ținem proaspătă o oră ca deschiderea
    // repetată a panoului de filtre să nu o ceară de fiecare dată.
    staleTime: 60 * 60 * 1000,
  });

  const results = useInfiniteQuery({
    queryKey: booksKeys.browse({ ...filters, limit: PAGE_SIZE }),
    initialPageParam: 0,
    queryFn: ({ pageParam, signal }) =>
      booksRepository.browse({ ...filters, limit: PAGE_SIZE, offset: pageParam }, signal),
    getNextPageParam: (lastPage, allPages) => {
      const loaded = allPages.reduce((sum, page) => sum + page.items.length, 0);
      // `total` vine de la backend; fără comparația asta, scroll-ul ar cere la
      // nesfârșit pagini goale după ultima.
      return loaded < lastPage.total ? loaded : undefined;
    },
  });

  const items = results.data?.pages.flatMap((page) => page.items) ?? [];
  const total = results.data?.pages[0]?.total ?? 0;

  function updateFilter(key: string, value: string | undefined) {
    const next = new URLSearchParams(params);
    if (value) next.set(key, value);
    else next.delete(key);
    // `replace`, nu push: fiecare bifă de filtru ar adăuga altfel o intrare în
    // istoric, iar butonul de back ar trebui apăsat de zece ori ca să iasă.
    setParams(next, { replace: true });
  }

  const activeFilterCount = ['author', 'genre', 'language', 'city', 'condition', 'listingType']
    .filter((key) => params.get(key))
    .length;

  const header = (
    <ScreenHeader
      title={t('browseTitle')}
      back
      actions={
        <HeaderAction to="/map" label={t('browseMapTooltip')}>
          <MapIcon size={22} />
        </HeaderAction>
      }
    />
  );

  return (
    <div className="mx-auto w-full max-w-[1200px] px-5 pb-16 pt-2 min-[900px]:px-8">
      {header}
      <div className="mb-6 flex flex-wrap gap-3">
        <form
          onSubmit={(event) => {
            event.preventDefault();
            updateFilter('title', titleDraft.trim() || undefined);
          }}
          className="flex min-w-[240px] flex-1 items-center gap-2 rounded-[16px] bg-muted px-4"
        >
          <Search size={18} className="shrink-0 text-muted-foreground" />
          <input
            value={titleDraft}
            onChange={(event) => setTitleDraft(event.target.value)}
            placeholder={t('browseSearchHint')}
            aria-label={t('browseSearchHint')}
            className="w-full bg-transparent py-4 text-foreground placeholder:text-muted-foreground focus:outline-none"
          />
          {titleDraft && (
            <button
              type="button"
              aria-label={t('filtersReset')}
              onClick={() => {
                setTitleDraft('');
                updateFilter('title', undefined);
              }}
              className="shrink-0 text-muted-foreground hover:text-foreground"
            >
              <X size={18} />
            </button>
          )}
        </form>

        <button
          onClick={() => setFiltersOpen((open) => !open)}
          className={cn(
            'flex items-center gap-2 rounded-[12px] border border-border px-4 py-2.5 text-sm font-medium hover:bg-muted',
            filtersOpen && 'bg-muted',
          )}
        >
          <SlidersHorizontal size={16} />
          {t('filtersTitle')}
          {activeFilterCount > 0 && (
            <span className="rounded-full bg-accent px-1.5 text-[11px] font-bold text-accent-foreground">
              {activeFilterCount}
            </span>
          )}
        </button>
      </div>

      {filtersOpen && (
        <div className="mb-6 rounded-[16px] border border-border bg-card p-5">
          <FilterGroup
            label={t('discoverSortTitle')}
            options={SORT_OPTIONS.map((option) => ({
              value: option.value,
              label: t(option.labelKey),
            }))}
            selected={params.get('sort') ?? 'popularity'}
            onSelect={(value) => updateFilter('sort', value === 'popularity' ? undefined : value)}
          />

          <FilterGroup
            label={t('filtersListingType')}
            options={LISTING_TYPES.map((option) => ({
              value: option.value,
              label: t(option.labelKey),
            }))}
            selected={params.get('listingType')}
            onSelect={(value) => updateFilter('listingType', value)}
            clearable
          />

          <FilterGroup
            label={t('filtersCondition')}
            options={CONDITIONS.map((option) => ({
              value: option.value,
              label: t(option.labelKey),
            }))}
            selected={params.get('condition')}
            onSelect={(value) => updateFilter('condition', value)}
            clearable
            clearLabel={t('filtersAnyCondition')}
          />

          {genres.data && genres.data.length > 0 && (
            <FilterGroup
              label={t('filtersGenre')}
              options={genres.data.slice(0, 24).map((stat) => ({
                value: stat.genre,
                label: stat.genre,
              }))}
              selected={params.get('genre')}
              onSelect={(value) => updateFilter('genre', value)}
              clearable
            />
          )}

          <div className="mt-5 flex justify-end">
            <Button variant="outline" onClick={() => setParams(new URLSearchParams(), { replace: true })}>
              {t('filtersReset')}
            </Button>
          </div>
        </div>
      )}

      {results.isPending ? (
        <div className="flex h-64 items-center justify-center text-accent">
          <Spinner size={28} />
        </div>
      ) : results.isError ? (
        <ErrorNotice message={t('commonGenericError')} onRetry={() => void results.refetch()} />
      ) : items.length === 0 ? (
        <p className="py-16 text-center text-muted-foreground">{t('browseEmpty')}</p>
      ) : (
        <>
          <p className="mb-4 text-sm text-muted-foreground">
            {t('browseResultsCount', { count: total })}
          </p>
          <BookGrid>
            {items.map((item, index) => (
              <BookCard key={item.id} item={item} eager={index < 5} />
            ))}
          </BookGrid>

          <InfiniteScrollSentinel
            hasMore={results.hasNextPage}
            loading={results.isFetchingNextPage}
            onReach={() => void results.fetchNextPage()}
          />
        </>
      )}
    </div>
  );
}

function FilterGroup({
  label,
  options,
  selected,
  onSelect,
  clearable = false,
  clearLabel,
}: {
  label: string;
  options: Array<{ value: string; label: string }>;
  selected: string | null | undefined;
  onSelect: (value: string | undefined) => void;
  clearable?: boolean;
  clearLabel?: string;
}) {
  const { t } = useTranslation();
  return (
    <div className="mb-5 last:mb-0">
      <p className="mb-2 text-xs font-semibold uppercase tracking-wider text-muted-foreground">
        {label}
      </p>
      <div className="flex flex-wrap gap-2">
        {clearable && (
          <Chip active={!selected} onClick={() => onSelect(undefined)}>
            {clearLabel ?? t('filtersAny')}
          </Chip>
        )}
        {options.map((option) => (
          <Chip
            key={option.value}
            active={selected === option.value}
            // Re-clic pe o opțiune activă o deselectează. Fără asta, un filtru
            // pus din greșeală se putea scoate doar prin „Resetează", care
            // șterge și tot restul.
            onClick={() => onSelect(selected === option.value ? undefined : option.value)}
          >
            {option.label}
          </Chip>
        ))}
      </div>
    </div>
  );
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
      className={cn(
        'rounded-full border px-4 py-2 text-sm transition',
        active
          ? 'border-accent bg-accent/15 font-semibold text-accent'
          : 'border-border hover:bg-muted',
      )}
    >
      {children}
    </button>
  );
}

/**
 * Încărcare la scroll prin IntersectionObserver, nu prin ascultarea
 * evenimentului de scroll: observatorul nu rulează cod la fiecare pixel
 * derulat și funcționează identic indiferent de containerul care derulează.
 */
function InfiniteScrollSentinel({
  hasMore,
  loading,
  onReach,
}: {
  hasMore: boolean;
  loading: boolean;
  onReach: () => void;
}) {
  const ref = useRef<HTMLDivElement>(null);

  useEffect(() => {
    const element = ref.current;
    if (!element || !hasMore || loading) return;

    const observer = new IntersectionObserver(
      (entries) => {
        if (entries[0]?.isIntersecting) onReach();
      },
      // `rootMargin` pozitiv: pagina următoare pleacă înainte ca userul să
      // ajungă efectiv la capăt, deci nu vede niciodată o listă care se oprește.
      { rootMargin: '400px' },
    );
    observer.observe(element);
    return () => observer.disconnect();
  }, [hasMore, loading, onReach]);

  if (!hasMore) return null;

  return (
    <div ref={ref} className="flex justify-center py-8 text-accent">
      {loading && <Spinner size={22} />}
    </div>
  );
}
