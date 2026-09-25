import { Fragment, useState, type ReactNode } from 'react';
import {
  useInfiniteQuery,
  useMutation,
  useQuery,
  useQueryClient,
  type InfiniteData,
} from '@tanstack/react-query';
import { Link } from 'react-router-dom';
import { useTranslation } from 'react-i18next';
import {
  ArrowLeftRight,
  Bell,
  Bookmark,
  BookOpen,
  ChevronRight,
  Flag,
  Heart,
  MessageCircle,
  Search,
  Send,
  Star,
  Trash2,
} from 'lucide-react';
import { HeaderAction, ScreenHeader } from '@/components/layout/ScreenHeader';
import {
  FEED_PAGE_SIZE,
  profileKeys,
  profileRepository,
  type ActivityEntry,
  type FeedComment,
  type FeedKind,
  type FeedScope,
} from './profileRepository';
import { listsKeys, wishlistRepository } from '@/features/lists/listsRepository';
import { shelfKeys, shelfRepository } from '@/features/shelf/shelfRepository';
import { BookCover } from '@/components/ui/BookCover';
import { Avatar } from '@/components/ui/Avatar';
import { ErrorNotice, Spinner } from '@/components/ui';
import { useToast } from '@/components/ui/Toast';
import { formatRelativeTime } from '@/lib/utils/time';
import { cn } from '@/lib/utils/cn';
import { useAuth } from '@/features/auth/AuthProvider';

type Filter = 'all' | 'friends' | 'reading' | 'exchanges' | 'nearby';

/** Cum se traduce fiecare filtru în parametrii de pe server. */
const FILTERS: { id: Filter; labelKey: string; scope: FeedScope; kind?: FeedKind }[] = [
  { id: 'all', labelKey: 'feedFilterAll', scope: 'all' },
  { id: 'friends', labelKey: 'feedFilterFriends', scope: 'following' },
  { id: 'reading', labelKey: 'feedFilterReading', scope: 'all', kind: 'reading' },
  { id: 'exchanges', labelKey: 'feedFilterExchanges', scope: 'all', kind: 'exchanges' },
  { id: 'nearby', labelKey: 'feedFilterNearby', scope: 'nearby' },
];

type FeedPages = InfiniteData<ActivityEntry[], number>;

/**
 * Feedul: ce citesc, adaugă și schimbă cei urmăriți și cititorii din oraș.
 * Fiecare eveniment e un card cu coperta în stânga și acțiunile lui jos -
 * apreciere, comentarii, favorite și acțiunea principală a tipului („Și eu o
 * citesc", „Vezi cartea"). Schimburile ies în evidență: sunt miezul aplicației.
 */
