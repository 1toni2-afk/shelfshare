import { useState, type FormEvent } from 'react';
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { Link, useParams } from 'react-router-dom';
import { useTranslation } from 'react-i18next';
import { ScreenHeader } from '@/components/layout/ScreenHeader';
import { Star, Trash2 } from 'lucide-react';
import { workKeys, workRepository, type BookReview } from './workRepository';
import { shelfKeys, shelfRepository } from '@/features/shelf/shelfRepository';
import { BookCard } from '@/features/books/BookCard';
import { BookGrid } from '@/features/books/BookGrid';
import { BookCover } from '@/components/ui/BookCover';
import { Avatar } from '@/components/ui/Avatar';
import { Button, ErrorNotice, Spinner } from '@/components/ui';
import { useToast } from '@/components/ui/Toast';
import { useAuth } from '@/features/auth/AuthProvider';
import { formatRelativeTime } from '@/lib/utils/time';
import { cn } from '@/lib/utils/cn';

/**
 * Pagina OPEREI, nu a unui exemplar: aduna toate edițiile aceluiași titlu,
 * recenziile lor la un loc și anunțurile active pentru oricare dintre ele.
 * `/books/:userBookId` e altceva - acolo e un exemplar anume, al unui om anume.
 */
export function BookWorkScreen() {
  const { bookId = '' } = useParams();
  const { t, i18n } = useTranslation();
  const { user } = useAuth();
  const queryClient = useQueryClient();
  const toast = useToast();

  const [writing, setWriting] = useState(false);
  const [rating, setRating] = useState(0);
  const [text, setText] = useState('');

  const work = useQuery({
    queryKey: workKeys.work(bookId),
    queryFn: ({ signal }) => workRepository.get(bookId, signal),
    enabled: !!bookId,
  });

  const addToShelf = useMutation({
    mutationFn: (status: 'READING' | 'WANT_TO_READ') =>
      shelfRepository.setStatus(bookId, { status }),
    onSuccess: () => {
      void queryClient.invalidateQueries({ queryKey: shelfKeys.bookshelf() });
      toast.show(t('workAddedToShelf'));
    },
  });

  const submitReview = useMutation({
    mutationFn: () => workRepository.addReview(bookId, { rating, text: text.trim() || undefined }),
    onSuccess: () => {
      void queryClient.invalidateQueries({ queryKey: workKeys.work(bookId) });
      setWriting(false);
      setRating(0);
      setText('');
    },
    onError: () => toast.show(t('commonGenericError'), 'danger'),
  });

  const deleteReview = useMutation({
    mutationFn: () => workRepository.deleteReview(bookId),
    onSuccess: () => queryClient.invalidateQueries({ queryKey: workKeys.work(bookId) }),
  });

  const header = <ScreenHeader title={t('workTitle')} back />;

  if (work.isPending) {
    return (
      <div className="flex min-h-dvh items-center justify-center text-accent">
        {header}
        <Spinner size={28} />
      </div>
    );
  }

  if (work.isError) {
    return (
      <div className="mx-auto max-w-2xl p-6">
        {header}
        <ErrorNotice message={t('workLoadError')} onRetry={() => void work.refetch()} />
      </div>
    );
  }

  const { book, editions, reviews, listings } = work.data;
  const myReview = reviews.reviews.find((review) => review.userId === user?.id);

  function onSubmitReview(event: FormEvent) {
    event.preventDefault();
    if (rating < 1) return;
    submitReview.mutate();
  }

  return (
    <div className="mx-auto w-full max-w-[900px] px-5 pb-16 pt-2 min-[900px]:px-8">
      {header}
      <div className="flex flex-col gap-8 min-[700px]:flex-row">
        <div className="w-full shrink-0 min-[700px]:w-[220px]">
          <div className="aspect-[5/7] overflow-hidden rounded-[16px] border border-border bg-muted">
            <BookCover url={book.coverUrl} title={book.title} eager />
          </div>

          <div className="mt-4 flex flex-col gap-2">
            <Button onClick={() => addToShelf.mutate('READING')} loading={addToShelf.isPending}>
              {t('workAddToShelf')}
            </Button>
            <Button
              variant="outline"
              onClick={() => addToShelf.mutate('WANT_TO_READ')}
              loading={addToShelf.isPending}
            >
              {t('workWantToRead')}
            </Button>
          </div>
        </div>

        <div className="min-w-0 flex-1">
          <h1 className="font-display text-2xl font-bold leading-tight">{book.title}</h1>
          {book.author && <p className="mt-1 text-muted-foreground">{book.author}</p>}

          <div className="mt-3 flex flex-wrap items-center gap-3 text-sm">
            {reviews.averageRating !== null && (
              <span className="flex items-center gap-1">
                <Star size={16} className="fill-warning text-warning" />
                <strong>{reviews.averageRating.toFixed(1)}</strong>
                <span className="text-muted-foreground">
                  {t('workRatingCount', { count: reviews.reviewCount })}
                </span>
              </span>
            )}
            {book.pageCount && (
              <span className="text-muted-foreground">
                {t('workPages', { count: book.pageCount })}
              </span>
            )}
            {editions.length > 1 && (
              <span className="text-muted-foreground">
                {t('workEditions', { count: editions.length })}
              </span>
            )}
          </div>

          {book.description && (
            <section className="mt-6">
              <h2 className="mb-2 font-display text-lg font-bold">{t('workAbout')}</h2>
              <p className="whitespace-pre-line leading-relaxed text-muted-foreground">
                {book.description}
              </p>
            </section>
          )}

          {/* Edițiile sunt linkuri, nu un selector: fiecare are pagina ei de
              operă, iar `/work/:bookId` e adresa care se poate trimite. */}
          {editions.length > 1 && (
            <section className="mt-6">
              <h2 className="mb-2 font-display text-lg font-bold">
                {t('workEditions', { count: editions.length })}
              </h2>
              <div className="flex flex-wrap gap-2">
                {editions.map((edition) => (
                  <Link
                    key={edition.id}
                    to={`/work/${edition.id}`}
                    className={cn(
                      'rounded-full border px-3 py-1.5 text-sm',
                      edition.id === book.id
                        ? 'border-accent bg-accent/15 font-semibold text-accent'
                        : 'border-border hover:bg-muted',
                    )}
                  >
                    {edition.publisher ?? edition.publishedYear ?? t('workEditionUnnamed')}
                  </Link>
                ))}
              </div>
            </section>
          )}
        </div>
      </div>

      <section className="mt-10">
        <h2 className="mb-4 font-display text-lg font-bold">
          {t('workListingsTitle', { count: listings.length })}
        </h2>
        {listings.length === 0 ? (
          <div className="flex flex-wrap items-center gap-3 rounded-[16px] border border-border bg-card p-4">
            <p className="min-w-0 flex-1 text-muted-foreground">{t('workNoListings')}</p>
            <Link
              to="/library/add"
              className="shrink-0 rounded-[12px] bg-primary px-5 py-2.5 text-sm font-bold text-primary-foreground"
            >
              {t('shelfListItNow')}
            </Link>
          </div>
        ) : (
          <BookGrid>
            {listings.map((listing, index) => (
              <BookCard key={listing.id} item={listing} eager={index < 5} />
            ))}
          </BookGrid>
        )}
      </section>

      <section className="mt-10">
        <div className="mb-4 flex flex-wrap items-center justify-between gap-3">
          <h2 className="font-display text-lg font-bold">{t('workReviewsTitle')}</h2>
          {/* Un singur review per carte per user: dacă are deja unul, i se
              oferă ștergerea, nu încă o scriere care ar fi refuzată. */}
          {myReview ? (
            <Button
              variant="outline"
              loading={deleteReview.isPending}
              onClick={() => deleteReview.mutate()}
            >
              <Trash2 size={16} />
              {t('workDeleteReview')}
            </Button>
          ) : (
            <Button onClick={() => setWriting((open) => !open)}>{t('workWriteReview')}</Button>
          )}
        </div>

        {writing && !myReview && (
          <form
            onSubmit={onSubmitReview}
            className="mb-4 flex flex-col gap-3 rounded-[16px] border border-border bg-card p-4"
          >
            <StarPicker value={rating} onChange={setRating} />
            <textarea
              value={text}
              onChange={(event) => setText(event.target.value)}
              rows={4}
              placeholder={t('workWriteReview')}
              aria-label={t('workWriteReview')}
              className="w-full resize-y rounded-[16px] bg-muted px-4 py-3.5 text-foreground placeholder:text-muted-foreground focus:outline-none"
            />
            <div className="flex gap-2">
              <Button type="submit" loading={submitReview.isPending} disabled={rating < 1}>
                {t('commonSubmit')}
              </Button>
              <Button type="button" variant="text" onClick={() => setWriting(false)}>
                {t('commonCancel')}
              </Button>
            </div>
          </form>
        )}

        {reviews.reviews.length === 0 ? (
          <p className="py-12 text-center text-muted-foreground">{t('workNoReviews')}</p>
        ) : (
          <ul className="flex flex-col gap-3">
            {reviews.reviews.map((review) => (
              <ReviewRow key={review.id} review={review} locale={i18n.language} />
            ))}
          </ul>
        )}
      </section>
    </div>
  );
}

