import { useEffect, useMemo, useRef, useState } from 'react';
import { useQuery } from '@tanstack/react-query';
import { Link } from 'react-router-dom';
import { useTranslation } from 'react-i18next';
import { Eye, LayoutGrid, List, MoreVertical, Plus } from 'lucide-react';
import { booksKeys, booksRepository } from './booksRepository';
import { IMPORT_CSV_COLUMNS } from './importTemplate';
import { HeaderAction, ScreenHeader } from '@/components/layout/ScreenHeader';
import { FolderTabs } from '@/components/ui/FolderTabs';
import { downloadTextFile } from '@/lib/utils/download';
import { useAuth } from '@/features/auth/AuthProvider';
import { OwnedBooksSection } from '@/features/shelf/OwnedBooksSection';
import { BookCard } from './BookCard';
import { BookGrid } from './BookGrid';
import { BookCover } from '@/components/ui/BookCover';
import { ErrorNotice, Spinner } from '@/components/ui';
import { toNumber, type UserBook } from '@/types/models';

type Filter = 'all' | 'available' | 'unavailable';
type ViewMode = 'grid' | 'list';

const VIEW_STORAGE_KEY = 'shelfshare.library.view';

/**
 * Raftul meu - anunțurile proprii. Port al părții de listare din
 * my_library_screen.dart; editarea, selecția multiplă, importul/exportul CSV și
 * coșul de gunoi vin în loturile lor (fiecare are ecranul sau dialogul propriu).
 *
 * Endpointul întoarce TOATE cărțile deodată, fără paginare - la fel ca în
 * Flutter. Filtrarea și numărătoarea se fac deci local, dintr-un singur răspuns,
 * nu prin câte o cerere per filtru.
 */
