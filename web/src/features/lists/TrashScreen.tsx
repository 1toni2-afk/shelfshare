import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { useTranslation } from 'react-i18next';
import { ScreenHeader } from '@/components/layout/ScreenHeader';
import { RotateCcw } from 'lucide-react';
import { listsKeys, trashRepository } from './listsRepository';
import { booksKeys } from '@/features/books/booksRepository';
import { BookCover } from '@/components/ui/BookCover';
import { ErrorNotice, Spinner } from '@/components/ui';
import { useToast } from '@/components/ui/Toast';

/** Câte zile stau anunțurile în coș înainte să dispară definitiv. */
const RETENTION_DAYS = 7;

export function TrashScreen() {
  const { t } = useTranslation();
  const queryClient = useQueryClient();
  const toast = useToast();

  const trash = useQuery({
    queryKey: listsKeys.trash(),
    queryFn: ({ signal }) => trashRepository.list(signal),
  });

  const restore = useMutation({
    mutationFn: (userBookId: string) => trashRepository.restore(userBookId),
    onSuccess: () => {
      void queryClient.invalidateQueries({ queryKey: listsKeys.trash() });
      // Și biblioteca, nu doar coșul: anunțul restaurat trebuie să reapară
      // acolo imediat, altfel userul crede că restaurarea n-a funcționat.
      void queryClient.invalidateQueries({ queryKey: booksKeys.myLibrary() });
      toast.show(t('libraryRestored'));
    },
  });

  const header = <ScreenHeader title={t('libraryTrash')} back="/library" />;

  if (trash.isPending) {
    return (
      <div className="flex min-h-dvh items-center justify-center text-accent">
        {header}
        <Spinner size={28} />
      </div>
    );
  }

  if (trash.isError) {
    return (
      <div className="mx-auto max-w-2xl p-6">
        {header}
        <ErrorNotice message={t('homeLoadError')} onRetry={() => void trash.refetch()} />
      </div>
    );
  }

  return (
    <div className="mx-auto w-full max-w-[680px] px-5 pb-16 pt-2 min-[900px]:px-8">
      {header}
      <p className="mb-6 text-muted-foreground">{t('libraryTrashHint')}</p>

      {trash.data.length === 0 ? (
        <p className="py-16 text-center text-muted-foreground">{t('libraryTrashEmpty')}</p>
      ) : (
        <ul className="flex flex-col gap-2">
          {trash.data.map((item) => (
            <li
              key={item.id}
              className="flex items-center gap-3 rounded-[16px] border border-border bg-card p-3"
            >
              <div className="h-[72px] w-[52px] shrink-0 overflow-hidden rounded-lg bg-muted opacity-60">
                <BookCover
                  url={item.book.coverUrl}
                  fallbackUrl={item.mainPhotoUrl}
                  title={item.book.title}
                />
              </div>

              <div className="min-w-0 flex-1">
                <p className="truncate font-semibold">{item.book.title}</p>
                {item.book.author && (
                  <p className="truncate text-sm text-muted-foreground">{item.book.author}</p>
                )}
                {item.deletedAt && (
                  <p className="mt-1 text-xs text-muted-foreground">
                    {t('inventoryDeletedDaysLeft', { days: daysLeft(item.deletedAt) })}
                  </p>
                )}
              </div>

              <button
                onClick={() => restore.mutate(item.id)}
                disabled={restore.isPending}
                className="flex shrink-0 items-center gap-2 rounded-[12px] border border-border px-3 py-2 text-sm hover:bg-muted disabled:opacity-60"
              >
                <RotateCcw size={16} />
                {t('libraryRestore')}
              </button>
            </li>
          ))}
        </ul>
      )}
    </div>
  );
}

/**
 * Câte zile mai are anunțul până e șters definitiv. `Math.max(0, ...)`: un
 * anunț exact la limită ar afișa altfel „-1 zile" în intervalul dintre
 * expirare și următoarea rulare a curățeniei.
 */
function daysLeft(deletedAt: string): number {
  const elapsedMs = Date.now() - new Date(deletedAt).getTime();
  const elapsedDays = Math.floor(elapsedMs / (1000 * 60 * 60 * 24));
  return Math.max(0, RETENTION_DAYS - elapsedDays);
}
