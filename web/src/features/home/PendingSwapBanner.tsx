import { useQueries } from '@tanstack/react-query';
import { Link } from 'react-router-dom';
import { useTranslation } from 'react-i18next';
import { Handshake, Repeat } from 'lucide-react';
import { useAuth } from '@/features/auth/AuthProvider';
import {
  exchangeKeys,
  exchangesRepository,
  offersRepository,
} from '@/features/exchanges/exchangesRepository';

/**
 * Banda de sus din feed: „ai cereri de schimb" sau „ai un schimb în
 * desfășurare". Port al `_PendingSwapBanner` din home_screen.dart.
 *
 * Cererile PENDING nedecise au prioritate față de un schimb în desfășurare -
 * sunt acțiunea mai urgentă.
 */
export function PendingSwapBanner() {
  const { t } = useTranslation();
  const { user } = useAuth();

  const [received, sent, offersReceived, offersSent] = useQueries({
    queries: [
      {
        queryKey: exchangeKeys.received(),
        queryFn: ({ signal }: { signal: AbortSignal }) => exchangesRepository.received(signal),
        enabled: !!user,
      },
      {
        queryKey: exchangeKeys.sent(),
        queryFn: ({ signal }: { signal: AbortSignal }) => exchangesRepository.sent(signal),
        enabled: !!user,
      },
      {
        queryKey: exchangeKeys.offersReceived(),
        queryFn: ({ signal }: { signal: AbortSignal }) => offersRepository.received(signal),
        enabled: !!user,
      },
      {
        queryKey: exchangeKeys.offersSent(),
        queryFn: ({ signal }: { signal: AbortSignal }) => offersRepository.sent(signal),
        enabled: !!user,
      },
    ],
  });

  const pending = (received.data ?? []).filter((item) => item.status === 'PENDING').length;

  const ongoingExchanges = [
    ...(received.data ?? []).filter((item) => item.status === 'ACCEPTED'),
    ...(sent.data ?? []).filter((item) => item.status === 'ACCEPTED'),
  ];
  // Vânzările cu bani acceptate trec prin același flux „în desfășurare" ca
  // schimburile - vezi ReadyToExchangeScreen.
  const ongoingOffers = [
    ...(offersReceived.data ?? []).filter((item) => item.status === 'ACCEPTED'),
    ...(offersSent.data ?? []).filter((item) => item.status === 'ACCEPTED'),
  ];
  const ongoingCount = ongoingExchanges.length + ongoingOffers.length;

  if (pending === 0 && ongoingCount === 0) return null;

  const urgent = pending > 0;
  const destination = urgent
    ? '/exchanges'
    : ongoingCount === 1
      ? ongoingExchanges.length > 0
        ? `/exchanges/${ongoingExchanges[0].id}/ready`
        : `/offers/${ongoingOffers[0].id}/ready`
      : '/exchanges';

  return (
    <Link
      to={destination}
      className="mb-3 flex items-center gap-3 rounded-[12px] bg-accent/10 px-4 py-3 text-accent hover:bg-accent/15"
    >
      {urgent ? (
        <Repeat size={20} className="shrink-0" />
      ) : (
        <Handshake size={20} className="shrink-0" />
      )}
      <span className="min-w-0 flex-1 text-sm">
        {urgent ? t('homePendingSwapBanner', { count: pending }) : t('homeOngoingExchangeBanner')}
      </span>
      <span className="shrink-0 text-sm font-semibold">{t('homePendingSwapReview')}</span>
    </Link>
  );
}