export function MyLibraryScreen() {
  const { t } = useTranslation();
  const { user } = useAuth();
  const [filter, setFilter] = useState<Filter>('all');
  const [view, setView] = useState<ViewMode>(readStoredView);
  const [menuOpen, setMenuOpen] = useState(false);

  const library = useQuery({
    queryKey: booksKeys.myLibrary(),
    queryFn: ({ signal }) => booksRepository.getMyLibrary(signal),
  });

  const books = useMemo(() => library.data ?? [], [library.data]);

  /**
   * „Disponibilă" = listată în vreun fel (schimb, vânzare, licitație). O carte
   * poate fi simultan la schimb ȘI de vânzare, deci nu e un singur câmp de
   * verificat - vezi searchLibrary din books.service.ts, unde un anunț dispare
   * din public doar dacă TOATE tipurile lui sunt ascunse.
   */
  const counts = useMemo(() => {
    const available = books.filter(isAvailable).length;
    return { all: books.length, available, unavailable: books.length - available };
  }, [books]);

  const visible = useMemo(() => {
    if (filter === 'available') return books.filter(isAvailable);
    if (filter === 'unavailable') return books.filter((book) => !isAvailable(book));
    return books;
  }, [books, filter]);

  function changeView(next: ViewMode) {
    setView(next);
    try {
      window.localStorage.setItem(VIEW_STORAGE_KEY, next);
    } catch {
      /* storage blocat - preferința ține doar cât sesiunea */
    }
  }

  const header = (
    <ScreenHeader
      title={t('libraryTitle')}
      actions={
        <>
          <HeaderAction
            label={view === 'grid' ? t('libraryViewAsList') : t('libraryViewAsGrid')}
            onClick={() => changeView(view === 'grid' ? 'list' : 'grid')}
          >
            {view === 'grid' ? <List size={22} /> : <LayoutGrid size={22} />}
          </HeaderAction>

          <OverflowMenu
            open={menuOpen}
            onOpenChange={setMenuOpen}
            items={[
              { label: t('libraryExportCsv'), onSelect: () => exportCsv(books) },
              { label: t('libraryImportCsv'), to: '/import' },
              // Adaugarea in masa e o unealta pentru integrarile cu
              // anticariatele, nu o functie de user obisnuit - o vede doar
              // super-adminul (endpointul o refuza oricum celorlalti).
              ...(user?.isSuperAdmin
                ? [{ label: t('libraryBulkAdd'), to: '/library/bulk-add' }]
                : []),
              { label: t('libraryTrash'), to: '/library/trash' },
            ]}
          />
        </>
      }
    />
  );

  if (library.isPending) {
    return (
      <>
        {header}
        <div className="flex min-h-[60vh] items-center justify-center text-accent">
          <Spinner size={28} />
        </div>
      </>
    );
  }

  if (library.isError) {
    return (
      <>
        {header}
        <div className="mx-auto max-w-2xl p-6">
          <ErrorNotice message={t('libraryLoadError')} onRetry={() => void library.refetch()} />
        </div>
      </>
    );
  }

  return (
    <div className="mx-auto w-full max-w-[1200px] px-5 pb-16 pt-4 min-[900px]:px-8">
      {header}

      {/* Cărțile DEȚINUTE dar nelistate stau deasupra anunțurilor: sunt
          majoritatea unui raft real - cineva are acasă zeci de cărți și dă mai
          departe câteva. */}
      <OwnedBooksSection />

      {/* Aceleași file de dosar ca la Chat, Notificări și Raftul de lectură -
          categoriile arată la fel peste tot în aplicație. Contorul rămâne în
          etichetă, fiindcă traducerile îl au deja înăuntru („Toate {count}"). */}
      <FolderTabs
        className="mb-6"
        label={t('libraryTitle')}
        value={filter}
        onChange={setFilter}
        tabs={[
          { value: 'all' as const, label: t('libraryFilterAll', { count: counts.all }) },
          {
            value: 'available' as const,
            label: t('libraryFilterAvailable', { count: counts.available }),
          },
          {
            value: 'unavailable' as const,
            label: t('libraryFilterUnavailable', { count: counts.unavailable }),
          },
        ]}
      >
        {visible.length === 0 ? (
          <p className="py-16 text-center text-muted-foreground">{t('libraryEmpty')}</p>
        ) : view === 'grid' ? (
          <BookGrid>
            {visible.map((item, index) => (
              <BookCard key={item.id} item={item} eager={index < 5} />
            ))}
          </BookGrid>
        ) : (
          <ul className="flex flex-col gap-3">
            {visible.map((item) => (
              <LibraryRow key={item.id} item={item} />
            ))}
          </ul>
        )}
      </FolderTabs>

      {/* Butonul plutitor de adaugare, ca `FloatingActionButton.extended` din
          Flutter: e actiunea principala a ecranului si trebuie sa ramana la
          indemana oricat ar fi lista de lunga. */}
      <Link
        to="/library/add"
        className="fixed bottom-6 right-6 z-20 flex items-center gap-2 rounded-full bg-primary px-5 py-3.5 text-sm font-bold text-primary-foreground shadow-lg hover:brightness-110"
      >
        <Plus size={18} />
        {t('shelfFabAddBook')}
      </Link>
    </div>
  );
}

/**
 * Meniul „⋮" din bara de sus. Un `<details>` n-ar fi mers: lista trebuie sa se
 * inchida si la click in afara ei, nu doar pe buton.
 */
function OverflowMenu({
  open,
  onOpenChange,
  items,
}: {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  items: Array<{ label: string; to?: string; onSelect?: () => void }>;
}) {
  const { t } = useTranslation();
  const box = useRef<HTMLDivElement>(null);

  useEffect(() => {
    if (!open) return;
    const onPointerDown = (event: MouseEvent) => {
      if (!box.current?.contains(event.target as Node)) onOpenChange(false);
    };
    const onKey = (event: KeyboardEvent) => {
      if (event.key === 'Escape') onOpenChange(false);
    };
    document.addEventListener('mousedown', onPointerDown);
    window.addEventListener('keydown', onKey);
    return () => {
      document.removeEventListener('mousedown', onPointerDown);
      window.removeEventListener('keydown', onKey);
    };
  }, [open, onOpenChange]);

  return (
    <div ref={box} className="relative shrink-0">
      <HeaderAction label={t('commonShowMore')} onClick={() => onOpenChange(!open)}>
        <MoreVertical size={22} />
      </HeaderAction>

      {open && (
        <div className="absolute right-0 top-full z-40 min-w-[200px] overflow-hidden rounded-[12px] border border-border bg-card py-1 shadow-xl">
          {items.map((item) =>
            item.to ? (
              <Link
                key={item.label}
                to={item.to}
                onClick={() => onOpenChange(false)}
                className="block px-4 py-2.5 text-left text-sm hover:bg-muted"
              >
                {item.label}
              </Link>
            ) : (
              <button
                key={item.label}
                onClick={() => {
                  onOpenChange(false);
                  item.onSelect?.();
                }}
                className="block w-full px-4 py-2.5 text-left text-sm hover:bg-muted"
              >
                {item.label}
              </button>
            ),
          )}
        </div>
      )}
    </div>
  );
}

