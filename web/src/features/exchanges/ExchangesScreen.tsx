import { useState } from 'react';
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { Link } from 'react-router-dom';
import { useTranslation } from 'react-i18next';
import { ScreenHeader } from '@/components/layout/ScreenHeader';
import { FolderTabs } from '@/components/ui/FolderTabs';
import { ArrowRight } from 'lucide-react';
import {
  exchangeKeys,
  exchangesRepository,
  offersRepository,
  type ExchangeRequest,
  type PriceOffer,
} from './exchangesRepository';
import { BookCover } from '@/components/ui/BookCover';
import { Avatar } from '@/components/ui/Avatar';
import { Button, ErrorNotice, Spinner } from '@/components/ui';
import { useAuth } from '@/features/auth/AuthProvider';
import { formatRelativeTime } from '@/lib/utils/time';
import { toNumber } from '@/types/models';
import { cn } from '@/lib/utils/cn';
import { NAME_SLOT, splitAroundName } from '@/lib/i18n/nameSlot';

/**
 * Cele patru tab-uri din exchanges_screen.dart. Cererile de schimb și ofertele
 * cu bani stau separat, nu amestecate într-un „primite": sunt fluxuri diferite
 * (una cere o carte la schimb, cealaltă oferă bani) și se răspunde altfel.
 */
type Tab = 'received' | 'sent' | 'offersReceived' | 'offersSent';

const TAB_LABELS: Record<Tab, string> = {
  received: 'exchangesTabReceived',
  sent: 'exchangesTabSent',
  offersReceived: 'offersTabReceived',
  offersSent: 'offersTabSent',
};

export function ExchangesScreen() {
  const { t, i18n } = useTranslation();
  const { user } = useAuth();
  const queryClient = useQueryClient();
  const [tab, setTab] = useState<Tab>('received');

  const showingOffers = tab === 'offersReceived' || tab === 'offersSent';
  const incoming = tab === 'received' || tab === 'offersReceived';

  const exchanges = useQuery({
    queryKey: incoming ? exchangeKeys.received() : exchangeKeys.sent(),
    queryFn: ({ signal }) =>
      incoming ? exchangesRepository.received(signal) : exchangesRepository.sent(signal),
    enabled: !showingOffers,
  });

  const offers = useQuery({
    queryKey: incoming ? exchangeKeys.offersReceived() : exchangeKeys.offersSent(),
    queryFn: ({ signal }) =>
      incoming ? offersRepository.received(signal) : offersRepository.sent(signal),
    enabled: showingOffers,
  });

  function invalidateAll() {
    void queryClient.invalidateQueries({ queryKey: exchangeKeys.all });
    void queryClient.invalidateQueries({ queryKey: ['offers'] });
  }

  const respond = useMutation({
    mutationFn: ({ id, action }: { id: string; action: 'accept' | 'reject' | 'cancel' }) =>
      action === 'accept'
        ? exchangesRepository.accept(id)
        : action === 'reject'
          ? exchangesRepository.reject(id)
          : exchangesRepository.cancel(id),
    onSuccess: invalidateAll,
  });

  const respondOffer = useMutation({
    mutationFn: ({ id, action }: { id: string; action: 'accept' | 'reject' | 'cancel' }) =>
      action === 'accept'
        ? offersRepository.accept(id)
        : action === 'reject'
          ? offersRepository.reject(id)
          : offersRepository.cancel(id),
    onSuccess: invalidateAll,
  });

  // Filele au coborât din antet în corpul paginii: ca file de dosar, ele
  // delimitează lista de dedesubt, deci trebuie lipite de ea - în antet ar fi
  // rămas un capac fără cutie.
  const header = <ScreenHeader title={t('exchangesTitle')} back />;

  const tabs = (Object.keys(TAB_LABELS) as Tab[]).map((value) => ({
    value,
    label: t(TAB_LABELS[value]),
  }));

  const active = showingOffers ? offers : exchanges;

  if (active.isPending) {
    return (
      <>
        {header}
        <div className="flex min-h-[60vh] items-center justify-center text-accent">
          <Spinner size={28} />
        </div>
      </>
    );
  }

  if (active.isError) {
    return (
      <>
        {header}
        <div className="mx-auto max-w-2xl p-6">
          <ErrorNotice message={t('exchangesLoadError')} onRetry={() => void active.refetch()} />
        </div>
      </>
    );
  }

  const exchangeList = showingOffers ? [] : (exchanges.data ?? []);
  const offerList = showingOffers ? (offers.data ?? []) : [];
  const isEmpty = exchangeList.length === 0 && offerList.length === 0;

  return (
    <div className="mx-auto w-full max-w-[760px] px-5 pb-16 pt-4 min-[900px]:px-8">
      {header}
      <FolderTabs label={t('exchangesTitle')} value={tab} onChange={setTab} tabs={tabs}>
      {isEmpty ? (
        <p className="py-16 text-center text-muted-foreground">
          {t(incoming ? 'exchangesEmptyReceived' : 'exchangesEmptySent')}
        </p>
      ) : (
        <ul className="flex flex-col gap-3">
          {exchangeList.map((exchange) => (
            <li key={exchange.id}>
              <ExchangeCard
                exchange={exchange}
                incoming={incoming}
                locale={i18n.language}
                busy={respond.isPending}
                onRespond={(action) => respond.mutate({ id: exchange.id, action })}
              />
            </li>
          ))}

          {offerList.map((offer) => (
            <li key={offer.id}>
              <OfferCard
                offer={offer}
                incoming={incoming}
                locale={i18n.language}
                busy={respondOffer.isPending}
                onRespond={(action) => respondOffer.mutate({ id: offer.id, action })}
                currentUserId={user?.id}
              />
            </li>
          ))}
        </ul>
      )}
      </FolderTabs>
    </div>
  );
}