export function ActivityFeedScreen() {
  const { t, i18n } = useTranslation();
  const { user } = useAuth();
  const [filter, setFilter] = useState<Filter>('all');
  const active = FILTERS.find((f) => f.id === filter)!;

  const feed = useInfiniteQuery({
    queryKey: profileKeys.activityFeed(filter),
    queryFn: ({ pageParam, signal }) =>
      profileRepository.activityFeed(
        { scope: active.scope, kind: active.kind, offset: pageParam },
        signal,
      ),
    initialPageParam: 0,
    // O pagină incompletă înseamnă că s-a terminat - nu mai cerem una goală.
    getNextPageParam: (last, pages) =>
      last.length < FEED_PAGE_SIZE ? undefined : pages.length * FEED_PAGE_SIZE,
  });

  const header = (
    <ScreenHeader
      title={t('feedTitle')}
      actions={
        <>
          <HeaderAction to="/search" label={t('addBookSearchButton')}>
            <Search size={22} />
          </HeaderAction>
          <HeaderAction to="/notifications" label={t('notificationsTitle')}>
            <Bell size={22} />
          </HeaderAction>
        </>
      }
    />
  );

  const events = feed.data?.pages.flat() ?? [];
  // Paginarea pe offset poate aduce același eveniment de două ori dacă între
  // timp a apărut unul nou deasupra; cheia stabilă îl face ușor de eliminat.
  const unique = events.filter((e, i) => events.findIndex((x) => x.id === e.id) === i);

  const emptyText =
    filter === 'nearby'
      ? user?.city
        ? t('feedEmptyNearby')
        : t('feedEmptyNoCity')
      : filter === 'all' || filter === 'friends'
        ? t('activityFeedEmpty')
        : t('feedEmptyFilter');

  return (
    <div className="mx-auto w-full max-w-[760px] px-4 pb-16 pt-2 sm:px-6">
      {header}

      <div className="-mx-4 mb-4 flex gap-2 overflow-x-auto px-4 pb-1 sm:mx-0 sm:px-0 [scrollbar-width:none]">
        {FILTERS.map((option) => (
          <button
            key={option.id}
            onClick={() => setFilter(option.id)}
            aria-pressed={filter === option.id}
            className={cn(
              'shrink-0 rounded-full px-4 py-2 text-sm font-medium transition-colors',
              filter === option.id
                ? 'bg-accent text-accent-foreground'
                : 'border border-border bg-card text-foreground hover:bg-muted',
            )}
          >
            {t(option.labelKey)}
          </button>
        ))}
      </div>

      {feed.isPending ? (
        <div className="flex min-h-[40vh] items-center justify-center text-accent">
          <Spinner size={28} />
        </div>
      ) : feed.isError ? (
        <ErrorNotice message={t('activityFeedLoadError')} onRetry={() => void feed.refetch()} />
      ) : unique.length === 0 ? (
        <p className="py-16 text-center text-muted-foreground">{emptyText}</p>
      ) : (
        <>
          <ul className="flex flex-col gap-3">
            {unique.map((entry) => (
              <li key={entry.id}>
                <FeedCard entry={entry} locale={i18n.language} />
              </li>
            ))}
          </ul>
          {feed.hasNextPage && (
            <div className="mt-6 flex justify-center">
              <button
                onClick={() => void feed.fetchNextPage()}
                disabled={feed.isFetchingNextPage}
                className="flex items-center gap-2 rounded-full border border-border px-5 py-2 text-sm hover:bg-muted"
              >
                {feed.isFetchingNextPage && <Spinner size={14} />}
                {t('feedLoadMore')}
              </button>
            </div>
          )}
        </>
      )}
    </div>
  );
}

/**
 * Schimbă un eveniment în TOATE listele de feed din cache: același eveniment
 * poate sta și în „Toate", și în „Prieteni", iar o inimă aprinsă într-una
 * trebuie să fie aprinsă și în cealaltă la schimbarea filtrului.
 */
function usePatchEvent() {
  const queryClient = useQueryClient();
  return (match: (e: ActivityEntry) => boolean, patch: Partial<ActivityEntry>) => {
    queryClient.setQueriesData<FeedPages>({ queryKey: profileKeys.activityFeed() }, (data) =>
      data
        ? {
            ...data,
            pages: data.pages.map((page) => page.map((e) => (match(e) ? { ...e, ...patch } : e))),
          }
        : data,
    );
  };
}

function FeedCard({ entry, locale }: { entry: ActivityEntry; locale: string }) {
  const [commentsOpen, setCommentsOpen] = useState(false);
  const isExchange = entry.type === 'completed_exchange';

  return (
    <article
      className={cn(
        'rounded-[18px] border p-4',
        isExchange
          ? 'border-accent/40 bg-gradient-to-br from-accent/20 via-accent/5 to-card'
          : 'border-border bg-card',
      )}
    >
      {isExchange ? (
        <ExchangeBody entry={entry} locale={locale} />
      ) : (
        <BookBody entry={entry} locale={locale} />
      )}

      <FeedActions entry={entry} onToggleComments={() => setCommentsOpen((open) => !open)} />
      {commentsOpen && <CommentsThread entry={entry} />}
    </article>
  );
}

