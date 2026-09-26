import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { Link, useNavigate, useParams } from 'react-router-dom';
import { useTranslation } from 'react-i18next';
import { ScreenHeader } from '@/components/layout/ScreenHeader';
import { Trash2 } from 'lucide-react';
import { collectionsRepository, listsKeys } from './listsRepository';
import { BookGrid } from '@/features/books/BookGrid';
import { BookCover } from '@/components/ui/BookCover';
import { ErrorNotice, Spinner } from '@/components/ui';
import { Switch } from '@/components/ui/Switch';

export function CollectionDetailScreen() {
  const { id = '' } = useParams();
  const { t } = useTranslation();
  const navigate = useNavigate();
  const queryClient = useQueryClient();

  const collection = useQuery({
    queryKey: listsKeys.collection(id),
    queryFn: ({ signal }) => collectionsRepository.detail(id, signal),
    enabled: !!id,
  });

  const setPublic = useMutation({
    mutationFn: (isPublic: boolean) => collectionsRepository.update(id, { isPublic }),
    onSuccess: () => queryClient.invalidateQueries({ queryKey: listsKeys.collection(id) }),
  });

  const removeCollection = useMutation({
    mutationFn: () => collectionsRepository.remove(id),
    onSuccess: () => {
      void queryClient.invalidateQueries({ queryKey: listsKeys.collections() });
      void navigate('/collections');
    },
  });

  const removeBook = useMutation({
    mutationFn: (bookId: string) => collectionsRepository.removeBook(id, bookId),
    onSuccess: () => queryClient.invalidateQueries({ queryKey: listsKeys.collection(id) }),
  });

  const header = <ScreenHeader title={collection.data?.name ?? t('collectionsTitle')} back="/collections" />;

  if (collection.isPending) {
    return (
      <div className="flex min-h-dvh items-center justify-center text-accent">
        {header}
        <Spinner size={28} />
      </div>
    );
  }

  if (collection.isError) {
    return (
      <div className="mx-auto max-w-2xl p-6">
        {header}
        <ErrorNotice
          message={t('collectionsLoadError')}
          onRetry={() => void collection.refetch()}
        />
      </div>
    );
  }

  return (
    <div className="mx-auto w-full max-w-[900px] px-5 pb-16 pt-2 min-[900px]:px-8">
      {header}
      <div className="mb-6 flex flex-wrap items-center justify-between gap-3">
        <h1 className="font-display text-2xl font-bold">{collection.data.name}</h1>
        <button
          onClick={() => {
            // Confirmarea e obligatorie: ștergerea unei colecții nu se poate
            // anula, iar butonul stă lângă altele inofensive.
            if (window.confirm(t('collectionsDeleteConfirmTitle'))) removeCollection.mutate();
          }}
          className="flex items-center gap-2 rounded-[12px] border border-border px-4 py-2.5 text-sm font-medium text-danger-text hover:bg-muted"
        >
          <Trash2 size={16} />
          {t('commonDelete')}
        </button>
      </div>

      <div className="mb-6">
        <Switch
          checked={collection.data.isPublic}
          onChange={(value) => setPublic.mutate(value)}
          label={t('collectionsPublicSwitch')}
        />
      </div>

      {collection.data.books.length === 0 ? (
        <p className="py-16 text-center text-muted-foreground">{t('collectionsEmptyItems')}</p>
      ) : (
        <BookGrid>
          {collection.data.books.map((book) => (
            <div key={book.id} className="group relative">
              <Link to={`/work/${book.id}`} className="flex flex-col gap-2">
                <div className="aspect-[5/7] overflow-hidden rounded-[12px] border border-border bg-muted">
                  <BookCover url={book.coverUrl} title={book.title} />
                </div>
                <p className="line-clamp-2 text-sm font-semibold leading-snug">{book.title}</p>
                {book.author && (
                  <p className="truncate text-xs text-muted-foreground">{book.author}</p>
                )}
              </Link>

              {/* Apare la hover pe desktop, dar e mereu vizibil pe touch
                  (`group-hover` nu se declanșează pe telefon, unde nu există
                  hover - fără `opacity-100` sub prag, butonul ar fi inaccesibil). */}
              <button
                onClick={() => removeBook.mutate(book.id)}
                aria-label={t('commonDelete')}
                className="absolute right-1.5 top-1.5 rounded-full bg-card/90 p-1.5 text-danger-text opacity-100 shadow transition min-[900px]:opacity-0 min-[900px]:group-hover:opacity-100"
              >
                <Trash2 size={14} />
              </button>
            </div>
          ))}
        </BookGrid>
      )}
    </div>
  );
}
