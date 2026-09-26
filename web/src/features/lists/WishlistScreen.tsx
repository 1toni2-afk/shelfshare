import { useMemo } from 'react';
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { Link } from 'react-router-dom';
import { useTranslation } from 'react-i18next';
import { ScreenHeader, HeaderAction } from '@/components/layout/ScreenHeader';
import { BellRing, FileSearch, Sparkles, Trash2 } from 'lucide-react';
import { listsKeys, wishlistRepository, type WishlistItem } from './listsRepository';
import { BookCover } from '@/components/ui/BookCover';
import { ErrorNotice, Spinner } from '@/components/ui';

/**
 * Lista de dorințe. Port al wishlist_screen.dart.
 *
 * Are două secțiuni, fiindcă intrările vin din două locuri: adăugate manual și
 * strânse din Book Match (swipe). Amestecate, userul nu mai înțelegea de ce
 * are în listă cărți pe care nu-și amintea să le fi adăugat.
 */
export function WishlistScreen() {
  const { t } = useTranslation();
  const queryClient = useQueryClient();

  const wishlist = useQuery({
    queryKey: listsKeys.wishlist(),
    queryFn: ({ signal }) => wishlistRepository.list(signal),
  });

  const remove = useMutation({
    mutationFn: (bookId: string) => wishlistRepository.remove(bookId),
    onSuccess: () => queryClient.invalidateQueries({ queryKey: listsKeys.wishlist() }),
  });

  const { manual, fromMatch } = useMemo(() => {
    const items = wishlist.data ?? [];
    return {
      manual: items.filter((item) => item.source !== 'BOOK_MATCH'),
      fromMatch: items.filter((item) => item.source === 'BOOK_MATCH'),
    };
  }, [wishlist.data]);

  const header = (
    <ScreenHeader
      title={t('wishlistTitle')}
      back
      actions={
        <>
          <HeaderAction to="/saved-searches" label={t('savedSearchesTitle')}>
            <BellRing size={22} />
          </HeaderAction>
          {/* Cărțile cerute stau lângă favorite și căutări salvate: toate trei
              sunt „ce aștept să apară", doar sursa diferă. */}
          <HeaderAction to="/book-requests" label={t('bookRequestsTitle')}>
            <FileSearch size={22} />
          </HeaderAction>
        </>
      }
    />
  );

  if (wishlist.isPending) {
    return (
      <div className="flex min-h-dvh items-center justify-center text-accent">
        {header}
        <Spinner size={28} />
      </div>
    );
  }

  if (wishlist.isError) {
    return (
      <div className="mx-auto max-w-2xl p-6">
        {header}
        <ErrorNotice message={t('wishlistLoadError')} onRetry={() => void wishlist.refetch()} />
      </div>
    );
  }

  const total = wishlist.data.length;

  return (
    <div className="mx-auto w-full max-w-[900px] px-5 pb-16 pt-2 min-[900px]:px-8">
      {header}
      {total === 0 ? (
        <p className="py-16 text-center text-muted-foreground">{t('wishlistEmpty')}</p>
      ) : (
        <>
          {/*
            `browseResultsCount`, nu `wishlistCount`: a doua e un simplu
            „{count} cărți", fără forme de plural, deci pentru un singur titlu
            scria „1 cărți". Cheia folosită aici are one/few/other corecte
            pentru română.
          */}
          <p className="mb-6 text-sm text-muted-foreground">
            {t('browseResultsCount', { count: total })}
          </p>

          <Section
            title={t('wishlistSectionPersonal', { count: manual.length })}
            items={manual}
            onRemove={(bookId) => remove.mutate(bookId)}
          />
          <Section
            title={t('wishlistSectionBookMatch', { count: fromMatch.length })}
            icon={<Sparkles size={18} className="text-accent" />}
            items={fromMatch}
            onRemove={(bookId) => remove.mutate(bookId)}
          />
        </>
      )}
    </div>
  );
}

function Section({
  title,
  items,
  icon,
  onRemove,
}: {
  title: string;
  items: WishlistItem[];
  icon?: React.ReactNode;
  onRemove: (bookId: string) => void;
}) {
  const { t } = useTranslation();
  if (items.length === 0) return null;

  return (
    <section className="mt-8 first:mt-0">
      <h2 className="mb-4 flex items-center gap-2 font-display text-lg font-bold">
        {icon}
        {title}
      </h2>

      <ul className="flex flex-col gap-2">
        {items.map((item) => (
          <li
            key={item.id}
            className="flex items-center gap-3 rounded-[16px] border border-border bg-card p-3"
          >
            <div className="h-[72px] w-[52px] shrink-0 overflow-hidden rounded-lg bg-muted">
              <BookCover url={item.book.coverUrl} title={item.book.title} />
            </div>

            <div className="min-w-0 flex-1">
              <Link to={`/work/${item.book.id}`} className="truncate font-semibold hover:underline">
                {item.book.title}
              </Link>
              {item.book.author && (
                <p className="truncate text-sm text-muted-foreground">{item.book.author}</p>
              )}
              {/* Anunțurile disponibile acum sunt motivul pentru care lista
                  există: fără ele, e doar o listă de titluri. */}
              {item.availableListings && item.availableListings.length > 0 && (
                <Link
                  to={`/books/${item.availableListings[0].id}`}
                  className="mt-1 inline-block text-sm font-medium text-success hover:underline"
                >
                  {item.availableListings.length}
                </Link>
              )}
            </div>

            <button
              onClick={() => onRemove(item.book.id)}
              aria-label={t('commonDelete')}
              title={t('commonDelete')}
              className="shrink-0 rounded-[12px] p-2.5 text-muted-foreground hover:bg-muted hover:text-danger-text"
            >
              <Trash2 size={18} />
            </button>
          </li>
        ))}
      </ul>
    </section>
  );
}
