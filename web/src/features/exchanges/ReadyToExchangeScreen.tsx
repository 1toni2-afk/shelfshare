import { useState } from 'react';
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { Link, useParams } from 'react-router-dom';
import { useTranslation } from 'react-i18next';
import { ScreenHeader } from '@/components/layout/ScreenHeader';
import { CalendarClock, CheckCircle2, MapPin, Phone, ShieldCheck } from 'lucide-react';
import {
  exchangeKeys,
  exchangesRepository,
  offersRepository,
  type ExchangeRequest,
  type PriceOffer,
} from './exchangesRepository';
import { Avatar } from '@/components/ui/Avatar';
import { BookCover } from '@/components/ui/BookCover';
import { Button, ErrorNotice, Spinner } from '@/components/ui';
import { useToast } from '@/components/ui/Toast';
import { useAuth } from '@/features/auth/AuthProvider';
import { toNumber } from '@/types/models';

/**
 * Pregătirea întâlnirii, folosită ȘI pentru schimburi, ȘI pentru vânzări.
 *
 * Cele două au endpointuri diferite (`/exchanges/:id/...` vs `/offers/:id/...`)
 * dar exact aceiași pași: recomandări de siguranță, contact, întâlnire,
 * confirmarea finalizării de ambele părți. În Flutter erau două ecrane aproape
 * identice; aici e unul singur, parametrizat pe tip.
 */
