import { useState, type FormEvent } from 'react';
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { Link, useParams } from 'react-router-dom';
import { useTranslation } from 'react-i18next';
import { ScreenHeader } from '@/components/layout/ScreenHeader';
import { Eye } from 'lucide-react';
import { auctionsRepository, workKeys } from './workRepository';
import { BookCover } from '@/components/ui/BookCover';
import { Avatar } from '@/components/ui/Avatar';
import { Button, ErrorNotice, Field, Spinner } from '@/components/ui';
import { useToast } from '@/components/ui/Toast';
import { formatRelativeTime } from '@/lib/utils/time';
import { toNumber } from '@/types/models';

/** Pasul minim peste prețul curent, ca în Flutter. */
const MIN_INCREMENT = 1;

export function AuctionDetailScreen() {
  const { id = '' } = useParams();
  const { t, i18n } = useTranslation();
  const queryClient = useQueryClient();
  const toast = useToast();
  const [amount, setAmount] = useState('');
  const [error, setError] = useState<string | null>(null);

  const auction = useQuery({
    queryKey: workKeys.auction(id),
    queryFn: ({ signal }) => auctionsRepository.get(id, signal),
    enabled: !!id,
    // O licitație e date care se schimbă sub tine. 15s: destul cât să vezi
    // ofertele altora fără să bombardezi backendul.
    refetchInterval: 15_000,
  });

  const bid = useMutation({
    mutationFn: (value: number) => auctionsRepository.bid(id, value),
    onSuccess: () => {
      void queryClient.invalidateQueries({ queryKey: workKeys.auction(id) });
      setAmount('');
      toast.show(t('auctionBidPlaced'));
    },
    onError: () => toast.show(t('auctionGenericError'), 'danger'),
  });

  const watch = useMutation({
    mutationFn: () => auctionsRepository.toggleWatch(id),
    onSuccess: () => queryClient.invalidateQueries({ queryKey: workKeys.auction(id) }),
  });

  const header = <ScreenHeader title={t('auctionTitle')} back="/exchanges" />;

  if (auction.isPending) {
    return (
      <div className="flex min-h-dvh items-center justify-center text-accent">
        {header}
        <Spinner size={28} />
      </div>
    );
  }

  if (auction.isError) {
    return (
      <div className="mx-auto max-w-2xl p-6">
        {header}
        <ErrorNotice message={t('auctionGenericError')} onRetry={() => void auction.refetch()} />
      </div>
    );
  }

  const data = auction.data;
  const current = toNumber(data.currentPrice) ?? 0;
  const minBid = current + MIN_INCREMENT;
  const buyNow = toNumber(data.buyNowPrice);
  const ended = data.status !== 'ACTIVE' || new Date(data.endsAt) <= new Date();

  function onBid(event: FormEvent) {
    event.preventDefault();
    const value = Number(amount);
    // `Number('')` dă 0, deci verificăm explicit șirul gol - altfel o ofertă
    // goală ar fi trimisă ca 0 și respinsă cu un mesaj derutant.
    if (!amount.trim() || !Number.isFinite(value) || value < minBid) {
      setError(t('addBookInvalidPrice'));
      return;
    }
    setError(null);
    bid.mutate(value);
  }

  return (
    <div className="mx-auto w-full max-w-[680px] px-5 pb-16 pt-2 min-[900px]:px-8">
      {header}
      {data.userBook && (
        <section className="mb-4 flex items-center gap-3 rounded-[16px] border border-border bg-card p-4">
          <div className="h-[80px] w-[58px] shrink-0 overflow-hidden rounded-lg bg-muted">
            <BookCover
              url={data.userBook.book.coverUrl}
              fallbackUrl={data.userBook.mainPhotoUrl}
              title={data.userBook.book.title}
            />
          </div>
          <div className="min-w-0 flex-1">
            <Link
              to={`/books/${data.userBook.id}`}
              className="truncate font-semibold hover:underline"
            >
              {data.userBook.book.title}
            </Link>
            {data.userBook.book.author && (
              <p className="truncate text-sm text-muted-foreground">
                {data.userBook.book.author}
              </p>
            )}
          </div>
        </section>
      )}

      <section className="mb-4 rounded-[16px] border border-border bg-card p-5">
        <p className="text-sm text-muted-foreground">{t('auctionCurrentPrice')}</p>
        <p className="font-display text-3xl font-bold text-accent">
          {t('priceLei', { amount: current })}
        </p>

        <p className="mt-2 text-sm">
          {ended ? (
            <span className="font-medium text-muted-foreground">
              {data.highestBidder ? t('auctionEndedWithWinner') : t('auctionEndedNoWinner')}
            </span>
          ) : (
            <span className="text-warning">{formatTimeLeft(data.endsAt, t)}</span>
          )}
        </p>

        {data.reservePrice !== null && (
          <p className="mt-1 text-sm text-muted-foreground">
            {t(data.reserveMet ? 'auctionReserveMet' : 'auctionReserveNotMet')}
          </p>
        )}

        {buyNow !== null && (
          <p className="mt-1 text-sm text-muted-foreground">
            {t('priceLei', { amount: buyNow })}
          </p>
        )}

        <div className="mt-3 flex flex-wrap items-center gap-4 text-sm text-muted-foreground">
          <span className="flex items-center gap-1">
            <Eye size={14} />
            {data.watchersCount}
          </span>
          <span>
            {data.bids?.length ?? 0} {t('auctionBidsCount')}
          </span>
        </div>

        {!ended && (
          <form onSubmit={onBid} className="mt-4 flex flex-col gap-3">
            <Field
              label={t('auctionBidAmountLabel', { amount: minBid })}
              name="amount"
              type="number"
              inputMode="decimal"
              min={minBid}
              value={amount}
              error={error}
              onChange={(event) => {
                setAmount(event.target.value);
                setError(null);
              }}
            />
            <div className="flex flex-wrap gap-2">
              <Button type="submit" loading={bid.isPending}>
                {t('auctionPlaceBid')}
              </Button>
              <Button
                type="button"
                variant="outline"
                loading={watch.isPending}
                onClick={() => watch.mutate()}
              >
                {t('auctionWatch')}
              </Button>
            </div>
          </form>
        )}
      </section>

      <section>
        <h2 className="mb-3 font-display text-lg font-bold">{t('auctionBidHistory')}</h2>
        {!data.bids || data.bids.length === 0 ? (
          <p className="py-8 text-center text-muted-foreground">{t('auctionNoBidsYet')}</p>
        ) : (
          <ul className="flex flex-col gap-2">
            {data.bids.map((entry) => {
              // `label` e pseudonimul anonimizat pe care îl trimite backendul
              // („Ofertant 3"): identitatea celorlalți licitatori nu se
              // dezvăluie cât timp licitația e deschisă.
              const name = entry.bidder.label ?? entry.bidder.name ?? t('commonUnknownUser');
              return (
                <li
                  key={entry.id}
                  className="flex items-center gap-3 rounded-[16px] border border-border bg-card p-3"
                >
                  <Avatar src={entry.bidder.profileImage} name={name} size={32} />
                  <span className="min-w-0 flex-1 truncate">{name}</span>
                  <span className="shrink-0 font-bold text-accent">
                    {t('priceLei', { amount: toNumber(entry.amount) ?? 0 })}
                  </span>
                  <span className="shrink-0 text-xs text-muted-foreground">
                    {formatRelativeTime(entry.createdAt, i18n.language)}
                  </span>
                </li>
              );
            })}
          </ul>
        )}
      </section>
    </div>
  );
}

/**
 * Cât mai e până la final, în unitatea cea mai mare care are sens. Flutter are
 * trei chei separate (zile / ore / minute), nu una parametrizată.
 */
function formatTimeLeft(endsAt: string, t: (key: string, params?: Record<string, unknown>) => string): string {
  const msLeft = new Date(endsAt).getTime() - Date.now();
  if (msLeft <= 0) return t('auctionEnded');

  const minutes = Math.floor(msLeft / 60_000);
  if (minutes < 60) return t('auctionEndsInMinutes', { minutes });

  const hours = Math.floor(minutes / 60);
  if (hours < 24) return t('auctionEndsInHours', { hours });

  return t('auctionEndsInDays', { days: Math.floor(hours / 24) });
}
