import { useState } from 'react';
import { useMutation, useQueryClient } from '@tanstack/react-query';
import { Navigate } from 'react-router-dom';
import { useTranslation } from 'react-i18next';
import { ScreenHeader } from '@/components/layout/ScreenHeader';
import { api } from '@/lib/api/client';
import { booksKeys } from './booksRepository';
import { Button, Spinner } from '@/components/ui';
import { useToast } from '@/components/ui/Toast';
import { useAuth } from '@/features/auth/AuthProvider';
import { cn } from '@/lib/utils/cn';

const CONDITIONS = [
  { value: 'NOUA', labelKey: 'bookConditionNew' },
  { value: 'FOARTE_BUNA', labelKey: 'bookConditionVeryGood' },
  { value: 'BUNA', labelKey: 'bookConditionGood' },
  { value: 'ACCEPTABILA', labelKey: 'bookConditionAcceptable' },
] as const;

interface BulkResult {
  created?: Array<{ isbn: string; title: string }>;
  failed?: Array<{ isbn: string; reason?: string }>;
}

/**
 * Adăugare în masă după ISBN. `POST /books/bulk` e păzit de SuperAdminGuard,
 * nu doar de „e admin": creează rânduri în catalog pentru oricine, deci e o
 * unealtă de operare, nu de moderare.
 *
 * Verificăm dreptul și în interfață, nu doar pe server. Un 403 brut la
 * trimitere, după ce userul a tastat cincizeci de ISBN-uri, e cel mai prost
 * moment posibil pentru a afla că n-avea voie.
 */
export function BulkAddScreen() {
  const { t } = useTranslation();
  const { user, status } = useAuth();
  const queryClient = useQueryClient();
  const toast = useToast();

  const [raw, setRaw] = useState('');
  const [condition, setCondition] = useState<string>('BUNA');
  const [result, setResult] = useState<BulkResult | null>(null);

  // Lista se calculează din text la fiecare randare: ISBN-urile pot fi
  // separate prin virgulă, spațiu sau linie nouă (copiate dintr-un tabel).
  const isbns = [...new Set(raw.split(/[\s,;]+/).map((value) => value.trim()).filter(Boolean))];

  const submit = useMutation({
    mutationFn: () => api.post<BulkResult>('/books/bulk', { isbns, condition }),
    onSuccess: (data) => {
      setResult(data);
      void queryClient.invalidateQueries({ queryKey: booksKeys.myLibrary() });
    },
    onError: () => toast.show(t('libraryImportError'), 'danger'),
  });

  const header = <ScreenHeader title={t('bulkAddTitle')} back="/library" />;

  if (status.kind === 'restoring') return null;
  if (!user?.isSuperAdmin) return <Navigate to="/library" replace />;

  return (
    <div className="mx-auto w-full max-w-[680px] px-5 pb-16 pt-2 min-[900px]:px-8">
      {header}
      <div className="mb-4 flex flex-col gap-1.5">
        <label htmlFor="isbns" className="text-sm font-medium text-muted-foreground">
          {t('bulkAddManualEntry')}
        </label>
        <textarea
          id="isbns"
          rows={8}
          value={raw}
          onChange={(event) => setRaw(event.target.value)}
          placeholder={t('bulkAddManualPlaceholder')}
          className="w-full resize-y rounded-[16px] bg-muted px-4 py-4 font-mono text-sm text-foreground placeholder:text-muted-foreground focus:outline-none"
        />
        <p className="text-xs text-muted-foreground">{t('bulkAddManualHint')}</p>
      </div>

      <div className="mb-6">
        <p className="mb-2 text-sm font-medium text-muted-foreground">{t('filtersCondition')}</p>
        <div className="flex flex-wrap gap-2">
          {CONDITIONS.map((option) => (
            <button
              key={option.value}
              onClick={() => setCondition(option.value)}
              className={cn(
                'rounded-full border px-4 py-2 text-sm transition',
                condition === option.value
                  ? 'border-accent bg-accent/15 font-semibold text-accent'
                  : 'border-border hover:bg-muted',
              )}
            >
              {t(option.labelKey)}
            </button>
          ))}
        </div>
      </div>

      <Button
        onClick={() => submit.mutate()}
        loading={submit.isPending}
        disabled={isbns.length === 0}
        fullWidth
      >
        {t('bulkAddSubmit', { count: isbns.length })}
      </Button>

      {isbns.length === 0 && (
        <p className="mt-3 text-center text-sm text-muted-foreground">{t('bulkAddQueueEmpty')}</p>
      )}

      {submit.isPending && (
        <div className="mt-6 flex justify-center text-accent">
          <Spinner size={26} />
        </div>
      )}

      {result && (
        <section className="mt-6 rounded-[16px] border border-border bg-card p-5">
          <p className="font-medium">
            {t('bulkAddResultSummary', {
              created: result.created?.length ?? 0,
              failed: result.failed?.length ?? 0,
            })}
          </p>

          {result.failed && result.failed.length > 0 && (
            <ul className="mt-3 flex flex-col gap-1 text-sm text-danger-text">
              {result.failed.map((entry) => (
                <li key={entry.isbn} className="truncate">
                  {entry.isbn} — {entry.reason ?? ''}
                </li>
              ))}
            </ul>
          )}
        </section>
      )}
    </div>
  );
}
