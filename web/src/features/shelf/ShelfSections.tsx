import { useEffect, useRef, useState, type ReactNode } from 'react';
import { useMutation, useQueryClient } from '@tanstack/react-query';
import { Link, useNavigate } from 'react-router-dom';
import { useTranslation } from 'react-i18next';
import { ArrowRight, Check, MoreVertical, Store } from 'lucide-react';
import {
  shelfItemProgress,
  shelfKeys,
  shelfRepository,
  type ShelfItem,
  type ShelfStatus,
} from './shelfRepository';
import { booksKeys } from '@/features/books/booksRepository';
import { BookCover } from '@/components/ui/BookCover';
import { Button } from '@/components/ui';
import { useToast } from '@/components/ui/Toast';
import { cn } from '@/lib/utils/cn';

/** Fila din My Shelf în care se află lista - schimbă ce acțiuni are fiecare rând. */
export type ShelfTab = 'owned' | 'read' | 'toRead';

/**
 * „Citesc acum" - bandă orizontală deasupra filelor, doar când există cărți
 * în curs de citire. E locul unde omul revine cel mai des, deci progresul se
 * actualizează de aici dintr-un singur gest („Continuă").
 */
export function CurrentlyReadingStrip({ items }: { items: ShelfItem[] }) {
  const { t } = useTranslation();
  const [editing, setEditing] = useState<ShelfItem | null>(null);

  if (items.length === 0) return null;

  return (
    <section className="mb-6">
      <h2 className="mb-2.5 font-semibold">{t('shelfCurrentlyReadingTitle')}</h2>
      <ul className="flex gap-3 overflow-x-auto pb-2">
        {items.map((item) => {
          const fraction = shelfItemProgress(item);
          return (
            <li
              key={item.bookId}
              className="flex w-[min(78vw,300px)] shrink-0 gap-3 rounded-[16px] border border-border bg-card p-3"
            >
              <Link
                to={`/work/${item.bookId}`}
                className="aspect-[2/3] w-[64px] shrink-0 overflow-hidden rounded-[6px] bg-muted"
              >
                <BookCover url={item.book.coverUrl} title={item.book.title} />
              </Link>
              <div className="flex min-w-0 flex-1 flex-col">
                <Link to={`/work/${item.bookId}`} className="line-clamp-2 font-semibold leading-tight">
                  {item.book.title}
                </Link>
                {item.book.author && (
                  <p className="truncate text-sm text-muted-foreground">{item.book.author}</p>
                )}
                <div className="mt-auto pt-2">
                  {fraction !== null && (
                    <div className="mb-1 flex items-center gap-2">
                      <span className="h-[5px] flex-1 overflow-hidden rounded bg-muted">
                        <span
                          className="block h-full rounded bg-accent"
                          style={{ width: `${Math.round(fraction * 100)}%` }}
                        />
                      </span>
                      <span className="text-xs font-semibold tabular-nums">
                        {Math.round(fraction * 100)}%
                      </span>
                    </div>
                  )}
                  <button
                    onClick={() => setEditing(item)}
                    className="flex items-center gap-1 text-sm font-semibold text-accent hover:underline"
                  >
                    {t('shelfContinueReading')}
                    <ArrowRight size={15} />
                  </button>
                </div>
              </div>
            </li>
          );
        })}
      </ul>

      {editing && <ReadingProgressSheet item={editing} onClose={() => setEditing(null)} />}
    </section>
  );
}

/** Lista unei file (Deținute / Citite / De citit). */
export function ShelfBookList({
  items,
  tab,
  empty,
}: {
  items: ShelfItem[];
  tab: ShelfTab;
  empty: ReactNode;
}) {
  if (items.length === 0) {
    return <div className="py-12 text-center text-muted-foreground">{empty}</div>;
  }
  return (
    <ul className="flex flex-col gap-2">
      {items.map((item) => (
        <ShelfBookRow key={item.bookId} item={item} tab={tab} />
      ))}
    </ul>
  );
}

