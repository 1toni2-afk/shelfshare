import { useEffect, useState } from 'react';
import { useMutation, useQuery } from '@tanstack/react-query';
import { useTranslation } from 'react-i18next';
import { Check, Search } from 'lucide-react';
import { api } from '@/lib/api/client';
import { booksRepository } from '@/features/books/booksRepository';
import { ScreenHeader } from '@/components/layout/ScreenHeader';
import { Button, Spinner } from '@/components/ui';
import { useToast } from '@/components/ui/Toast';
import { RequireAdmin } from './AdminScreens';
import { cn } from '@/lib/utils/cn';

interface ListingScoreBreakdown {
  userBookId: string;
  book: { title: string; author: string | null };
  counts: Record<string, number>;
  popularityScore: number;
  exchangePotentialScore: number;
  manualScoreOverride: number | null;
}

/**
 * Cheile de traducere ale evenimentelor. Erau texte românești hardcodate, cu
 * nota „e o unealtă internă, văzută doar de admini" - dar un admin care își
 * pune aplicația pe engleză vedea jumătate de ecran în română, deci excepția
 * costa mai mult decât economisea.
 */
const COUNT_LABEL_KEYS: Record<string, string> = {
  UNIQUE_VIEW: 'adminScoreEventUniqueView',
  RETURN_VISIT: 'adminScoreEventReturnVisit',
  WISHLIST_ADD: 'adminScoreWishlistAdds',
  EXCHANGE_REQUEST: 'adminScoreEventExchangeRequest',
  BUY_OFFER: 'adminScorePriceOffers',
  REVIEW: 'adminScoreEventReview',
};

/**
 * Panou de admin: caută un anunț după titlu, arată breakdown-ul scorului de
 * interes (popularitate + potențial de schimb) și permite suprascrierea
 * manuală a scorului de popularitate. Vezi listing-score.service.ts și
 * AdminService.getListingScore / setListingScoreOverride.
 *
 * Scorul nu e vizibil userilor normali - ecranul ăsta e singurul loc din
 * aplicație unde apare desfășurat.
 */