/** Cardul obișnuit: copertă în stânga, cine + ce + carte în dreapta. */
function BookBody({ entry, locale }: { entry: ActivityEntry; locale: string }) {
  const { t } = useTranslation();
  const name = entry.userName ?? t('commonUnknownUser');

  return (
    <div className="flex gap-4">
      <BookLink entry={entry} className="w-[76px] shrink-0 sm:w-[100px]">
        <div className="aspect-[2/3] overflow-hidden rounded-[10px] bg-muted shadow-md">
          <BookCover url={entry.bookCoverUrl} title={entry.bookTitle} />
        </div>
      </BookLink>

      <div className="min-w-0 flex-1">
        <EventHeader entry={entry} locale={locale} />

        {entry.type === 'new_listing' && (
          <p className="mt-2 text-muted-foreground">{t('activityNewListing')}</p>
        )}
        {entry.type === 'finished_book' && (
          <p className="mt-2 text-muted-foreground">{t('feedFinishedLine', { name })}</p>
        )}
        {entry.type === 'sale' && (
          <p className="mt-2 text-muted-foreground">
            {t('activitySale', { amount: entry.amount ?? 0 })}
          </p>
        )}

        <BookLink entry={entry}>
          <p className={cn('font-display text-lg font-bold leading-snug hover:underline', entry.type === 'reading_progress' && 'mt-2')}>
            {entry.bookTitle}
          </p>
        </BookLink>
        {entry.bookAuthor && <p className="text-muted-foreground">{entry.bookAuthor}</p>}

        {entry.type === 'new_listing' && entry.caption && (
          <p className="mt-1.5 line-clamp-2 italic text-muted-foreground">„{entry.caption}”</p>
        )}

        {entry.type === 'finished_book' && (entry.rating || entry.reviewText) && (
          <div className="mt-1.5 flex flex-wrap items-center gap-x-3 gap-y-1">
            {!!entry.rating && <Stars rating={entry.rating} />}
            {entry.reviewText && (
              <p className="line-clamp-2 italic text-muted-foreground">„{entry.reviewText}”</p>
            )}
          </div>
        )}

        {entry.type === 'reading_progress' && entry.currentPage !== undefined && (
          <ReadingProgressBar current={entry.currentPage} total={entry.totalPages ?? null} />
        )}
      </div>
    </div>
  );
}

/** Avatar, nume, eticheta tipului și vârsta evenimentului. */
function EventHeader({ entry, locale }: { entry: ActivityEntry; locale: string }) {
  const { t } = useTranslation();
  const name = entry.userName ?? t('commonUnknownUser');
  const badge = {
    new_listing: { key: 'activityBadgeNew', tone: 'neutral' },
    finished_book: { key: 'feedBadgeFinished', tone: 'success' },
    completed_exchange: { key: 'activityBadgeExchange', tone: 'accent' },
    sale: { key: 'activityBadgeSale', tone: 'accent' },
    reading_progress: { key: 'feedBadgeReading', tone: 'neutral' },
  }[entry.type];

  return (
    // `flex-wrap`: pe telefon eticheta coboară sub nume în loc să-l taie.
    <div className="flex flex-wrap items-center gap-x-2 gap-y-1">
      <Link to={`/users/${entry.userId}`} className="flex min-w-0 max-w-full items-center gap-2">
        <Avatar src={entry.userAvatar} name={name} size={30} />
        <span className="truncate font-semibold hover:underline">{name}</span>
      </Link>
      <span
        className={cn(
          'shrink-0 rounded-full border px-2.5 py-0.5 text-xs',
          badge.tone === 'success' && 'border-success/50 text-success',
          badge.tone === 'accent' && 'border-accent/50 text-accent',
          badge.tone === 'neutral' && 'border-border text-muted-foreground',
        )}
      >
        {t(badge.key)}
      </span>
      <span className="ml-auto shrink-0 text-xs text-muted-foreground">
        {formatRelativeTime(entry.date, locale)}
      </span>
    </div>
  );
}

/**
 * Schimbul: cele două coperți cu săgeți între ele și o propoziție pe trei
 * rânduri - „Andrada a schimbat / Jane Eyre pe Solenoid / cu Alina".
 */