function ShelfBookRow({ item, tab }: { item: ShelfItem; tab: ShelfTab }) {
  const { t } = useTranslation();
  const navigate = useNavigate();
  const queryClient = useQueryClient();
  const toast = useToast();

  const [editing, setEditing] = useState(false);
  const [menuOpen, setMenuOpen] = useState(false);
  const menu = useRef<HTMLDivElement>(null);

  useEffect(() => {
    if (!menuOpen) return;
    const onDown = (event: MouseEvent) => {
      if (!menu.current?.contains(event.target as Node)) setMenuOpen(false);
    };
    document.addEventListener('mousedown', onDown);
    return () => document.removeEventListener('mousedown', onDown);
  }, [menuOpen]);

  const update = useMutation({
    mutationFn: (input: { status?: ShelfStatus | null; owned?: boolean }) =>
      shelfRepository.update(item.bookId, input),
    onSuccess: () => void queryClient.invalidateQueries({ queryKey: shelfKeys.all }),
    onError: () => toast.show(t('commonGenericError'), 'danger'),
  });

  function change(input: { status?: ShelfStatus | null; owned?: boolean }) {
    setMenuOpen(false);
    update.mutate(input);
  }

  /**
   * Listarea: formularul de anunț, precompletat cu cartea. Cartea primită
   * printr-un schimb are deja un exemplar al userului, doar nescos în piață -
   * pe acela îl re-listăm, altfel am crea al doilea rând pentru aceeași carte.
   */
  function listNow() {
    setMenuOpen(false);
    const params = new URLSearchParams({
      mode: 'listing',
      from: 'shelf',
      bookId: item.book.id,
      title: item.book.title,
    });
    if (item.book.author) params.set('author', item.book.author);
    if (item.book.isbn) params.set('isbn', item.book.isbn);
    if (item.book.coverUrl) params.set('cover', item.book.coverUrl);
    if (item.relistSourceId) params.set('relistFrom', item.relistSourceId);
    void navigate(`/library/add?${params}`);
  }

  // „Nu o mai am" doar pentru ce a marcat omul singur: o carte cu exemplar în
  // aplicație (anunț, carte primită) e deținută prin exemplarul acela.
  const ownedByCopy = item.listed || !!item.relistSourceId;
  const canList = item.owned && !item.listed;

  const menuItems: { label: string; onClick: () => void }[] = [];
  if (item.status === 'READING' || (tab === 'owned' && item.status !== 'FINISHED')) {
    menuItems.push({
      label: t('shelfUpdateProgress'),
      onClick: () => {
        setMenuOpen(false);
        setEditing(true);
      },
    });
  }
  if (item.status !== 'READING') {
    menuItems.push({ label: t('shelfMarkReading'), onClick: () => change({ status: 'READING' }) });
  }
  if (item.status !== 'FINISHED') {
    menuItems.push({ label: t('shelfMarkRead'), onClick: () => change({ status: 'FINISHED' }) });
  }
  if (item.status == null) {
    menuItems.push({ label: t('shelfMarkToRead'), onClick: () => change({ status: 'WANT_TO_READ' }) });
  }
  if (!item.owned) {
    menuItems.push({ label: t('shelfMarkOwned'), onClick: () => change({ owned: true }) });
  } else if (!ownedByCopy) {
    menuItems.push({ label: t('shelfMarkNotOwned'), onClick: () => change({ owned: false }) });
  }
  if (canList) {
    menuItems.push({ label: t('shelfListBook'), onClick: listNow });
  }
  if (item.status != null && tab !== 'owned') {
    menuItems.push({
      label: t(tab === 'read' ? 'shelfRemoveFromRead' : 'shelfRemoveFromToRead'),
      onClick: () => change({ status: null }),
    });
  }
  menuItems.push({
    label: t('workTitle'),
    onClick: () => void navigate(`/work/${item.bookId}`),
  });

  const fraction = shelfItemProgress(item);

  return (
    <li className="rounded-[16px] border border-border bg-card p-3">
      <div className="flex items-start gap-3">
        <Link
          to={`/work/${item.bookId}`}
          className="h-[62px] w-11 shrink-0 overflow-hidden rounded-lg bg-muted"
        >
          <BookCover url={item.book.coverUrl} title={item.book.title} />
        </Link>

        <Link to={`/work/${item.bookId}`} className="min-w-0 flex-1">
          <span className="flex flex-wrap items-center gap-1.5">
            <span className="min-w-0 truncate font-semibold">{item.book.title}</span>
            {item.listed && <Chip tone="accent">{t('shelfOwnedListedBadge')}</Chip>}
            {tab !== 'owned' && item.owned && !item.listed && <Chip>{t('shelfOwnedBadge')}</Chip>}
          </span>
          {item.book.author && (
            <span className="block truncate text-sm text-muted-foreground">{item.book.author}</span>
          )}
          <StatusLine item={item} fraction={fraction} tab={tab} />
        </Link>

        {/* „Listează" stă la vedere doar în „Deținute": e singurul loc în care
            listarea are sens fără alt pas. O carte citită nu e automat de dat
            mai departe - de aici a pornit toată reorganizarea. */}
        {tab === 'owned' && canList && (
          <button
            onClick={listNow}
            className="flex shrink-0 items-center gap-1.5 rounded-full border border-border px-3 py-1.5 text-sm font-semibold hover:bg-muted"
          >
            <Store size={16} />
            {t('shelfListBook')}
          </button>
        )}

        <div ref={menu} className="relative shrink-0">
          <button
            onClick={() => setMenuOpen((open) => !open)}
            aria-label={t('commonShowMore')}
            disabled={update.isPending}
            className="rounded-full p-2 text-muted-foreground hover:bg-muted hover:text-foreground"
          >
            <MoreVertical size={20} />
          </button>
          {menuOpen && (
            <div className="absolute right-0 top-full z-40 min-w-[220px] overflow-hidden rounded-[12px] border border-border bg-card py-1 shadow-xl">
              {menuItems.map((entry) => (
                <button
                  key={entry.label}
                  onClick={entry.onClick}
                  className="block w-full px-4 py-2.5 text-left text-sm hover:bg-muted"
                >
                  {entry.label}
                </button>
              ))}
            </div>
          )}
        </div>
      </div>

      {editing && <ReadingProgressSheet item={item} onClose={() => setEditing(false)} />}
    </li>
  );
}

