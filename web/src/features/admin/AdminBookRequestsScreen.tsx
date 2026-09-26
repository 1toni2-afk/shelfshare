import { useState } from 'react';
import { useQuery } from '@tanstack/react-query';
import { Link } from 'react-router-dom';
import { useTranslation } from 'react-i18next';
import { api } from '@/lib/api/client';
import { ScreenHeader } from '@/components/layout/ScreenHeader';
import { ErrorNotice, Spinner } from '@/components/ui';
import { RequireAdmin } from './AdminScreens';
import { cn } from '@/lib/utils/cn';

type RequestStatus = 'PENDING' | 'FULFILLED' | 'NOT_FOUND' | 'CANCELLED';

/**
 * O cerere de carte așa cum o vede panoul de admin: cererea propriu-zisă, plus
 * cine a făcut-o și câți oameni așteaptă același titlu. Emailul solicitantului
 * e un câmp pe care un user obișnuit nu-l primește niciodată.
 */
interface AdminBookRequest {
  id: string;
  title: string;
  author: string | null;
  isbn: string | null;
  note: string | null;
  status: RequestStatus | null;
  /** Câte nopți a fost căutată fără succes. */
  attempts: number;
  /** Câți useri DISTINCȚI așteaptă același titlu - ordinea cozii de noapte. */
  demand: number;
  resolvedSource: string | null;
  createdAt: string;
  lastAttemptAt: string | null;
  user?: { email?: string | null; name?: string | null } | null;
  book?: { id?: string | null; title?: string | null } | null;
}

const FILTERS: Array<{ value: RequestStatus | null; labelKey: string }> = [
  { value: 'PENDING', labelKey: 'adminBookRequestsFilterPending' },
  { value: 'FULFILLED', labelKey: 'adminBookRequestsFilterFulfilled' },
  { value: 'NOT_FOUND', labelKey: 'adminBookRequestsFilterNotFound' },
  { value: null, labelKey: 'adminBookRequestsFilterAll' },
];

const STATUS_KEYS: Record<RequestStatus, string> = {
  PENDING: 'bookRequestStatusPending',
  FULFILLED: 'bookRequestStatusFulfilled',
  NOT_FOUND: 'bookRequestStatusNotFound',
  CANCELLED: 'bookRequestStatusCancelled',
};

const STATUS_TONES: Record<RequestStatus, string> = {
  PENDING: 'bg-accent/15 text-accent',
  FULFILLED: 'bg-success/15 text-success',
  NOT_FOUND: 'bg-danger-text/15 text-danger-text',
  CANCELLED: 'bg-muted text-muted-foreground',
};

/**
 * Cererile de carte trimise din formularul „nu găsesc cartea".
 *
 * Ecranul e de OBSERVARE, nu de lucru: cererile se rezolvă singure, în fiecare
 * noapte (vezi BookRequestsService.resolvePendingRequests și
 * scripts/book-requests/nightly_book_requests.py). Ce contează aici e să se
 * vadă ce se caută, în ce ordine și ce nu găsește nimeni - un titlu cerut de
 * mulți oameni care rămâne negăsit e semnal că lipsește o sursă, nu că trebuie
 * apăsat un buton.
 */
export function AdminBookRequestsScreen() {
  const { t } = useTranslation();
  const [status, setStatus] = useState<RequestStatus | null>('PENDING');

  // Filtrarea se face pe server (`?status=`), nu în client: panoul n-are de ce
  // să descarce toate cererile ca să le arate doar pe cele în așteptare.
  const requests = useQuery({
    queryKey: ['admin', 'book-requests', status],
    queryFn: ({ signal }) =>
      api.get<AdminBookRequest[]>('/book-requests/admin', {
        query: { status: status ?? undefined, limit: 200 },
        signal,
      }),
  });

  return (
    <RequireAdmin>
      <div className="mx-auto w-full max-w-[760px] px-5 pb-16 pt-4 min-[900px]:px-8">
        <ScreenHeader title={t('adminBookRequestsTitle')} back="/admin" />

        <div className="mb-4 flex flex-wrap gap-2">
          {FILTERS.map((filter) => (
            <button
              key={filter.labelKey}
              onClick={() => setStatus(filter.value)}
              className={cn(
                'rounded-full border px-4 py-2 text-sm transition',
                status === filter.value
                  ? 'border-accent bg-accent/15 font-semibold text-accent'
                  : 'border-border hover:bg-muted',
              )}
            >
              {t(filter.labelKey)}
            </button>
          ))}
        </div>

        {requests.isPending ? (
          <div className="flex h-40 items-center justify-center text-accent">
            <Spinner size={26} />
          </div>
        ) : requests.isError ? (
          <ErrorNotice message={t('adminLoadError')} onRetry={() => void requests.refetch()} />
        ) : requests.data.length === 0 ? (
          <p className="py-16 text-center text-muted-foreground">
            {t('adminBookRequestsEmpty')}
          </p>
        ) : (
          <>
            <p className="mb-2 text-sm text-muted-foreground">
              {t('adminBookRequestsCount', { count: requests.data.length })}
            </p>
            <ul className="flex flex-col gap-2">
              {requests.data.map((request) => (
                <RequestRow key={request.id} request={request} />
              ))}
            </ul>
          </>
        )}
      </div>
    </RequireAdmin>
  );
}

function RequestRow({ request }: { request: AdminBookRequest }) {
  const { t } = useTranslation();
  const status = request.status ?? 'PENDING';

  return (
    <li className="rounded-[16px] border border-border bg-card p-3.5">
      <div className="flex items-start gap-3">
        <p className="min-w-0 flex-1 font-semibold">{request.title}</p>
        <span
          className={cn(
            'shrink-0 rounded-lg px-2 py-0.5 text-[11px]',
            STATUS_TONES[status] ?? STATUS_TONES.PENDING,
          )}
        >
          {t(STATUS_KEYS[status] ?? 'bookRequestStatusPending')}
        </span>
      </div>

      {request.author && <p className="text-sm text-muted-foreground">{request.author}</p>}

      <div className="mt-2 flex flex-wrap gap-x-3 gap-y-1 text-sm text-muted-foreground">
        {/* Cine cere, ca să se poată răspunde omului direct dacă titlul e scris
            greșit - de aceea emailul, nu doar numele. */}
        {request.user?.email && <span>{request.user.email}</span>}
        <span>{formatDate(request.createdAt)}</span>
        {request.demand > 1 && (
          <span className="text-accent">
            {t('adminBookRequestsDemand', { count: request.demand })}
          </span>
        )}
        {request.attempts > 0 && <span>{t('bookRequestAttempts', { nights: request.attempts })}</span>}
        {request.isbn && <span>ISBN {request.isbn}</span>}
        {request.resolvedSource && (
          <span>{t('adminBookRequestsFoundOn', { source: request.resolvedSource })}</span>
        )}
      </div>

      {request.note && <p className="mt-2 text-sm text-muted-foreground">„{request.note}"</p>}

      {request.book?.id && (
        <Link
          to={`/work/${request.book.id}`}
          className="mt-1 inline-block py-1 text-sm font-semibold text-accent hover:underline"
        >
          {t('bookRequestOpenBook')}
        </Link>
      )}
    </li>
  );
}

/** `dd.mm.yyyy`, ca în `_RequestTile._date`. */
function formatDate(iso: string): string {
  const date = new Date(iso);
  const pad = (value: number) => String(value).padStart(2, '0');
  return `${pad(date.getDate())}.${pad(date.getMonth() + 1)}.${date.getFullYear()}`;
}