function ExchangeBody({ entry, locale }: { entry: ActivityEntry; locale: string }) {
  const { t } = useTranslation();
  const { user } = useAuth();
  const name = entry.userName ?? t('commonUnknownUser');
  const counterpartyName = entry.counterpartyName ?? t('commonUnknownUser');
  const withViewer = !!user && entry.counterpartyId === user.id;

  const given = entry.givenBookTitle
    ? { title: entry.givenBookTitle, cover: entry.givenBookCoverUrl ?? null }
    : null;
  const received = entry.receivedBookTitle
    ? { title: entry.receivedBookTitle, cover: entry.receivedBookCoverUrl ?? null }
    : null;
  const covers =
    given || received
      ? [given, received].filter((b): b is { title: string; cover: string | null } => !!b)
      : [{ title: entry.bookTitle, cover: entry.bookCoverUrl }];

  const accent = (text?: string) => <span className="text-accent">{text}</span>;
  const strong = (text?: string) => <span>{text}</span>;
  const counterparty = entry.counterpartyId ? (
    <Link
      to={`/users/${entry.counterpartyId}`}
      className="inline-flex items-center gap-1.5 align-middle font-semibold text-foreground hover:underline"
    >
      <Avatar src={entry.counterpartyAvatar} name={counterpartyName} size={22} />
      {counterpartyName}
    </Link>
  ) : (
    <strong className="font-semibold text-foreground">{counterpartyName}</strong>
  );

  // Carte contra carte: propoziția scurtă din machetă. Celelalte forme (a
  // primit / a dat, fără carte la schimb) folosesc frazele deja traduse.
  const you = withViewer ? 'You' : '';
  const fallbackKey = received
    ? `activityExchangeGot${you}`
    : given
      ? `activityExchangeGave${you}`
      : `activityExchangeWith${you}`;

  return (
    // Pe telefon coperțile stau deasupra textului: alăturate, cele două
    // coperți plus săgeata lăsau propoziției sub jumătate de card.
    <div className="flex flex-col gap-4 sm:flex-row">
      <div className="flex shrink-0 items-center gap-2.5">
        {covers.map((book, i) => (
          <Fragment key={i}>
            {i === 1 && <ArrowLeftRight size={22} className="text-accent" aria-hidden />}
            <div className="aspect-[2/3] w-[76px] overflow-hidden rounded-[8px] bg-muted shadow-md sm:w-[82px]">
              <BookCover url={book.cover} title={book.title} />
            </div>
          </Fragment>
        ))}
      </div>

      <div className="min-w-0 flex-1">
        <EventHeader entry={entry} locale={locale} />
        {given && received ? (
          <>
            <p className="mt-2 text-muted-foreground">{t('feedExchangedLine', { name })}</p>
            <p className="font-display text-lg font-bold leading-snug">
              {fillSlots(t('feedExchangeBooks', { given: SLOT.given, received: SLOT.received }), {
                given: accent(given.title),
                received: strong(received.title),
              })}
            </p>
            <p className="mt-1 text-sm text-muted-foreground">
              {withViewer ? (
                t('feedExchangeWithYou')
              ) : (
                <>
                  {t('feedExchangeWith')} {counterparty}
                </>
              )}
            </p>
          </>
        ) : (
          <p className="mt-2 text-muted-foreground">
            {fillSlots(
              t(fallbackKey, {
                book: SLOT.book,
                counterparty: SLOT.counterparty,
              }),
              {
                book: <strong className="text-foreground">{(received ?? given)?.title}</strong>,
                counterparty,
              },
            )}
          </p>
        )}
      </div>
    </div>
  );
}

/**
 * Rândul de jos: apreciere, comentarii, favorite, apoi acțiunea principală a
 * tipului. Toate se actualizează optimist - un click pe inimă nu așteaptă
 * serverul să se aprindă.
 */