/** Rândul de sub autor: unde e cartea pe raftul de lectură și cât s-a citit. */
function StatusLine({
  item,
  fraction,
  tab,
}: {
  item: ShelfItem;
  fraction: number | null;
  tab: ShelfTab;
}) {
  const { t } = useTranslation();

  if (item.status === 'FINISHED') {
    return (
      <span className="mt-1 flex items-center gap-1 text-sm font-medium text-success">
        <Check size={15} />
        {item.totalPages
          ? t('shelfReadWithPages', { total: item.totalPages })
          : t('shelfStatusRead')}
      </span>
    );
  }

  if (item.status === 'READING') {
    return (
      <>
        {fraction !== null && (
          <span className="mt-2 block h-[5px] overflow-hidden rounded bg-muted">
            <span
              className="block h-full rounded bg-accent"
              style={{ width: `${Math.round(fraction * 100)}%` }}
            />
          </span>
        )}
        <span className="mt-1 block text-sm text-muted-foreground">
          {item.totalPages
            ? `${t('bookshelfProgressLabel', { current: item.currentPage, total: item.totalPages })} · ${t('shelfProgressPercentLabel', { percent: Math.round((fraction ?? 0) * 100) })}`
            : item.currentPage > 0
              ? t('bookshelfProgressLabelNoTotal', { current: item.currentPage })
              : t('shelfStatusReading')}
        </span>
      </>
    );
  }

  // „De citit" e deja numele filei; se scrie doar în „Deținute", unde spune
  // ceva în plus.
  if (item.status === 'WANT_TO_READ' && tab === 'owned') {
    return <span className="mt-1 block text-sm text-muted-foreground">{t('shelfStatusToRead')}</span>;
  }
  return null;
}

function Chip({ children, tone }: { children: ReactNode; tone?: 'accent' }) {
  return (
    <span
      className={cn(
        'shrink-0 rounded-full px-2 py-0.5 text-[11px] font-semibold',
        tone === 'accent' ? 'bg-accent/15 text-accent' : 'bg-muted text-muted-foreground',
      )}
    >
      {children}
    </span>
  );
}

/**
 * Foaia de progres la citit: totalul de pagini, valoarea în pagini SAU în
 * procente, și un buton separat de „am terminat-o". Schimbă doar statusul de
 * lectură - „deținută" rămâne cum era (înainte, orice salvare de progres
 * marca și cartea ca deținută).
 */