/**
 * Exportul bibliotecii ca CSV, cu ACELEASI coloane pe care le citeste importul -
 * un fisier exportat de aici se poate incarca inapoi. Antetul ramane in engleza
 * dinadins: backendul compara numele coloanelor literal.
 *
 * Incepe cu BOM, ca Excel sa-l deschida ca UTF-8 si sa nu strice diacriticele.
 */
function exportCsv(books: UserBook[]): void {
  const rows = [
    IMPORT_CSV_COLUMNS.join(','),
    ...books.map((item) =>
      [
        csvEscape(item.book.title),
        csvEscape(item.book.author ?? ''),
        item.book.isbn ?? '',
        // Tot ce e in „Cartile mele" e deja un anunt; la reimport ramane anunt,
        // nu ajunge pe raftul de lectura.
        'swap',
        item.condition ?? '',
        csvEscape(item.language ?? ''),
        csvEscape(item.city ?? ''),
        toNumber(item.salePrice)?.toFixed(0) ?? '',
        csvEscape(item.description ?? ''),
      ].join(','),
    ),
  ];
  downloadTextFile({
    filename: 'biblioteca-shelfshare.csv',
    content: `\uFEFF${rows.join('\r\n')}\r\n`,
    mimeType: 'text/csv',
  });
}

function csvEscape(value: string): string {
  if (value.includes(',') || value.includes('"')) {
    return `"${value.replaceAll('"', '""')}"`;
  }
  return value;
}

function LibraryRow({ item }: { item: UserBook }) {
  const { t } = useTranslation();
  const price = toNumber(item.salePrice);
  const available = isAvailable(item);

  return (
    <li>
      <Link
        to={`/books/${item.id}`}
        className="flex items-center gap-4 rounded-[16px] border border-border bg-card p-3 hover:bg-muted"
      >
        <div className="h-[72px] w-[52px] shrink-0 overflow-hidden rounded-lg bg-muted">
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
          <div className="mt-1 flex flex-wrap items-center gap-2 text-xs">
            <span className={available ? 'text-success' : 'text-muted-foreground'}>
              {available ? t('libraryAvailable') : t('libraryUnavailable')}
            </span>
            {item.availableForSwap && <Badge>{t('shareListingModeSwap')}</Badge>}
            {item.isForSale && <Badge>{t('shareListingModeSale')}</Badge>}
            {item.isAuction && <Badge>{t('shareListingModeAuction')}</Badge>}
          </div>
        </div>

        <div className="shrink-0 text-right">
          {price !== null && (
            <p className="font-bold text-accent">{t('priceLei', { amount: price })}</p>
          )}
          <p className="flex items-center justify-end gap-1 text-xs text-muted-foreground">
            <Eye size={12} />
            {item.viewCount}
          </p>
        </div>
      </Link>
    </li>
  );
}

function Badge({ children }: { children: React.ReactNode }) {
  return (
    <span className="rounded-full border border-border px-2 py-0.5 text-muted-foreground">
      {children}
    </span>
  );
}


function isAvailable(book: UserBook): boolean {
  return book.availableForSwap || book.isForSale || book.isAuction;
}

function readStoredView(): ViewMode {
  try {
    return window.localStorage.getItem(VIEW_STORAGE_KEY) === 'list' ? 'list' : 'grid';
  } catch {
    return 'grid';
  }
}