export function ReadyToExchangeScreen({ kind }: { kind: 'exchange' | 'offer' }) {
  const { id = '' } = useParams();
  const { t } = useTranslation();
  const { user } = useAuth();
  const queryClient = useQueryClient();
  const toast = useToast();

  const [meetingTime, setMeetingTime] = useState('');
  const [meetingLocation, setMeetingLocation] = useState('');

  const isExchange = kind === 'exchange';

  // Tipul e adnotat explicit: din `isExchange ? ... : ...` TypeScript ar
  // deduce `Promise<ExchangeRequest> | Promise<PriceOffer>`, pe care useQuery
  // nu îl acceptă ca funcție de interogare. Uniunea se restrânge mai jos, prin
  // verificări de câmp (`'requestedBook' in data`).
  const deal = useQuery<ExchangeRequest | PriceOffer>({
    queryKey: isExchange ? exchangeKeys.detail(id) : exchangeKeys.offerDetail(id),
    queryFn: ({ signal }) =>
      isExchange ? exchangesRepository.detail(id, signal) : offersRepository.detail(id, signal),
    enabled: !!id,
  });

  function invalidate() {
    void queryClient.invalidateQueries({
      queryKey: isExchange ? exchangeKeys.detail(id) : exchangeKeys.offerDetail(id),
    });
  }

  const act = useMutation({
    mutationFn: async (action: 'safety' | 'contact' | 'done' | 'dispute' | 'meeting' | 'acceptMeeting') => {
      if (isExchange) {
        switch (action) {
          case 'safety':
            return exchangesRepository.acknowledgeSafety(id);
          case 'contact':
            return exchangesRepository.shareContact(id);
          case 'done':
            return exchangesRepository.markDone(id);
          case 'dispute':
            return exchangesRepository.dispute(id);
          case 'acceptMeeting':
            return exchangesRepository.acceptMeeting(id);
          case 'meeting':
            return exchangesRepository.proposeMeeting(id, {
              meetingTime: new Date(meetingTime).toISOString(),
              meetingLocation,
            });
        }
      }
      switch (action) {
        case 'contact':
          return offersRepository.shareContact(id);
        case 'done':
          return offersRepository.markDone(id);
        case 'acceptMeeting':
          return offersRepository.acceptMeeting(id);
        case 'meeting':
          return offersRepository.proposeMeeting(id, {
            meetingTime: new Date(meetingTime).toISOString(),
            meetingLocation,
          });
        default:
          // Ofertele n-au pașii de siguranță și de contestare pe backend.
          throw new Error(t('exchangeOffersActionUnavailable'));
      }
    },
    onSuccess: invalidate,
    onError: () => toast.show(t('commonGenericError'), 'danger'),
  });

  const header = <ScreenHeader title={t('readyTitle')} back="/exchanges" />;

  if (deal.isPending) {
    return (
      <div className="flex min-h-dvh items-center justify-center text-accent">
        {header}
        <Spinner size={28} />
      </div>
    );
  }

  if (deal.isError) {
    return (
      <div className="mx-auto max-w-2xl p-6">
        {header}
        <ErrorNotice message={t('exchangesLoadError')} onRetry={() => void deal.refetch()} />
      </div>
    );
  }

  const data = deal.data;
  const isCompleted = data.status === 'COMPLETED';
  const isCancelled = data.status === 'CANCELLED' || data.status === 'REJECTED';

  // Cine e „celălalt" depinde de rolul meu în tranzacție.
  const counterparty =
    'requester' in data
      ? data.requesterId === user?.id
        ? data.owner
        : data.requester
      : data.buyerId === user?.id
        ? data.owner
        : data.buyer;

  const counterpartyName =
    counterparty.name ?? counterparty.username ?? t('commonAnonymousUser');

  const book = 'requestedBook' in data ? data.requestedBook : data.userBook;

  const iMarkedDone =
    'requesterDoneAt' in data
      ? data.requesterId === user?.id
        ? !!data.requesterDoneAt
        : !!data.ownerDoneAt
      : false;

  return (
    <div className="mx-auto w-full max-w-[680px] px-5 pb-16 pt-2 min-[900px]:px-8">
      {header}
      {isCompleted && (
        <p className="mb-6 rounded-[16px] border border-success/40 bg-success/10 p-4 text-center font-bold text-success">
          {t('dealFinalisedBanner')}
        </p>
      )}
      {isCancelled && (
        <p className="mb-6 rounded-[16px] border border-border bg-muted p-4 text-center font-bold text-muted-foreground">
          {t('dealCancelledBanner')}
        </p>
      )}

      <section className="mb-4 flex items-center gap-3 rounded-[16px] border border-border bg-card p-4">
        <div className="h-[72px] w-[52px] shrink-0 overflow-hidden rounded-lg bg-muted">
          <BookCover
            url={book.book.coverUrl}
            fallbackUrl={book.mainPhotoUrl}
            title={book.book.title}
          />
        </div>
        <div className="min-w-0 flex-1">
          <p className="truncate font-semibold">{book.book.title}</p>
          {'amount' in data && (
            <p className="font-bold text-accent">
              {t('priceLei', { amount: toNumber(data.amount) ?? 0 })}
            </p>
          )}
          <Link
            to={`/users/${counterparty.id}`}
            className="mt-1 flex items-center gap-2 text-sm hover:underline"
          >
            <Avatar src={counterparty.profileImage} name={counterpartyName} size={20} />
            {counterpartyName}
          </Link>
        </div>
      </section>

      {/* Pasul de siguranță există doar pentru schimburi: ofertele n-au
          endpointul `safety-ack` pe backend. */}
      {isExchange && !isCompleted && !isCancelled && (
        <Step
          icon={<ShieldCheck size={18} />}
          title={t('readySafetyTitle')}
          subtitle={t('readySafetySubtitle')}
        >
          <Button variant="outline" loading={act.isPending} onClick={() => act.mutate('safety')}>
            {t('readySafetyAck')}
          </Button>
        </Step>
      )}

      {!isCompleted && !isCancelled && (
        <Step
          icon={<Phone size={18} />}
          title={t('readyContactTitle')}
          subtitle={t('readyContactSubtitle')}
        >
          <Button variant="outline" loading={act.isPending} onClick={() => act.mutate('contact')}>
            {t('readyContactShare')}
          </Button>
        </Step>
      )}

      {!isCompleted && !isCancelled && (
        <Step
          icon={<CalendarClock size={18} />}
          title={t('exchangeScheduleMeeting')}
          subtitle={t('readyMeetingSubtitle')}
        >
          {data.meetingTime ? (
            <div className="flex flex-col gap-3">
              <p className="flex items-center gap-2 text-sm">
                <CalendarClock size={16} className="text-muted-foreground" />
                {new Intl.DateTimeFormat(undefined, {
                  dateStyle: 'medium',
                  timeStyle: 'short',
                }).format(new Date(data.meetingTime))}
              </p>
              {data.meetingLocation && (
                <p className="flex items-center gap-2 text-sm">
                  <MapPin size={16} className="text-muted-foreground" />
                  {data.meetingLocation}
                </p>
              )}
              <Button
                variant="outline"
                loading={act.isPending}
                onClick={() => act.mutate('acceptMeeting')}
              >
                {t('readyMeetingAccept')}
              </Button>
            </div>
          ) : (
            <div className="flex flex-col gap-3">
              <input
                type="datetime-local"
                value={meetingTime}
                onChange={(event) => setMeetingTime(event.target.value)}
                aria-label={t('exchangeScheduleMeeting')}
                className="w-full rounded-[16px] bg-muted px-4 py-3.5 text-foreground focus:outline-none"
              />
              <input
                value={meetingLocation}
                onChange={(event) => setMeetingLocation(event.target.value)}
                placeholder={t('chatSuggestedMeetingPoints')}
                aria-label={t('chatMapLabel')}
                className="w-full rounded-[16px] bg-muted px-4 py-3.5 text-foreground placeholder:text-muted-foreground focus:outline-none"
              />
              <Button
                loading={act.isPending}
                // Ambele câmpuri sunt obligatorii: backendul refuză o
                // propunere fără dată sau fără loc, iar un `new Date('')` ar
                // trimite „Invalid Date" în ISO.
                disabled={!meetingTime || !meetingLocation.trim()}
                onClick={() => act.mutate('meeting')}
              >
                {t('exchangeScheduleMeeting')}
              </Button>
            </div>
          )}
        </Step>
      )}

      {!isCompleted && !isCancelled && (
        <Step
          icon={<CheckCircle2 size={18} />}
          title={t('readyDone')}
          subtitle={iMarkedDone ? t('readyWaitingConfirmation') : t('readyOtherMarkedDone')}
        >
          <div className="flex flex-wrap gap-2">
            <Button loading={act.isPending} disabled={iMarkedDone} onClick={() => act.mutate('done')}>
              {t('readyConfirmDone')}
            </Button>
            {isExchange && (
              <Button
                variant="outline"
                loading={act.isPending}
                onClick={() => act.mutate('dispute')}
              >
                {t('readyDisputeDone')}
              </Button>
            )}
          </div>
        </Step>
      )}
    </div>
  );
}

function Step({
  icon,
  title,
  subtitle,
  children,
}: {
  icon: React.ReactNode;
  title: string;
  subtitle: string;
  children: React.ReactNode;
}) {
  return (
    <section className="mb-4 rounded-[16px] border border-border bg-card p-4">
      <h2 className="flex items-center gap-2 font-display text-base font-bold">
        <span className="text-accent">{icon}</span>
        {title}
      </h2>
      <p className="mb-3 mt-1 text-sm text-muted-foreground">{subtitle}</p>
      {children}
    </section>
  );
}