export function ReadingProgressSheet({ item, onClose }: { item: ShelfItem; onClose: () => void }) {
  const { t } = useTranslation();
  const toast = useToast();
  const queryClient = useQueryClient();

  const [total, setTotal] = useState(item.totalPages?.toString() ?? '');
  const [unit, setUnit] = useState<'pages' | 'percent'>('pages');
  const [value, setValue] = useState(item.currentPage ? item.currentPage.toString() : '');
  const [error, setError] = useState<string | null>(null);

  const totalPages = Number(total.trim()) || null;

  const save = useMutation({
    /*
      `page: null` = „am terminat-o" fără să știm câte pagini are: nu
      inventăm un progres, doar schimbăm statusul.
    */
    mutationFn: async ({ page, finished }: { page: number | null; finished: boolean }) => {
      if (page !== null) {
        await shelfRepository.saveProgress(item.bookId, {
          currentPage: page,
          ...(totalPages ? { totalPages } : {}),
        });
      }
      // Cine ajunge la ultima pagină a terminat cartea; cine e la mijloc o
      // citește acum.
      const done = finished || (!!totalPages && page !== null && page >= totalPages);
      await shelfRepository.update(item.bookId, { status: done ? 'FINISHED' : 'READING' });
    },
    onSuccess: () => {
      void queryClient.invalidateQueries({ queryKey: shelfKeys.all });
      void queryClient.invalidateQueries({ queryKey: booksKeys.myLibrary() });
      onClose();
    },
    onError: () => toast.show(t('bookshelfProgressError'), 'danger'),
  });

  function submit(markFinished = false) {
    if (markFinished) {
      save.mutate({ page: totalPages, finished: true });
      return;
    }

    const raw = Number(value.trim());
    if (!value.trim() || !Number.isFinite(raw)) {
      setError(t('bookshelfProgressError'));
      return;
    }
    if (unit === 'percent') {
      if (!totalPages) {
        setError(t('shelfProgressNeedTotal'));
        return;
      }
      save.mutate({
        page: Math.round((Math.min(100, Math.max(0, raw)) / 100) * totalPages),
        finished: false,
      });
      return;
    }
    save.mutate({ page: raw, finished: false });
  }

  return (
    <div className="fixed inset-0 z-50 flex items-end justify-center min-[560px]:items-center">
      <button
        aria-label={t('commonCancel')}
        onClick={onClose}
        className="absolute inset-0 bg-black/50"
      />
      <div className="relative max-h-[85dvh] w-full max-w-[420px] overflow-y-auto rounded-t-[20px] bg-card p-4 min-[560px]:rounded-[20px]">
        <p className="font-semibold">{item.book.title}</p>
        {item.book.author && <p className="text-sm text-muted-foreground">{item.book.author}</p>}

        <label className="mt-4 flex flex-col gap-1.5">
          <span className="text-sm font-medium text-muted-foreground">
            {t('shelfProgressTotalPages')}
          </span>
          <input
            value={total}
            onChange={(event) => setTotal(event.target.value.replace(/\D/g, ''))}
            inputMode="numeric"
            className="w-full rounded-[16px] bg-muted px-4 py-3.5 text-foreground focus:outline-none"
          />
        </label>

        <div className="mt-3 flex overflow-hidden rounded-full border border-border">
          {(['pages', 'percent'] as const).map((option) => (
            <button
              key={option}
              onClick={() => setUnit(option)}
              className={cn(
                'flex-1 px-4 py-2 text-sm transition',
                unit === option ? 'bg-accent/15 font-semibold text-accent' : 'hover:bg-muted',
              )}
            >
              {t(option === 'pages' ? 'shelfProgressUnitPages' : 'shelfProgressUnitPercent')}
            </button>
          ))}
        </div>

        <label className="mt-3 flex flex-col gap-1.5">
          <span className="text-sm font-medium text-muted-foreground">
            {t(unit === 'pages' ? 'shelfProgressPagesRead' : 'shelfProgressPercentRead')}
          </span>
          <input
            value={value}
            onChange={(event) => setValue(event.target.value.replace(/\D/g, ''))}
            inputMode="numeric"
            autoFocus
            className="w-full rounded-[16px] bg-muted px-4 py-3.5 text-foreground focus:outline-none"
          />
        </label>

        {error && <p className="mt-2 text-sm text-destructive">{error}</p>}

        <div className="mt-4 flex gap-2">
          <Button
            variant="outline"
            fullWidth
            onClick={() => submit(true)}
            disabled={save.isPending}
          >
            {t('shelfProgressMarkFinished')}
          </Button>
          <Button fullWidth onClick={() => submit()} loading={save.isPending}>
            {t('commonSave')}
          </Button>
        </div>
      </div>
    </div>
  );
}