function FeedActions({ entry, onToggleComments }: { entry: ActivityEntry; onToggleComments: () => void }) {
  const { t } = useTranslation();
  const toast = useToast();
  const queryClient = useQueryClient();
  const patch = usePatchEvent();

  const like = useMutation({
    mutationFn: (next: boolean) => profileRepository.likeFeedEvent(entry.id, next),
    onMutate: (next) =>
      patch((e) => e.id === entry.id, {
        likedByMe: next,
        likeCount: Math.max(0, entry.likeCount + (next ? 1 : -1)),
      }),
    onSuccess: (state) => patch((e) => e.id === entry.id, state),
    onError: () => {
      patch((e) => e.id === entry.id, { likedByMe: entry.likedByMe, likeCount: entry.likeCount });
      toast.show(t('feedActionError'), 'danger');
    },
  });

  // Favoritul e pe CARTE, deci se aprinde pe toate evenimentele cu ea.
  const wishlist = useMutation({
    mutationFn: async (next: boolean) => {
      if (next) await wishlistRepository.add(entry.bookId);
      else await wishlistRepository.remove(entry.bookId);
    },
    onMutate: (next) => patch((e) => e.bookId === entry.bookId, { wishlistedByMe: next }),
    onSuccess: () => void queryClient.invalidateQueries({ queryKey: listsKeys.wishlist() }),
    onError: () => {
      patch((e) => e.bookId === entry.bookId, { wishlistedByMe: entry.wishlistedByMe });
      toast.show(t('feedActionError'), 'danger');
    },
  });

  const readToo = useMutation({
    mutationFn: () => shelfRepository.setStatus(entry.bookId, { status: 'READING' }),
    onSuccess: () => {
      patch((e) => e.bookId === entry.bookId, { readingByMe: true });
      void queryClient.invalidateQueries({ queryKey: shelfKeys.all });
      toast.show(t('feedReadingTooAdded'));
    },
    onError: () => toast.show(t('feedActionError'), 'danger'),
  });

  const iconButton = 'flex items-center gap-1.5 rounded-md py-1 text-muted-foreground transition-colors hover:text-foreground';

  return (
    <div className="mt-4 flex items-center gap-5 border-t border-border/60 pt-3">
      <button
        onClick={() => like.mutate(!entry.likedByMe)}
        aria-pressed={entry.likedByMe}
        aria-label={t('feedLike')}
        className={cn(iconButton, entry.likedByMe && 'text-destructive hover:text-destructive')}
      >
        <Heart size={20} className={cn(entry.likedByMe && 'fill-current')} />
        {entry.likeCount > 0 && <span className="text-sm">{entry.likeCount}</span>}
      </button>

      <button onClick={onToggleComments} aria-label={t('feedComments')} className={iconButton}>
        <MessageCircle size={20} />
        {entry.commentCount > 0 && <span className="text-sm">{entry.commentCount}</span>}
      </button>

      <button
        onClick={() => wishlist.mutate(!entry.wishlistedByMe)}
        aria-pressed={entry.wishlistedByMe}
        aria-label={t('feedFavorite')}
        title={t('feedFavorite')}
        className={cn(iconButton, entry.wishlistedByMe && 'text-accent hover:text-accent')}
      >
        <Bookmark size={20} className={cn(entry.wishlistedByMe && 'fill-current')} />
      </button>

      <div className="ml-auto">
        {entry.type === 'reading_progress' ? (
          <button
            onClick={() => readToo.mutate()}
            disabled={entry.readingByMe || readToo.isPending}
            className={cn(
              'flex items-center gap-2 rounded-full border px-4 py-2 text-sm font-semibold transition-colors',
              entry.readingByMe
                ? 'border-border text-muted-foreground'
                : 'border-accent text-accent hover:bg-accent/10',
            )}
          >
            {readToo.isPending ? <Spinner size={14} /> : <BookOpen size={17} />}
            {t(entry.readingByMe ? 'feedReadingTooDone' : 'feedIAmReadingToo')}
          </button>
        ) : (
          <BookLink
            entry={entry}
            className="flex items-center gap-1 rounded-full border border-border px-4 py-2 text-sm font-semibold hover:bg-muted"
          >
            {t('feedViewBook')}
            <ChevronRight size={16} />
          </BookLink>
        )}
      </div>
    </div>
  );
}

/** Anunțul, când evenimentul e unul; altfel pagina operei. */
function BookLink({
  entry,
  className,
  children,
}: {
  entry: ActivityEntry;
  className?: string;
  children: ReactNode;
}) {
  const to = entry.userBookId ? `/books/${entry.userBookId}` : `/work/${entry.bookId}`;
  return (
    <Link to={to} className={className}>
      {children}
    </Link>
  );
}