function ExchangeCard({
  exchange,
  incoming,
  locale,
  busy,
  onRespond,
}: {
  exchange: ExchangeRequest;
  incoming: boolean;
  locale: string;
  busy: boolean;
  onRespond: (action: 'accept' | 'reject' | 'cancel') => void;
}) {
  const { t } = useTranslation();
  const counterparty = incoming ? exchange.requester : exchange.owner;
  const name = counterparty.name ?? counterparty.username ?? t('commonAnonymousUser');
  const amount = toNumber(exchange.offeredAmount);
  // Titlul cartii oferite, nu al celei cerute: „Ofera: X + inca 2 carti".
  const offeredTitle = exchange.offeredBook?.book.title ?? '';

  return (
    <article className="rounded-[16px] border border-border bg-card p-4">
      <header className="mb-3 flex items-center gap-2">
        <Avatar src={counterparty.profileImage} name={name} size={28} />
        <p className="min-w-0 flex-1 truncate text-sm">
          <NamedPhrase
            phrase={t(incoming ? 'exchangeRequestedBy' : 'exchangeFrom', { name: NAME_SLOT })}
            name={name}
            userId={counterparty.id}
          />
        </p>
        <StatusBadge status={exchange.status} />
      </header>

      {/* Cele două cărți, cu săgeata între ele: ce se oferă -> ce se cere. */}
      <div className="flex items-center gap-3">
        {exchange.offeredBook ? (
          <BookThumb book={exchange.offeredBook} />
        ) : (
          <div className="flex h-[72px] w-[52px] shrink-0 items-center justify-center rounded-lg border border-dashed border-border text-xs text-muted-foreground">
            {amount !== null ? t('priceLei', { amount }) : '—'}
          </div>
        )}

        <ArrowRight size={18} className="shrink-0 text-muted-foreground" />
        <BookThumb book={exchange.requestedBook} />

        <div className="min-w-0 flex-1">
          <p className="truncate font-semibold">{exchange.requestedBook.book.title}</p>
          <p className="text-xs text-muted-foreground">
            {exchange.additionalOfferedBooks.length > 0
              ? t('exchangeOffersBookBundle', {
                  title: offeredTitle,
                  count: exchange.additionalOfferedBooks.length,
                })
              : exchange.offeredBook
                ? t('exchangeOffersBook', { title: offeredTitle })
                : t('exchangeOffersAmount', { amount: amount ?? 0 })}
          </p>
          <p className="mt-1 text-xs text-muted-foreground">
            {formatRelativeTime(exchange.createdAt, locale)}
          </p>
        </div>
      </div>

      {exchange.message && (
        <p className="mt-3 whitespace-pre-line rounded-[12px] bg-muted p-3 text-sm">
          {exchange.message}
        </p>
      )}

      <footer className="mt-4 flex flex-wrap gap-2">
        {/* Acțiunile depind de stare ȘI de partea pe care ești: doar cel care
            PRIMEȘTE cererea poate accepta sau refuza; cel care a trimis-o o
            poate doar anula. */}
        {exchange.status === 'PENDING' && incoming && (
          <>
            <Button loading={busy} onClick={() => onRespond('accept')}>
              {t('exchangeAccept')}
            </Button>
            <Button variant="outline" loading={busy} onClick={() => onRespond('reject')}>
              {t('exchangeReject')}
            </Button>
          </>
        )}

        {exchange.status === 'PENDING' && !incoming && (
          <Button variant="outline" loading={busy} onClick={() => onRespond('cancel')}>
            {t('exchangeCancelRequest')}
          </Button>
        )}

        {exchange.status === 'ACCEPTED' && (
          <Link
            to={`/exchanges/${exchange.id}/ready`}
            className="rounded-[12px] bg-primary px-6 py-3 text-sm font-bold text-primary-foreground hover:brightness-110"
          >
            {t('exchangeGoToReady')}
          </Link>
        )}
      </footer>
    </article>
  );
}

