import { useEffect, useState, type ReactNode } from 'react';
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { Link, useParams } from 'react-router-dom';
import { useTranslation } from 'react-i18next';
import { ScreenHeader } from '@/components/layout/ScreenHeader';
import {
  ArrowLeftRight,
  CalendarDays,
  CalendarPlus,
  Check,
  CircleCheck,
  CreditCard,
  Flag,
  MapPin,
  Phone,
  Shield,
  ShieldAlert,
  ShieldCheck,
  X,
} from 'lucide-react';
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
import { api } from '@/lib/api/client';
import { useAuth } from '@/features/auth/AuthProvider';
import { SafetyItem } from '@/features/chat/ChatSafetyPane';
import { staticPageUrl } from '@/lib/staticPages';
import { toNumber, type UserBook } from '@/types/models';
import { cn } from '@/lib/utils/cn';

/**
 * Pregătirea întâlnirii, folosită ȘI pentru schimburi, ȘI pentru vânzări.
 *
 * Cele două au endpointuri diferite (`/exchanges/:id/...` vs `/offers/:id/...`)
 * dar exact aceiași pași: recomandări de siguranță, contact, întâlnire,
 * confirmarea finalizării de ambele părți. Aici e un singur ecran,
 * parametrizat pe tip.
 *
 * Pașii stau pe o linie verticală numerotată: un pas terminat își aprinde
 * cercul și bucata de linie de sub el, deci dintr-o privire se vede cât a
 * rămas - nu patru carduri egale, între care nu știi de unde să începi.
 */
type Action = 'safety' | 'contact' | 'done' | 'dispute' | 'meeting' | 'acceptMeeting';