const REPORT_REASONS = [
  ['SPAM', 'reportReasonSpam'],
  ['ABUSIVE_LANGUAGE', 'reportReasonAbusiveLanguage'],
  ['FALSE_CONTENT', 'reportReasonFalseContent'],
  ['INAPPROPRIATE', 'reportReasonInappropriate'],
  ['OTHER', 'reportReasonOther'],
] as const;

/** Comentariile unui eveniment, încărcate abia la deschidere. */
function CommentsThread({ entry }: { entry: ActivityEntry }) {
  const { t, i18n } = useTranslation();
  const toast = useToast();
  const queryClient = useQueryClient();
  const patch = usePatchEvent();
  const [text, setText] = useState('');
  const [reporting, setReporting] = useState<string | null>(null);
  const key = profileKeys.feedComments(entry.id);

  const comments = useQuery({
    queryKey: key,
    queryFn: ({ signal }) => profileRepository.feedComments(entry.id, signal),
  });

  const setCount = (list: FeedComment[]) =>
    patch((e) => e.id === entry.id, { commentCount: list.length });

  const add = useMutation({
    mutationFn: () => profileRepository.addFeedComment(entry.id, text.trim()),
    onSuccess: (comment) => {
      const next = [...(comments.data ?? []), comment];
      queryClient.setQueryData(key, next);
      setCount(next);
      setText('');
    },
    onError: () => toast.show(t('feedCommentError'), 'danger'),
  });

  const remove = useMutation({
    mutationFn: (id: string) => profileRepository.deleteFeedComment(id),
    onSuccess: (_, id) => {
      const next = (comments.data ?? []).filter((c) => c.id !== id);
      queryClient.setQueryData(key, next);
      setCount(next);
    },
    onError: () => toast.show(t('feedActionError'), 'danger'),
  });

  const report = useMutation({
    mutationFn: ({ id, reason }: { id: string; reason: string }) =>
      profileRepository.reportFeedComment(id, reason),
    onSuccess: () => {
      setReporting(null);
      toast.show(t('feedCommentReported'));
    },
    onError: (error) =>
      toast.show(error instanceof Error ? error.message : t('feedActionError'), 'danger'),
  });

  return (
    <section className="mt-3 border-t border-border/60 pt-3">
      {comments.isPending ? (
        <div className="flex justify-center py-3 text-accent">
          <Spinner size={18} />
        </div>
      ) : comments.data && comments.data.length > 0 ? (
        <ul className="flex flex-col gap-3">
          {comments.data.map((comment) => {
            const author = comment.user.name ?? t('commonUnknownUser');
            return (
              <li key={comment.id} className="group flex gap-2.5">
                <Link to={`/users/${comment.user.id}`} className="shrink-0">
                  <Avatar src={comment.user.profileImage} name={author} size={28} />
                </Link>
                <div className="min-w-0 flex-1">
                  <div className="rounded-[12px] bg-muted/60 px-3 py-2">
                    <Link to={`/users/${comment.user.id}`} className="text-sm font-semibold hover:underline">
                      {author}
                    </Link>
                    <p className="whitespace-pre-line break-words text-sm">{comment.text}</p>
                  </div>
                  <div className="mt-1 flex items-center gap-3 px-1 text-xs text-muted-foreground">
                    <span>{formatRelativeTime(comment.createdAt, i18n.language)}</span>
                    {comment.canDelete && (
                      <button
                        onClick={() => remove.mutate(comment.id)}
                        className="flex items-center gap-1 hover:text-foreground"
                      >
                        <Trash2 size={12} />
                        {t('feedCommentDelete')}
                      </button>
                    )}
                    {!comment.isMine && (
                      <button
                        onClick={() => setReporting(reporting === comment.id ? null : comment.id)}
                        className="flex items-center gap-1 hover:text-foreground"
                      >
                        <Flag size={12} />
                        {t('feedCommentReport')}
                      </button>
                    )}
                  </div>
                  {reporting === comment.id && (
                    <div className="mt-2 rounded-[12px] border border-border p-3">
                      <p className="mb-2 text-sm font-semibold">{t('feedCommentReportTitle')}</p>
                      <div className="flex flex-wrap gap-2">
                        {REPORT_REASONS.map(([reason, labelKey]) => (
                          <button
                            key={reason}
                            disabled={report.isPending}
                            onClick={() => report.mutate({ id: comment.id, reason })}
                            className="rounded-full border border-border px-3 py-1 text-xs hover:bg-muted"
                          >
                            {t(labelKey)}
                          </button>
                        ))}
                      </div>
                    </div>
                  )}
                </div>
              </li>
            );
          })}
        </ul>
      ) : (
        <p className="py-1 text-sm text-muted-foreground">{t('feedNoComments')}</p>
      )}

      <form
        className="mt-3 flex items-end gap-2"
        onSubmit={(event) => {
          event.preventDefault();
          if (text.trim() && !add.isPending) add.mutate();
        }}
      >
        <textarea
          value={text}
          onChange={(event) => setText(event.target.value)}
          onKeyDown={(event) => {
            // Enter trimite, Shift+Enter rupe rândul - ca în chat.
            if (event.key === 'Enter' && !event.shiftKey) {
              event.preventDefault();
              if (text.trim() && !add.isPending) add.mutate();
            }
          }}
          rows={1}
          maxLength={1000}
          placeholder={t('feedCommentPlaceholder')}
          className="max-h-32 min-h-[40px] flex-1 resize-none rounded-[12px] border border-border bg-background px-3 py-2 text-sm outline-none focus:border-accent"
        />
        <button
          type="submit"
          disabled={!text.trim() || add.isPending}
          aria-label={t('feedCommentSend')}
          className="flex size-10 shrink-0 items-center justify-center rounded-full bg-accent text-accent-foreground disabled:opacity-50"
        >
          {add.isPending ? <Spinner size={16} /> : <Send size={17} />}
        </button>
      </form>
    </section>
  );
}

