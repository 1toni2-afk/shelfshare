import { useState, type FormEvent } from 'react';
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { Link } from 'react-router-dom';
import { useTranslation } from 'react-i18next';
import { ScreenHeader } from '@/components/layout/ScreenHeader';
import { Plus, X } from 'lucide-react';
import { bookRequestsRepository, shelfKeys, type BookRequestStatus } from './shelfRepository';
import { Button, ErrorNotice, Field, Spinner } from '@/components/ui';
import { formatRelativeTime } from '@/lib/utils/time';
import { cn } from '@/lib/utils/cn';

const STATUS_KEYS: Record<BookRequestStatus, string> = {
  PENDING: 'bookRequestStatusPending',
  FULFILLED: 'bookRequestStatusFulfilled',
  NOT_FOUND: 'bookRequestStatusNotFound',
  CANCELLED: 'bookRequestStatusCancelled',
};

const STATUS_TONES: Record<BookRequestStatus, string> = {
  PENDING: 'text-warning',
  FULFILLED: 'text-success',
  NOT_FOUND: 'text-muted-foreground',
  CANCELLED: 'text-muted-foreground',
};

/**
 * „Nu găsesc cartea": userul cere un titlu, iar o căutare de noapte îl caută
 * prin magazine. Când îl găsește, cererea trece pe FULFILLED și trimite o
 * notificare (BOOK_REQUEST_FOUND).
 */
export function BookRequestsScreen() {
  const { t, i18n } = useTranslation();
  const queryClient = useQueryClient();

  const [creating, setCreating] = useState(false);
  const [title, setTitle] = useState('');
  const [author, setAuthor] = useState('');

  const requests = useQuery({
    queryKey: shelfKeys.bookRequests(),
    queryFn: ({ signal }) => bookRequestsRepository.mine(signal),
  });

  const create = useMutation({
    mutationFn: () =>
      bookRequestsRepository.create({ title: title.trim(), author: author.trim() || undefined }),
    onSuccess: () => {
      void queryClient.invalidateQueries({ queryKey: shelfKeys.bookRequests() });
      setCreating(false);
      setTitle('');
      setAuthor('');
    },
  });

  const cancel = useMutation({
    mutationFn: (id: string) => bookRequestsRepository.cancel(id),
    onSuccess: () => queryClient.invalidateQueries({ queryKey: shelfKeys.bookRequests() }),
  });

  function onCreate(event: FormEvent) {
    event.preventDefault();
    if (!title.trim()) return;
    create.mutate();
  }

  const header = <ScreenHeader title={t('bookRequestsTitle')} back />;

  if (requests.isPending) {
    return (
      <div className="flex min-h-dvh items-center justify-center text-accent">
        {header}
        <Spinner size={28} />
      </div>
    );
  }

  if (requests.isError) {
    return (
      <div className="mx-auto max-w-2xl p-6">
        {header}
        <ErrorNotice
          message={t('bookRequestsLoadError')}
          onRetry={() => void requests.refetch()}
        />
      </div>
    );
  }

  return (
    <div className="mx-auto w-full max-w-[680px] px-5 pb-16 pt-2 min-[900px]:px-8">
      {header}
      <div className="mb-6 flex flex-wrap items-center justify-between gap-3">
        <Button onClick={() => setCreating((open) => !open)}>
          <Plus size={18} />
          {t('bookRequestTitle')}
        </Button>
      </div>

      {creating && (
        <form
          onSubmit={onCreate}
          className="mb-6 flex flex-col gap-4 rounded-[16px] border border-border bg-card p-5"
        >
          <Field
            label={t('bookRequestTitle')}
            name="title"
            value={title}
            autoFocus
            onChange={(event) => setTitle(event.target.value)}
          />
          <Field
            label={t('filtersAuthor')}
            name="author"
            value={author}
            onChange={(event) => setAuthor(event.target.value)}
          />
          <div className="flex gap-2">
            <Button type="submit" loading={create.isPending} disabled={!title.trim()}>
              {t('commonSubmit')}
            </Button>
            <Button type="button" variant="text" onClick={() => setCreating(false)}>
              {t('commonCancel')}
            </Button>
          </div>
        </form>
      )}

      {requests.data.length === 0 ? (
        <p className="py-16 text-center text-muted-foreground">{t('bookRequestsEmpty')}</p>
      ) : (
        <ul className="flex flex-col gap-2">
          {requests.data.map((request) => (
            <li
              key={request.id}
              className="flex items-center gap-3 rounded-[16px] border border-border bg-card p-4"
            >
              <div className="min-w-0 flex-1">
                <p className="truncate font-semibold">{request.title}</p>
                {request.author && (
                  <p className="truncate text-sm text-muted-foreground">{request.author}</p>
                )}
                <p className="mt-1 flex flex-wrap items-center gap-2 text-xs">
                  <span className={cn('font-medium', STATUS_TONES[request.status])}>
                    {t(STATUS_KEYS[request.status])}
                  </span>
                  {/* `nights`, nu `count`: așa se cheamă placeholderul în .arb.
                      Cu numele greșit, i18next lăsa „{nights}" pe ecran. Și îl
                      arătăm doar după prima noapte de căutare - „căutată 0
                      nopți" e zgomot pe o cerere abia trimisă. */}
                  {request.attempts > 0 && (
                    <span className="text-muted-foreground">
                      {t('bookRequestAttempts', { nights: request.attempts })}
                    </span>
                  )}
                  <span className="text-muted-foreground">
                    {formatRelativeTime(request.createdAt, i18n.language)}
                  </span>
                </p>
              </div>

              {/* Cartea găsită duce direct la pagina ei - e tot rostul cererii. */}
              {request.status === 'FULFILLED' && request.foundBookId && (
                <Link
                  to={`/work/${request.foundBookId}`}
                  className="shrink-0 rounded-[12px] border border-border px-3 py-2 text-sm hover:bg-muted"
                >
                  {t('bookRequestOpenBook')}
                </Link>
              )}

              {request.status === 'PENDING' && (
                <button
                  onClick={() => cancel.mutate(request.id)}
                  aria-label={t('commonCancel')}
                  title={t('commonCancel')}
                  className="shrink-0 rounded-[12px] p-2.5 text-muted-foreground hover:bg-muted hover:text-danger-text"
                >
                  <X size={18} />
                </button>
              )}
            </li>
          ))}
        </ul>
      )}
    </div>
  );
}