function OfferCard({
  offer,
  incoming,
  locale,
  busy,
  onRespond,
  currentUserId,
}: {
  offer: PriceOffer;
  incoming: boolean;
  locale: string;
  busy: boolean;
  onRespond: (action: 'accept' | 'reject' | 'cancel') => void;
  currentUserId?: string;
}) {
  const { t } = useTranslation();
  const counterparty = incoming ? offer.buyer : offer.owner;
  const name = counterparty.name ?? counterparty.username ?? t('commonAnonymousUser');
  const amount = toNumber(offer.amount) ?? 0;
  // „Primită" pentru ofertă înseamnă că EU sunt vânzătorul, nu doar că sunt pe
  // tabul „primite" - lista de oferte și cea de schimburi au roluri diferite.
  const isSeller = offer.ownerId === currentUserId;

  return (
    <article className="rounded-[16px] border border-border bg-card p-4">
      <header className="mb-3 flex items-center gap-2">
        <Avatar src={counterparty.profileImage} name={name} size={28} />
        <p className="min-w-0 flex-1 truncate text-sm">
          <NamedPhrase
            phrase={t('offerTo', { name: NAME_SLOT })}
            name={name}
            userId={counterparty.id}
          />
        </p>
        <StatusBadge status={offer.status} />
      </header>

      <div className="flex items-center gap-3">
        <BookThumb book={offer.userBook} />
        <div className="min-w-0 flex-1">
          <p className="truncate font-semibold">{offer.userBook.book.title}</p>
          <p className="font-bold text-accent">{t('offerAmountLine', { amount })}</p>
          <p className="mt-1 text-xs text-muted-foreground">
            {formatRelativeTime(offer.createdAt, locale)}
          </p>
        </div>
      </div>

      {offer.message && (
        <p className="mt-3 whitespace-pre-line rounded-[12px] bg-muted p-3 text-sm">
          {offer.message}
        </p>
      )}

      <footer className="mt-4 flex flex-wrap gap-2">
        {offer.status === 'PENDING' && isSeller && (
          <>
            <Button loading={busy} onClick={() => onRespond('accept')}>
              {t('exchangeAccept')}
            </Button>
            <Button variant="outline" loading={busy} onClick={() => onRespond('reject')}>
              {t('exchangeReject')}
            </Button>
          </>
        )}

        {offer.status === 'PENDING' && !isSeller && (
          <Button variant="outline" loading={busy} onClick={() => onRespond('cancel')}>
            {t('offerCancel')}
          </Button>
        )}

        {offer.status === 'ACCEPTED' && (
          <Link
            to={`/offers/${offer.id}/ready`}
            className="rounded-[12px] bg-primary px-6 py-3 text-sm font-bold text-primary-foreground hover:brightness-110"
          >
            {t('exchangeGoToReady')}
          </Link>
        )}
      </footer>
    </article>
  );
}

function BookThumb({ book }: { book: { book: { title: string; coverUrl: string | null }; mainPhotoUrl: string | null } }) {
  return (
    <div className="h-[72px] w-[52px] shrink-0 overflow-hidden rounded-lg bg-muted">
      <BookCover
        url={book.book.coverUrl}
        fallbackUrl={book.mainPhotoUrl}
        title={book.book.title}
      />
    </div>
  );
}

const STATUS_TONES: Record<string, string> = {
  PENDING: 'text-warning',
  ACCEPTED: 'text-success',
  COMPLETED: 'text-success',
  REJECTED: 'text-danger-text',
  CANCELLED: 'text-muted-foreground',
  EXPIRED: 'text-muted-foreground',
};

function StatusBadge({ status }: { status: string }) {
  return (
    <span
      className={cn(
        'shrink-0 rounded-full border border-border px-2.5 py-0.5 text-[11px] font-medium',
        STATUS_TONES[status] ?? 'text-muted-foreground',
      )}
    >
      {status}
    </span>
  );
}

/**
 * „Cerută de <nume>", cu numele ca link către profil. Fraza vine întreagă din
 * traducere, tăiată în jurul numelui - vezi nameSlot.ts pentru de ce nu putem
 * folosi cheia drept prefix.
 */
function NamedPhrase({
  phrase,
  name,
  userId,
}: {
  phrase: string;
  name: string;
  userId: string;
}) {
  const [before, after] = splitAroundName(phrase);

  return (
    <>
      <span className="text-muted-foreground">{before}</span>
      <Link to={`/users/${userId}`} className="font-semibold hover:underline">
        {name}
      </Link>
      <span className="text-muted-foreground">{after}</span>
    </>
  );
}
