import { useEffect, useRef, useState } from 'react';
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { Link, useNavigate } from 'react-router-dom';
import { useTranslation } from 'react-i18next';
import { MoreVertical, Plus, Store } from 'lucide-react';
import {
  ownedIsFinished,
  ownedProgress,
  shelfKeys,
  shelfRepository,
  type OwnedBook,
} from './shelfRepository';
import { booksKeys } from '@/features/books/booksRepository';
import { BookCover } from '@/components/ui/BookCover';
import { Button } from '@/components/ui';
import { useToast } from '@/components/ui/Toast';
import { cn } from '@/lib/utils/cn';

/**
 * Prim-planul din „Raftul meu": cărțile pe care userul le DEȚINE dar nu le-a
 * scos la listare. Sunt majoritatea rafturilor reale - cineva are acasă zeci de
 * cărți și dă mai departe câteva - deci stau deasupra anunțurilor, nu sub ele.
 *
 * Port al `owned_books_section.dart`.
 */
export function OwnedBooksSection() {
  const { t } = useTranslation();

  const owned = useQuery({
    queryKey: shelfKeys.owned(),
    queryFn: ({ signal }) => shelfRepository.owned(signal),
  });

  // Erorile nu blochează ecranul: listările de dedesubt sunt utile și fără
  // secțiunea asta, deci pe eroare/încărcare pur și simplu nu ocupăm loc.
  if (!owned.data) return null;

  return (
    <section className="mb-6">
      <div className="mb-2.5 flex flex-wrap items-start justify-between gap-3">
        <div className="min-w-0">
          <h2 className="font-semibold">{t('shelfOwnedSectionTitle')}</h2>
          <p className="text-sm text-muted-foreground">
            {t('shelfOwnedSectionSubtitle', { count: owned.data.length })}
          </p>
        </div>
        <Link
          to="/library/add"
          className="flex shrink-0 items-center gap-1.5 rounded-[12px] px-3 py-2 text-sm font-semibold text-accent hover:bg-muted"
        >
          <Plus size={18} />
          {t('shelfOwnedAddCta')}
        </Link>
      </div>

      {owned.data.length === 0 ? (
        <p className="rounded-[16px] border border-border bg-card p-4 text-sm text-muted-foreground">
          {t('shelfOwnedEmpty')}
        </p>
      ) : (
        <ul className="flex flex-col gap-2">
          {owned.data.map((item) => (
            <OwnedBookRow key={item.book.id} owned={item} />
          ))}
        </ul>
      )}
    </section>
  );
}

function OwnedBookRow({ owned }: { owned: OwnedBook }) {
  const { t } = useTranslation();
  const navigate = useNavigate();
  const queryClient = useQueryClient();

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

  const remove = useMutation({
    mutationFn: () => shelfRepository.remove(owned.book.id),
    onSuccess: () => {
      void queryClient.invalidateQueries({ queryKey: shelfKeys.owned() });
      void queryClient.invalidateQueries({ queryKey: shelfKeys.bookshelf() });
    },
  });

  /**
   * Listarea dintr-un singur click. Cartea primită printr-un schimb are deja un
   * exemplar al userului, doar nescos în piață - pe aceea o re-listăm, altfel
   * am crea un al doilea rând pentru aceeași carte.
   */
  function listNow() {
    // `from=shelf`: cartea e deja în raft, deci formularul nu mai oferă
    // „Adaugă în raft" - singura destinație cu sens e listarea.
    const params = new URLSearchParams({
      mode: 'listing',
      from: 'shelf',
      bookId: owned.book.id,
      title: owned.book.title,
    });
    if (owned.book.author) params.set('author', owned.book.author);
    if (owned.book.isbn) params.set('isbn', owned.book.isbn);
    if (owned.book.coverUrl) params.set('cover', owned.book.coverUrl);
    if (owned.relistSourceId) params.set('relistFrom', owned.relistSourceId);
    void navigate(`/library/add?${params}`);
  }

  const fraction = ownedProgress(owned);
  const finished = ownedIsFinished(owned);

  return (
    <li className="rounded-[16px] border border-border bg-card p-3">
      <div className="flex items-start gap-3">
        <div className="h-[62px] w-11 shrink-0 overflow-hidden rounded-lg bg-muted">
          <BookCover url={owned.book.coverUrl} title={owned.book.title} />
        </div>

        <button onClick={() => setEditing(true)} className="min-w-0 flex-1 text-left">
          <span className="flex items-center gap-1.5">
            <span className="min-w-0 truncate font-semibold">{owned.book.title}</span>
            {owned.listed && (
              <span className="shrink-0 rounded-full bg-accent/15 px-2 py-0.5 text-[11px] font-semibold text-accent">
                {t('shelfOwnedListedBadge')}
              </span>
            )}
          </span>
          {owned.book.author && (
            <span className="block truncate text-sm text-muted-foreground">
              {owned.book.author}
            </span>
          )}

          {fraction !== null && (
            <span className="mt-2 block h-[5px] overflow-hidden rounded bg-muted">
              <span
                className="block h-full rounded bg-accent"
                style={{ width: `${Math.round(fraction * 100)}%` }}
              />
            </span>
          )}
          {/* Fără total de pagini, „Pagina 0" nu spune nimic: cartea terminată
              scrie „Terminată", iar cea neîncepută nu scrie nimic. */}
          {owned.totalPages ? (
            <span className="mt-1 block text-sm text-muted-foreground">
              {`${t('bookshelfProgressLabel', { current: owned.currentPage, total: owned.totalPages })} · ${t('shelfProgressPercentLabel', { percent: Math.round((fraction ?? 0) * 100) })}`}
            </span>
          ) : finished ? (
            <span className="mt-1 block text-sm font-medium text-accent">
              {t('activityBadgeFinished')}
            </span>
          ) : owned.currentPage > 0 ? (
            <span className="mt-1 block text-sm text-muted-foreground">
              {t('bookshelfProgressLabelNoTotal', { current: owned.currentPage })}
            </span>
          ) : null}
        </button>

        {/* Listarea e acțiunea cea mai cerută de aici, deci stă la vedere, la un
            singur click - nu ascunsă în meniu. Cartea terminată e momentul în
            care propunerea e la locul ei, așa că butonul se aprinde în culoarea
            aplicației, în loc de un rând separat sub card. */}
        {!owned.listed && (
          <button
            onClick={listNow}
            title={t(finished ? 'shelfFinishedCta' : 'shelfListItNow')}
            aria-label={t('shelfListItNow')}
            className={cn(
              'shrink-0 rounded-full p-2 transition',
              finished
                ? 'bg-accent/15 text-accent hover:bg-accent/25'
                : 'text-muted-foreground hover:bg-muted hover:text-foreground',
            )}
          >
            <Store size={20} />
          </button>
        )}

        <div ref={menu} className="relative shrink-0">
          <button
            onClick={() => setMenuOpen((open) => !open)}
            aria-label={t('commonShowMore')}
            className="rounded-full p-2 text-muted-foreground hover:bg-muted hover:text-foreground"
          >
            <MoreVertical size={20} />
          </button>
          {menuOpen && (
            <div className="absolute right-0 top-full z-40 min-w-[200px] overflow-hidden rounded-[12px] border border-border bg-card py-1 shadow-xl">
              <MenuItem onClick={() => setEditing(true)}>{t('shelfUpdateProgress')}</MenuItem>
              <MenuItem onClick={() => void navigate(`/work/${owned.book.id}`)}>
                {t('workTitle')}
              </MenuItem>
              {/* Deja listată: nu-i mai propunem s-o listeze încă o dată. */}
              {!owned.listed && <MenuItem onClick={listNow}>{t('shelfListItNow')}</MenuItem>}
              <MenuItem
                onClick={() => {
                  setMenuOpen(false);
                  remove.mutate();
                }}
              >
                {t('shelfRemoveFromShelf')}
              </MenuItem>
            </div>
          )}
        </div>
      </div>

      {editing && <ReadingProgressSheet owned={owned} onClose={() => setEditing(false)} />}
    </li>
  );
}