function ReviewRow({ review, locale }: { review: BookReview; locale: string }) {
  const { t } = useTranslation();
  const name = review.authorName ?? t('commonAnonymousUser');

  return (
    <li className="rounded-[16px] border border-border bg-card p-4">
      <div className="mb-2 flex items-center gap-2">
        <Avatar src={review.authorAvatar} name={name} size={28} />
        <span className="truncate text-sm font-semibold">{name}</span>
        <span className="flex shrink-0 items-center gap-0.5">
          {Array.from({ length: 5 }, (_, index) => (
            <Star
              key={index}
              size={13}
              className={index < review.rating ? 'fill-warning text-warning' : 'text-border'}
            />
          ))}
        </span>
        <span className="ml-auto shrink-0 text-xs text-muted-foreground">
          {formatRelativeTime(review.createdAt, locale)}
        </span>
      </div>
      {review.text && <p className="whitespace-pre-line break-words">{review.text}</p>}
    </li>
  );
}

function StarPicker({ value, onChange }: { value: number; onChange: (value: number) => void }) {
  return (
    <div className="flex gap-1">
      {Array.from({ length: 5 }, (_, index) => {
        const star = index + 1;
        return (
          <button
            key={star}
            type="button"
            onClick={() => onChange(star)}
            aria-label={`${star}`}
            className="p-0.5"
          >
            <Star
              size={26}
              className={star <= value ? 'fill-warning text-warning' : 'text-border'}
            />
          </button>
        );
      })}
    </div>
  );
}