export function AdminListingScoreScreen() {
  const { t } = useTranslation();
  const toast = useToast();

  const [term, setTerm] = useState('');
  const [query, setQuery] = useState('');
  const [selectedId, setSelectedId] = useState<string | null>(null);
  const [override, setOverride] = useState('');

  // Debounce pe tastare, ca în Flutter (350ms): fiecare literă altfel ar
  // însemna o căutare în catalog.
  useEffect(() => {
    const timer = window.setTimeout(() => setQuery(term.trim()), 350);
    return () => window.clearTimeout(timer);
  }, [term]);

  const results = useQuery({
    queryKey: ['admin', 'listing-score', 'search', query],
    queryFn: ({ signal }) => booksRepository.browse({ title: query, limit: 20 }, signal),
    enabled: query.length >= 2,
  });

  const score = useQuery({
    queryKey: ['admin', 'listing-score', selectedId],
    queryFn: ({ signal }) =>
      api.get<ListingScoreBreakdown>(`/admin/listings/${selectedId}/score`, { signal }),
    enabled: !!selectedId,
  });

  // Câmpul urmează scorul încărcat, nu invers: altfel, la selectarea altui
  // anunț, ar rămâne în el valoarea celui dinainte.
  useEffect(() => {
    setOverride(score.data?.manualScoreOverride?.toString() ?? '');
  }, [score.data]);

  const save = useMutation({
    mutationFn: () => {
      const raw = override.trim();
      // Gol = fără override, se revine la scorul calculat.
      const value = raw === '' ? null : Number(raw);
      return api.put<ListingScoreBreakdown>(`/admin/listings/${selectedId}/score-override`, {
        score: value,
      });
    },
    onSuccess: (updated) => {
      score.refetch().catch(() => {});
      setOverride(updated.manualScoreOverride?.toString() ?? '');
      toast.show(
        t(
          updated.manualScoreOverride === null
            ? 'adminScoreOverrideRemoved'
            : 'adminScoreOverrideSaved',
        ),
      );
    },
    onError: () => toast.show(t('adminScoreSaveError'), 'danger'),
  });

  function submit() {
    const raw = override.trim();
    if (raw !== '' && Number.isNaN(Number(raw))) {
      toast.show(t('adminScoreMustBeNumber'), 'danger');
      return;
    }
    save.mutate();
  }

  const breakdown = score.data;

  return (
    <RequireAdmin>
      <div className="mx-auto w-full max-w-[680px] px-5 pb-16 pt-4 min-[900px]:px-8">
        <ScreenHeader title={t('adminScoreTitle')} back="/admin" />

        <p className="mb-4 text-sm text-muted-foreground">
          {t('adminScoreIntro')}
        </p>

        <div className="mb-3 flex items-center gap-2 rounded-[16px] bg-muted px-4">
          <Search size={18} className="shrink-0 text-muted-foreground" />
          <input
            value={term}
            onChange={(event) => setTerm(event.target.value)}
            placeholder={t('adminScoreSearchHint')}
            aria-label={t('adminScoreSearchLabel')}
            className="w-full bg-transparent py-3.5 text-foreground placeholder:text-muted-foreground focus:outline-none"
          />
          {results.isFetching && <Spinner size={16} />}
        </div>

        {query.length >= 2 && results.isSuccess && results.data.items.length === 0 ? (
          <p className="text-muted-foreground">{t('adminScoreNoResults')}</p>
        ) : (
          <ul>
            {(results.data?.items ?? []).map((item) => (
              <li key={item.id}>
                <button
                  onClick={() => setSelectedId(item.id)}
                  className={cn(
                    'flex w-full items-center gap-3 rounded-[12px] px-2 py-2 text-left hover:bg-muted',
                    item.id === selectedId && 'bg-muted',
                  )}
                >
                  <span className="min-w-0 flex-1">
                    <span className="block truncate">{item.book.title}</span>
                    <span className="block truncate text-sm text-muted-foreground">
                      {item.book.author ?? 'Autor necunoscut'}
                    </span>
                  </span>
                  {item.id === selectedId && <Check size={18} className="shrink-0 text-accent" />}
                </button>
              </li>
            ))}
          </ul>
        )}

        <div className="mt-6">
          {!selectedId ? (
            <p className="text-sm text-muted-foreground">{t('adminScorePickOne')}</p>
          ) : score.isPending ? (
            <div className="flex h-40 items-center justify-center text-accent">
              <Spinner size={26} />
            </div>
          ) : score.isError ? (
            <p className="text-sm text-destructive">{t('adminScoreLoadError')}</p>
          ) : breakdown ? (
            <>
              <p className="font-semibold">{breakdown.book.title}</p>
              {breakdown.book.author && (
                <p className="text-sm text-muted-foreground">{breakdown.book.author}</p>
              )}

              <div className="mt-4 flex flex-col gap-2">
                <ScoreTile
                  label={t('adminScorePopularity')}
                  value={breakdown.popularityScore}
                  highlighted={breakdown.manualScoreOverride !== null}
                />
                <ScoreTile
                  label={t('adminScoreSwapPotential')}
                  value={breakdown.exchangePotentialScore}
                />
              </div>

              <h2 className="mt-5 font-semibold">{t('adminScoreEventsTitle')}</h2>
              {Object.keys(breakdown.counts).length === 0 ? (
                <p className="mt-1 text-sm text-muted-foreground">
                  {t('adminScoreNoEvents')}
                </p>
              ) : (
                <ul className="mt-1">
                  {Object.entries(breakdown.counts).map(([key, value]) => (
                    <li key={key} className="flex items-center justify-between py-0.5">
                      <span>{COUNT_LABEL_KEYS[key] ? t(COUNT_LABEL_KEYS[key]) : key}</span>
                      <span>{value}</span>
                    </li>
                  ))}
                </ul>
              )}

              <h2 className="mt-5 font-semibold">{t('adminScoreOverrideLabel')}</h2>
              <p className="mt-1 text-sm text-muted-foreground">
                {t('adminScoreOverrideHint')}
              </p>
              <input
                value={override}
                onChange={(event) => setOverride(event.target.value)}
                inputMode="decimal"
                placeholder="ex: 87"
                aria-label={t('adminScoreManualLabel')}
                className="mt-2 w-full rounded-[16px] bg-muted px-4 py-3.5 text-foreground placeholder:text-muted-foreground focus:outline-none"
              />
              <Button className="mt-3" onClick={submit} loading={save.isPending}>
                {t('commonSave')}
              </Button>
            </>
          ) : null}
        </div>
      </div>
    </RequireAdmin>
  );
}

function ScoreTile({
  label,
  value,
  highlighted = false,
}: {
  label: string;
  value: number;
  highlighted?: boolean;
}) {
  const { t } = useTranslation();
  return (
    <div
      className={cn(
        'flex items-center justify-between rounded-[16px] border border-border p-4',
        highlighted ? 'bg-primary/[0.08]' : 'bg-card',
      )}
    >
      <span>
        {label}
        {highlighted && (
          <span className="block text-sm text-muted-foreground">{t('adminScoreOverrideActive')}</span>
        )}
      </span>
      <span className="font-display text-xl font-bold">{value.toFixed(1)}</span>
    </div>
  );
}