function MenuItem({ onClick, children }: { onClick: () => void; children: React.ReactNode }) {
  return (
    <button onClick={onClick} className="block w-full px-4 py-2.5 text-left text-sm hover:bg-muted">
      {children}
    </button>
  );
}

/**
 * Foaia de progres la citit. Port al `reading_progress_sheet.dart`: totalul de
 * pagini, valoarea în pagini SAU în procente, și un buton separat de „am
 * terminat-o".
 */
function ReadingProgressSheet({ owned, onClose }: { owned: OwnedBook; onClose: () => void }) {
  const { t } = useTranslation();
  const toast = useToast();
  const queryClient = useQueryClient();

  const [total, setTotal] = useState(owned.totalPages?.toString() ?? '');
  const [unit, setUnit] = useState<'pages' | 'percent'>('pages');
  const [value, setValue] = useState(owned.currentPage ? owned.currentPage.toString() : '');
  const [error, setError] = useState<string | null>(null);

  const totalPages = Number(total.trim()) || null;

  const save = useMutation({
    /*
      `page: null` = „am terminat-o" fără să știm câte pagini are: nu
      inventăm un progres (înainte, userul trebuia să tasteze un total ca să
      poată marca, și ajungea să scrie 0), doar schimbăm statusul.
    */
    mutationFn: async ({ page, finished }: { page: number | null; finished: boolean }) => {
      if (page !== null) {
        await shelfRepository.saveProgress(owned.book.id, {
          currentPage: page,
          ...(totalPages ? { totalPages } : {}),
        });
      }
      // Statusul de raft urmează progresul: cine ajunge la ultima pagină e
      // „Finished", cine e la mijloc e „Reading". Fără asta, cartea rămânea
      // „Reading" la infinit și butonul de listare nu apărea niciodată.
      const done = finished || (!!totalPages && page !== null && page >= totalPages);
      await shelfRepository.setStatus(owned.book.id, {
        status: done ? 'FINISHED' : 'READING',
        owned: true,
      });
    },
    onSuccess: () => {
      void queryClient.invalidateQueries({ queryKey: shelfKeys.owned() });
      void queryClient.invalidateQueries({ queryKey: shelfKeys.bookshelf() });
      void queryClient.invalidateQueries({ queryKey: booksKeys.myLibrary() });
      onClose();
    },
    onError: () => toast.show(t('bookshelfProgressError'), 'danger'),
  });

  function submit(markFinished = false) {
    if (markFinished) {
      // Cu total cunoscut, progresul sare la ultima pagină; fără el, doar
      // statusul - numărul de pagini nu e obligatoriu.
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
        <p className="font-semibold">{owned.book.title}</p>
        {owned.book.author && <p className="text-sm text-muted-foreground">{owned.book.author}</p>}

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