export function ReadyToExchangeScreen({ kind }: { kind: 'exchange' | 'offer' }) {
  const { id = '' } = useParams();
  const { t, i18n } = useTranslation();
  const { user } = useAuth();
  const queryClient = useQueryClient();
  const toast = useToast();

  const [meetingTime, setMeetingTime] = useState('');
  const [meetingLocation, setMeetingLocation] = useState('');
  const [phone, setPhone] = useState('');
  const [contactOpen, setContactOpen] = useState(false);
  const [safetyOpen, setSafetyOpen] = useState(false);

  const isExchange = kind === 'exchange';

  // Tipul e adnotat explicit: din `isExchange ? ... : ...` TypeScript ar
  // deduce `Promise<ExchangeRequest> | Promise<PriceOffer>`, pe care useQuery
  // nu îl acceptă ca funcție de interogare. Uniunea se restrânge mai jos, prin
  // verificări de câmp (`'requester' in data`).
  const deal = useQuery<ExchangeRequest | PriceOffer>({
    queryKey: isExchange ? exchangeKeys.detail(id) : exchangeKeys.offerDetail(id),
    queryFn: ({ signal }) =>
      isExchange ? exchangesRepository.detail(id, signal) : offersRepository.detail(id, signal),
    enabled: !!id,
  });

  const act = useMutation({
    mutationFn: async (action: Action) => {
      const repo = isExchange ? exchangesRepository : offersRepository;
      switch (action) {
        case 'safety':
          return repo.acknowledgeSafety(id);
        case 'contact':
          return repo.shareContact(id, phone.trim() || undefined);
        case 'done':
          return repo.markDone(id);
        case 'dispute':
          return repo.dispute(id);
        case 'acceptMeeting':
          return repo.acceptMeeting(id);
        case 'meeting':
          return repo.proposeMeeting(id, {
            meetingTime: new Date(meetingTime).toISOString(),
            meetingLocation: meetingLocation.trim(),
          });
      }
    },
    onSuccess: (_result, action) => {
      if (action === 'safety') setSafetyOpen(false);
      if (action === 'contact') setContactOpen(false);
      void queryClient.invalidateQueries({
        queryKey: isExchange ? exchangeKeys.detail(id) : exchangeKeys.offerDetail(id),
      });
    },
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
  const view = dealView(data, user?.id);

  const counterpartyName =
    view.counterparty.name ?? view.counterparty.username ?? t('commonAnonymousUser');

  const active = !isCompleted && !isCancelled;
  const meetingAccepted = !!data.meetingAcceptedAt;
  const meetingProposedByMe = !!data.meetingTime && data.meetingProposedBy === user?.id;

  const steps = [view.mySafetyAck, view.myContactShared, meetingAccepted, view.myDone];
  // Primul pas neterminat e „pasul curent" - singurul aprins fără bifă.
  const current = active ? steps.findIndex((done) => !done) : -1;
  const stepState = (index: number): StepState =>
    steps[index] ? 'done' : index === current ? 'current' : 'upcoming';

  const price = (amount: unknown) => t('priceLei', { amount: toNumber(amount as string) ?? 0 });

  return (
    <div className="mx-auto w-full max-w-[680px] px-5 pb-16 pt-2 min-[900px]:px-8">
      {header}

      {isCompleted && (
        <p className="mb-4 rounded-[16px] border border-success/40 bg-success/10 p-4 text-center font-bold text-success">
          {t('dealFinalisedBanner')}
        </p>
      )}
      {isCancelled && (
        <p className="mb-4 rounded-[16px] border border-border bg-muted p-4 text-center font-bold text-muted-foreground">
          {t('dealCancelledBanner')}
        </p>
      )}

      {/* Ce primești, ce dai, și cu cine. */}
      <section className="rounded-[20px] border border-border bg-card p-4 min-[560px]:p-5">
        <div className="flex items-center gap-2 min-[560px]:gap-3">
          <DealSide
            label={t('readyYouReceive')}
            book={view.receive}
            fallback={view.receiveAmount != null ? price(view.receiveAmount) : t('readyNothingOffered')}
          />
          <ArrowLeftRight size={22} className="shrink-0 text-accent min-[560px]:size-[26px]" aria-hidden />
          <DealSide
            label={t('readyYouGive')}
            book={view.give}
            fallback={view.giveAmount != null ? price(view.giveAmount) : t('readyNothingOffered')}
          />
        </div>

        <div className="mt-4 flex items-center gap-3 border-t border-border pt-4">
          <Avatar src={view.counterparty.profileImage} name={counterpartyName} size={44} />
          <div className="min-w-0 flex-1">
            <p className="truncate">
              <span className="text-muted-foreground">
                {t(isExchange ? 'readyDealWith' : 'readySaleWith')}
              </span>{' '}
              <span className="font-bold">{counterpartyName}</span>
            </p>
            {view.counterparty.city && (
              <p className="flex items-center gap-1 text-sm text-muted-foreground">
                <MapPin size={14} className="shrink-0" />
                <span className="truncate">{view.counterparty.city}</span>
              </p>
            )}
          </div>
          <Link
            to={`/users/${view.counterparty.id}`}
            className="shrink-0 rounded-[12px] border border-border px-3.5 py-2 text-sm font-medium transition hover:bg-muted"
          >
            {t('readyViewProfile')}
          </Link>
        </div>
      </section>

      {active && (
        <ol className="mt-5">
          {/* 1. Siguranță */}
          <Step
            number={1}
            state={stepState(0)}
            icon={<ShieldCheck size={26} />}
            title={t('readySafetyTitle')}
            text={view.mySafetyAck ? t('readyStepSafetyDone') : t('readyStepSafetyText')}
          >
            <Button
              variant={view.mySafetyAck ? 'outline' : 'primary'}
              className="px-5 py-3"
              onClick={() => setSafetyOpen(true)}
            >
              {t('readyStepSafetyView')}
            </Button>
          </Step>

          {/* 2. Contact */}
          <Step
            number={2}
            state={stepState(1)}
            icon={<Phone size={26} />}
            title={t('readyStepContactTitle')}
            text={view.myContactShared ? t('readyContactShared') : t('readyStepContactText')}
          >
            {view.otherContactShared && (
              <p className="mb-3 text-sm">
                {view.otherPhone ? (
                  <a href={`tel:${view.otherPhone}`} className="font-semibold text-accent hover:underline">
                    {t('readyContactOtherPhone', { phone: view.otherPhone })}
                  </a>
                ) : (
                  <span className="text-muted-foreground">{t('readyContactSharedNoPhone')}</span>
                )}
              </p>
            )}
            {view.myContactShared && !contactOpen ? (
              <Button variant="outline" className="px-5 py-3" onClick={() => setContactOpen(true)}>
                {t('readyContactEdit')}
              </Button>
            ) : contactOpen ? (
              <div className="flex flex-col gap-3">
                <FieldShell icon={<Phone size={18} />}>
                  <input
                    type="tel"
                    inputMode="tel"
                    autoComplete="tel"
                    autoFocus
                    maxLength={30}
                    value={phone}
                    onChange={(event) => setPhone(event.target.value)}
                    placeholder={t('readyContactPhoneLabel')}
                    aria-label={t('readyContactPhoneLabel')}
                    className="min-w-0 flex-1 bg-transparent py-3.5 text-foreground placeholder:text-muted-foreground focus:outline-none"
                  />
                </FieldShell>
                <div className="flex flex-wrap gap-2">
                  <Button
                    className="px-5 py-3"
                    loading={act.isPending && act.variables === 'contact'}
                    disabled={!phone.trim()}
                    onClick={() => act.mutate('contact')}
                  >
                    {t('readyStepContactSend')}
                  </Button>
                  {/* Fără telefon: contactul se face doar prin chat, dar pasul
                      tot e bifat - numărul e opțional și pe backend. */}
                  <Button
                    variant="text"
                    className="px-4 py-3"
                    disabled={act.isPending}
                    onClick={() => {
                      setPhone('');
                      act.mutate('contact');
                    }}
                  >
                    {t('readyContactSkip')}
                  </Button>
                </div>
              </div>
            ) : (
              <Button className="px-5 py-3" onClick={() => setContactOpen(true)}>
                {t('readyContactShare')}
              </Button>
            )}
          </Step>

          {/* 3. Întâlnirea */}
          <Step
            number={3}
            state={stepState(2)}
            icon={<CalendarPlus size={26} />}
            title={t('readyStepMeetingTitle')}
            text={
              meetingAccepted
                ? t('readyStepMeetingAccepted')
                : data.meetingTime
                  ? t(meetingProposedByMe ? 'readyMeetingProposedByMe' : 'readyMeetingAwaitingYou')
                  : t('readyStepMeetingText')
            }
          >
            {data.meetingTime ? (
              <div className="flex flex-col gap-3">
                <div className="flex flex-col gap-2 rounded-[14px] border border-border p-3.5 text-sm">
                  <p className="flex items-center gap-2.5">
                    <CalendarDays size={18} className="shrink-0 text-muted-foreground" />
                    {formatMeeting(data.meetingTime, i18n.language)}
                  </p>
                  {data.meetingLocation && (
                    <p className="flex items-center gap-2.5">
                      <MapPin size={18} className="shrink-0 text-muted-foreground" />
                      {data.meetingLocation}
                    </p>
                  )}
                </div>
                {!meetingAccepted && !meetingProposedByMe && (
                  <Button
                    fullWidth
                    className="py-3"
                    loading={act.isPending && act.variables === 'acceptMeeting'}
                    onClick={() => act.mutate('acceptMeeting')}
                  >
                    {t('readyMeetingAccept')}
                  </Button>
                )}
              </div>
            ) : (
              <div className="flex flex-col gap-3">
                <DateTimeField
                  value={meetingTime}
                  onChange={setMeetingTime}
                  placeholder={t('chatPickDate')}
                  language={i18n.language}
                />
                <MeetingPlaceField value={meetingLocation} onChange={setMeetingLocation} />
                <Button
                  fullWidth
                  className="py-3"
                  loading={act.isPending && act.variables === 'meeting'}
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

          {/* 4. Finalizare */}
          <Step
            number={4}
            state={stepState(3)}
            icon={<CircleCheck size={26} />}
            title={t('readyStepFinishTitle')}
            text={
              view.myDone
                ? t('readyWaitingConfirmation')
                : view.otherDone
                  ? t('readyOtherMarkedDone')
                  : view.mySafetyAck
                    ? t('readyStepFinishText')
                    : t('readyStepFinishLocked')
            }
            last
          >
            <div className="flex flex-col gap-2">
              <Button
                fullWidth
                className="py-3"
                loading={act.isPending && act.variables === 'done'}
                // Backendul refuză „gata" fără bifa de siguranță; butonul stă
                // stins până atunci, cu explicația în text.
                disabled={view.myDone || !view.mySafetyAck}
                onClick={() => act.mutate('done')}
              >
                {t('readyConfirmDone')}
              </Button>
              {view.otherDone && !view.myDone && (
                <Button
                  variant="outline"
                  fullWidth
                  className="py-3"
                  loading={act.isPending && act.variables === 'dispute'}
                  onClick={() => act.mutate('dispute')}
                >
                  {t('readyDisputeDone')}
                </Button>
              )}
            </div>
          </Step>
        </ol>
      )}

      {safetyOpen && (
        <SafetyDialog
          acknowledged={view.mySafetyAck}
          loading={act.isPending && act.variables === 'safety'}
          onAcknowledge={() => act.mutate('safety')}
          onClose={() => setSafetyOpen(false)}
        />
      )}
    </div>
  );
}

/**
 * Tranzacția văzută din partea mea: ce primesc, ce dau, cine e celălalt și
 * cât a bifat fiecare. Schimburile și vânzările au câmpuri cu nume diferite
 * (`requester*` vs `buyer*`), dar aceeași formă - de aici încolo ecranul nu
 * mai trebuie să știe care e care.
 */
function dealView(data: ExchangeRequest | PriceOffer, myId: string | undefined) {
  if ('requester' in data) {
    const iAmRequester = data.requesterId === myId;
    const mine = iAmRequester ? 'requester' : 'owner';
    const other = iAmRequester ? 'owner' : 'requester';
    return {
      counterparty: data[other],
      // Cel care cere primește cartea cerută și dă ce a oferit (carte sau bani).
      receive: iAmRequester ? data.requestedBook : data.offeredBook,
      give: iAmRequester ? data.offeredBook : data.requestedBook,
      receiveAmount: iAmRequester ? null : data.offeredAmount,
      giveAmount: iAmRequester ? data.offeredAmount : null,
      mySafetyAck: !!data[`${mine}SafetyAckAt`],
      myContactShared: !!data[`${mine}ContactSharedAt`],
      otherContactShared: !!data[`${other}ContactSharedAt`],
      otherPhone: data[`${other}ContactPhone`],
      myDone: !!data[`${mine}DoneAt`],
      otherDone: !!data[`${other}DoneAt`],
    };
  }
  const iAmBuyer = data.buyerId === myId;
  const mine = iAmBuyer ? 'buyer' : 'owner';
  const other = iAmBuyer ? 'owner' : 'buyer';
  return {
    counterparty: data[other],
    receive: iAmBuyer ? data.userBook : null,
    give: iAmBuyer ? null : data.userBook,
    receiveAmount: iAmBuyer ? null : data.amount,
    giveAmount: iAmBuyer ? data.amount : null,
    mySafetyAck: !!data[`${mine}SafetyAckAt`],
    myContactShared: !!data[`${mine}ContactSharedAt`],
    otherContactShared: !!data[`${other}ContactSharedAt`],
    otherPhone: data[`${other}ContactPhone`],
    myDone: !!data[`${mine}DoneAt`],
    otherDone: !!data[`${other}DoneAt`],
  };
}

function formatMeeting(iso: string, language: string) {
  return new Intl.DateTimeFormat(language, { dateStyle: 'medium', timeStyle: 'short' }).format(
    new Date(iso),
  );
}

/** O jumătate din cardul de sus: coperta, eticheta portocalie, titlu, autor. */
function DealSide({
  label,
  book,
  fallback,
}: {
  label: string;
  book: UserBook | null;
  fallback: string;
}) {
  return (
    <div className="flex min-w-0 flex-1 items-center gap-2 min-[560px]:gap-3.5">
      <div className="flex h-[78px] w-[54px] shrink-0 items-center justify-center overflow-hidden rounded-[10px] bg-muted min-[560px]:h-[104px] min-[560px]:w-[72px]">
        {book ? (
          <BookCover url={book.book.coverUrl} fallbackUrl={book.mainPhotoUrl} title={book.book.title} />
        ) : (
          <span className="px-1 text-center font-display text-sm font-bold text-accent">{fallback}</span>
        )}
      </div>
      <div className="min-w-0">
        <p className="text-[11px] font-bold uppercase tracking-wider text-accent">{label}</p>
        <p className="mt-0.5 line-clamp-2 font-display text-[15px] font-bold leading-tight min-[560px]:text-lg">
          {book ? book.book.title : fallback}
        </p>
        {book?.book.author && (
          <p className="mt-0.5 line-clamp-2 text-[13px] leading-snug text-muted-foreground min-[560px]:text-sm">{book.book.author}</p>
        )}
      </div>
    </div>
  );
}

type StepState = 'done' | 'current' | 'upcoming';

/**
 * Un pas din cronologie. Linia din stânga pornește de sub cerc și merge până la
 * cercul următor (trece și prin spațiul dintre carduri, de aceea stă pe `li`,
 * nu pe card); e portocalie doar sub un pas terminat.
 */
function Step({
  number,
  state,
  icon,
  title,
  text,
  last = false,
  children,
}: {
  number: number;
  state: StepState;
  icon: ReactNode;
  title: string;
  text: string;
  last?: boolean;
  children: ReactNode;
}) {
  return (
    <li className={cn('relative flex gap-3 min-[560px]:gap-4', !last && 'pb-4')}>
      <div className="relative flex w-10 shrink-0 justify-center pt-5">
        <span
          className={cn(
            'relative z-10 flex size-10 items-center justify-center rounded-full border-2 text-[15px] font-bold',
            state === 'upcoming'
              ? 'border-muted-foreground/60 bg-background text-muted-foreground'
              : 'border-accent bg-accent text-accent-foreground',
          )}
          aria-hidden
        >
          {state === 'done' ? <Check size={20} strokeWidth={3} /> : number}
        </span>
        {!last && (
          <span
            className={cn(
              'absolute bottom-[-20px] top-[60px] w-[2px] rounded-full',
              state === 'done' ? 'bg-accent' : 'bg-border',
            )}
            aria-hidden
          />
        )}
      </div>

      <section
        className={cn(
          'min-w-0 flex-1 rounded-[20px] border bg-card p-4 min-[560px]:p-5',
          state === 'current' ? 'border-accent/50' : 'border-border',
        )}
      >
        <div className="flex gap-3 min-[560px]:gap-4">
          <span
            className={cn(
              'mt-0.5 shrink-0',
              state === 'upcoming' ? 'text-muted-foreground' : 'text-accent',
            )}
          >
            {icon}
          </span>
          <div className="min-w-0 flex-1">
            <h2 className="font-display text-lg font-bold leading-tight min-[560px]:text-xl">{title}</h2>
            <p className="mt-1 text-sm leading-relaxed text-muted-foreground min-[560px]:text-[15px]">
              {text}
            </p>
            <div className="mt-4">{children}</div>
          </div>
        </div>
      </section>
    </li>
  );
}

/** Rama comună a câmpurilor din pași: iconiță în stânga, contur rotunjit. */
function FieldShell({ icon, trailing, children }: { icon: ReactNode; trailing?: ReactNode; children: ReactNode }) {
  return (
    <label className="flex items-center gap-3 rounded-[14px] border border-border bg-background/40 px-4 transition focus-within:border-accent">
      <span className="shrink-0 text-muted-foreground">{icon}</span>
      {children}
      {trailing}
    </label>
  );
}

interface PlaceResult {
  displayName: string;
  lat: number;
  lng: number;
}

// Nominatim ignoră interogările sub 3 caractere - la fel ca meeting_sheet.dart.
const MIN_PLACE_QUERY = 3;

/** Locul întâlnirii: text liber, cu sugestii din `/places/search` sub câmp. */
function MeetingPlaceField({ value, onChange }: { value: string; onChange: (value: string) => void }) {
  const { t } = useTranslation();
  const [debounced, setDebounced] = useState('');
  // Fără el, alegerea unei sugestii ar porni imediat o nouă căutare după textul ei.
  const [picked, setPicked] = useState<string | null>(null);

  useEffect(() => {
    const timer = window.setTimeout(() => setDebounced(value.trim()), 400);
    return () => window.clearTimeout(timer);
  }, [value]);

  const active = debounced.length >= MIN_PLACE_QUERY && debounced !== picked;
  const results = useQuery({
    queryKey: ['places', 'search', debounced],
    queryFn: ({ signal }) =>
      api.get<PlaceResult[]>('/places/search', { query: { q: debounced }, signal }),
    enabled: active,
    staleTime: 5 * 60_000,
  });

  const typing = value.trim() !== debounced && value.trim().length >= MIN_PLACE_QUERY && value.trim() !== picked;
  const suggestions = active && !typing ? (results.data ?? []) : [];

  return (
    <div className="relative">
      <FieldShell
        icon={<MapPin size={18} />}
        trailing={
          (typing || (active && results.isFetching)) && (
            <span className="shrink-0 text-accent">
              <Spinner size={16} />
            </span>
          )
        }
      >
        <input
          value={value}
          onChange={(event) => {
            setPicked(null);
            onChange(event.target.value);
          }}
          placeholder={t('readyStepPickPlace')}
          aria-label={t('readyStepPickPlace')}
          aria-autocomplete="list"
          autoComplete="off"
          className="min-w-0 flex-1 bg-transparent py-3.5 text-foreground placeholder:text-muted-foreground focus:outline-none"
        />
      </FieldShell>

      {suggestions.length > 0 && (
        <ul
          role="listbox"
          className="absolute inset-x-0 top-full z-20 mt-1 max-h-64 overflow-y-auto rounded-[14px] border border-border bg-card py-1 shadow-lg"
        >
          {suggestions.map((place) => (
            <li key={`${place.lat},${place.lng}`}>
              <button
                type="button"
                onClick={() => {
                  setPicked(place.displayName);
                  onChange(place.displayName);
                }}
                className="flex w-full items-start gap-2 px-4 py-2.5 text-left text-sm hover:bg-muted/50"
              >
                <MapPin size={16} className="mt-0.5 shrink-0 text-muted-foreground" />
                <span className="min-w-0 flex-1">{place.displayName}</span>
              </button>
            </li>
          ))}
        </ul>
      )}
    </div>
  );
}

/**
 * Data și ora, cu textul „Alege data" cât timp e gol. Inputul nativ
 * `datetime-local` nu are placeholder (arată „zz.ll.aaaa --:--"), așa că stă
 * invizibil peste rând, iar la click deschide direct selectorul browserului.
 */
function DateTimeField({
  value,
  onChange,
  placeholder,
  language,
}: {
  value: string;
  onChange: (value: string) => void;
  placeholder: string;
  language: string;
}) {
  return (
    <div className="relative">
      <FieldShell icon={<CalendarDays size={18} />}>
        <span className={cn('min-w-0 flex-1 truncate py-3.5', !value && 'text-muted-foreground')}>
          {value ? formatMeeting(value, language) : placeholder}
        </span>
      </FieldShell>
      <input
        type="datetime-local"
        value={value}
        min={minDateTime()}
        onChange={(event) => onChange(event.target.value)}
        onClick={(event) => {
          try {
            event.currentTarget.showPicker();
          } catch {
            // Browserele fără showPicker deschid oricum selectorul la focus.
          }
        }}
        aria-label={placeholder}
        className="absolute inset-0 size-full cursor-pointer opacity-0"
      />
    </div>
  );
}

/** Acum, în formatul lui `datetime-local` (ora locală, fără secunde). */
function minDateTime() {
  const now = new Date();
  now.setMinutes(now.getMinutes() - now.getTimezoneOffset());
  return now.toISOString().slice(0, 16);
}

/**
 * Recomandările de siguranță, cu bifa „Am citit" la final. Sunt aceleași patru
 * reguli ca în panoul de siguranță din chat, ca omul să le recunoască.
 */
function SafetyDialog({
  acknowledged,
  loading,
  onAcknowledge,
  onClose,
}: {
  acknowledged: boolean;
  loading: boolean;
  onAcknowledge: () => void;
  onClose: () => void;
}) {
  const { t, i18n } = useTranslation();

  useEffect(() => {
    const onKey = (event: KeyboardEvent) => {
      if (event.key === 'Escape') onClose();
    };
    window.addEventListener('keydown', onKey);
    return () => window.removeEventListener('keydown', onKey);
  }, [onClose]);

  return (
    <div
      role="dialog"
      aria-modal="true"
      aria-labelledby="ready-safety-title"
      className="fixed inset-0 z-[60] flex items-end justify-center min-[560px]:items-center"
    >
      <button
        aria-label={t('commonClose')}
        onClick={onClose}
        className="absolute inset-0 bg-background/70 backdrop-blur-md"
      />
      <div className="relative max-h-[90dvh] w-full max-w-[480px] overflow-y-auto rounded-t-[20px] border border-border bg-card p-6 shadow-xl min-[560px]:rounded-[20px]">
        <button
          onClick={onClose}
          aria-label={t('commonClose')}
          className="absolute right-3 top-3 rounded-full p-2 text-muted-foreground hover:bg-muted"
        >
          <X size={18} />
        </button>

        <span className="inline-flex rounded-[12px] bg-accent/15 p-2.5 text-accent">
          <ShieldCheck size={22} />
        </span>
        <h2 id="ready-safety-title" className="mt-3 font-display text-xl font-bold">
          {t('readySafetyTitle')}
        </h2>

        <ul className="mt-5 flex flex-col gap-4">
          <SafetyItem icon={<ShieldAlert size={20} />} title={t('chatSafetyPersonalTitle')} body={t('chatSafetyPersonalBody')} />
          <SafetyItem icon={<CreditCard size={20} />} title={t('chatSafetyPaymentTitle')} body={t('chatSafetyPaymentBody')} />
          <SafetyItem icon={<MapPin size={20} />} title={t('chatSafetyMeetupTitle')} body={t('chatSafetyMeetupBody')} />
          <SafetyItem icon={<Flag size={20} />} title={t('chatSafetyReportTitle')} body={t('chatSafetyReportBody')} />
        </ul>

        <a
          href={staticPageUrl('safety-center', i18n.language)}
          target="_blank"
          rel="noreferrer"
          className="mt-5 inline-flex items-center gap-2 text-sm font-medium text-accent hover:underline"
        >
          <Shield size={16} />
          {t('chatSafetyOpenCenter')}
        </a>

        <div className="mt-6">
          {acknowledged ? (
            <Button variant="outline" fullWidth onClick={onClose}>
              {t('commonClose')}
            </Button>
          ) : (
            <Button fullWidth loading={loading} onClick={onAcknowledge}>
              {t('readySafetyAck')}
            </Button>
          )}
        </div>
      </div>
    </div>
  );
}