function Stars({ rating }: { rating: number }) {
  return (
    <span className="flex items-center gap-0.5" aria-label={`${rating}/5`}>
      {[1, 2, 3, 4, 5].map((value) => (
        <Star
          key={value}
          size={17}
          className={value <= rating ? 'fill-warning text-warning' : 'text-warning/60'}
        />
      ))}
    </span>
  );
}

/**
 * Marcaje puse în locul variabilelor la traducere, ca propoziția să poată fi
 * tăiată apoi în bucăți și variabilele înlocuite cu JSX (titluri colorate,
 * link spre profil). Ordinea lor diferă de la o limbă la alta.
 */
const SLOT = {
  given: '[[given]]',
  received: '[[received]]',
  book: '[[book]]',
  counterparty: '[[counterparty]]',
};

function fillSlots(text: string, slots: Record<string, ReactNode>) {
  return text.split(/\[\[(\w+)\]\]/).map((part, i) =>
    // split cu grup de captură: pozițiile impare sunt numele marcajelor.
    i % 2 === 1 ? <Fragment key={i}>{slots[part]}</Fragment> : part,
  );
}

/** Cât a citit: „Pagina X din Y · 47%" și o bară. Fără total, doar pagina. */
function ReadingProgressBar({ current, total }: { current: number; total: number | null }) {
  const { t } = useTranslation();
  const percent = total ? Math.min(100, Math.round((current / total) * 100)) : null;

  return (
    <div className="mt-2">
      <p className="text-sm text-muted-foreground">
        {total
          ? t('bookshelfProgressLabel', { current, total })
          : t('bookshelfProgressLabelNoTotal', { current })}
        {percent !== null && ` · ${percent}%`}
      </p>
      {percent !== null && (
        <div
          className="mt-2 h-2 w-full overflow-hidden rounded-full bg-muted"
          role="progressbar"
          aria-valuenow={percent}
          aria-valuemin={0}
          aria-valuemax={100}
        >
          <div className="h-full rounded-full bg-accent" style={{ width: `${percent}%` }} />
        </div>
      )}
    </div>
  );
}
