import { useMemo, useState } from 'react';
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { Link } from 'react-router-dom';
import { useTranslation } from 'react-i18next';
import { ScreenHeader, HeaderAction } from '@/components/layout/ScreenHeader';
import { Trash2, Upload } from 'lucide-react';
import { shelfKeys, shelfRepository, type ShelfEntry, type ShelfStatus } from './shelfRepository';
import { BookCover } from '@/components/ui/BookCover';
import { ErrorNotice, Spinner } from '@/components/ui';
import { FolderTabs } from '@/components/ui/FolderTabs';

type Tab = 'reading' | 'wantToRead' | 'finished';

/** Statusul din spatele fiecărei file - `/bookshelf/me` nu-l pune pe carte. */
const TAB_STATUS: Record<Tab, ShelfStatus> = {
  reading: 'READING',
  wantToRead: 'WANT_TO_READ',
  finished: 'FINISHED',
};

const TAB_KEYS: Record<Tab, string> = {
  reading: 'bookshelfTabReading',
  wantToRead: 'bookshelfTabWantToRead',
  finished: 'bookshelfTabFinished',
};

/**
 * Raftul personal de lectură. E ALTCEVA decât „Raftul meu" (`/library`):
 * acolo sunt exemplarele pe care le dai la schimb sau le vinzi, aici e
 * statusul tău de citit, indiferent dacă deții fizic cartea. O carte poate fi
 * în ambele locuri simultan.
 */
export function BookshelfScreen() {
  const { t } = useTranslation();
  const queryClient = useQueryClient();
  const [tab, setTab] = useState<Tab>('reading');

  const shelf = useQuery({
    queryKey: shelfKeys.bookshelf(),
    queryFn: ({ signal }) => shelfRepository.mine(signal),
  });

  /*
    Progresul la citit stă în altă listă decât raftul. `/bookshelf/me` spune
    DOAR ce carte e pe ce raft; paginile citite și totalul ediției vin din
    `/bookshelf/me/owned`. Le lipim aici, după id.

    Eșecul lui nu strică ecranul: fără progres rândurile se desenează oricum,
    doar fără bară - mai bine un raft fără bare decât un raft care nu se vede.
  */
  const owned = useQuery({
    queryKey: shelfKeys.owned(),
    queryFn: ({ signal }) => shelfRepository.owned(signal),
  });

  const progressByBook = useMemo(
    () => new Map((owned.data ?? []).map((item) => [item.book.id, item])),
    [owned.data],
  );

  const remove = useMutation({
    mutationFn: (bookId: string) => shelfRepository.remove(bookId),
    onSuccess: () => queryClient.invalidateQueries({ queryKey: shelfKeys.bookshelf() }),
  });

  const move = useMutation({
    mutationFn: ({ bookId, status }: { bookId: string; status: ShelfStatus }) =>
      shelfRepository.setStatus(bookId, { status }),
    onSuccess: () => queryClient.invalidateQueries({ queryKey: shelfKeys.bookshelf() }),
  });

  const header = (
    <ScreenHeader
      title={t('bookshelfTitle')}
      back
      actions={
        <HeaderAction to="/import" label={t('bookshelfImportTooltip')}>
          <Upload size={22} />
        </HeaderAction>
      }
    />
  );

  if (shelf.isPending) {
    return (
      <div className="flex min-h-dvh items-center justify-center text-accent">
        {header}
        <Spinner size={28} />
      </div>
    );
  }

  if (shelf.isError) {
    return (
      <div className="mx-auto max-w-2xl p-6">
        {header}
        <ErrorNotice message={t('bookshelfLoadError')} onRetry={() => void shelf.refetch()} />
      </div>
    );
  }

  const entries: ShelfEntry[] = (shelf.data[tab] ?? []).map((book) => {
    const progress = progressByBook.get(book.id);
    return {
      book,
      status: TAB_STATUS[tab],
      currentPage: progress?.currentPage ?? 0,
      // Paginile ediției proprii bat numărul din catalog, ca pe backend.
      totalPages: progress?.totalPages ?? book.pageCount ?? null,
      listed: progress?.listed ?? false,
    };
  });

  return (
    <div className="mx-auto w-full max-w-[760px] px-5 pb-16 pt-2 min-[900px]:px-8">
      {header}
      <FolderTabs
        className="mb-6"
        label={t('bookshelfTitle')}
        value={tab}
        onChange={setTab}
        tabs={(Object.keys(TAB_KEYS) as Tab[]).map((value) => ({
          value,
          label: t(TAB_KEYS[value]),
          badge: shelf.data[value]?.length ?? 0,
        }))}
      >
        {entries.length === 0 ? (
          <p className="py-16 text-center text-muted-foreground">{t('bookshelfEmpty')}</p>
        ) : (
          /* Fără ramă proprie pe rând: interiorul dosarului e deja o suprafață
             delimitată - vezi nota din lista de conversații. */
          <ul className="flex flex-col divide-y divide-border">
            {entries.map((entry) => (
              <ShelfRow
                key={entry.book.id}
                entry={entry}
                onRemove={() => remove.mutate(entry.book.id)}
                onMove={(status) => move.mutate({ bookId: entry.book.id, status })}
              />
            ))}
          </ul>
        )}
      </FolderTabs>
    </div>
  );
}

function ShelfRow({
  entry,
  onRemove,
  onMove,
}: {
  entry: ShelfEntry;
  onRemove: () => void;
  onMove: (status: ShelfStatus) => void;
}) {
  const { t } = useTranslation();

  return (
    <li className="flex items-center gap-3 rounded-[12px] px-2 py-2.5">
      <div className="h-[72px] w-[52px] shrink-0 overflow-hidden rounded-lg bg-muted">
        <BookCover url={entry.book.coverUrl} title={entry.book.title} />
      </div>

      <div className="min-w-0 flex-1">
        <Link to={`/work/${entry.book.id}`} className="truncate font-semibold hover:underline">
          {entry.book.title}
        </Link>
        {entry.book.author && (
          <p className="truncate text-sm text-muted-foreground">{entry.book.author}</p>
        )}

        {entry.status === 'READING' && (
          <>
            <p className="mt-1 text-xs text-muted-foreground">
              {entry.totalPages
                ? t('bookshelfProgressLabel', {
                    current: entry.currentPage,
                    total: entry.totalPages,
                  })
                : t('bookshelfProgressLabelNoTotal', { current: entry.currentPage })}
            </p>
            {/* Bara apare doar când există un total: fără el, procentul ar fi
                împărțire la zero și bara ar fi mereu goală. */}
            {entry.totalPages ? (
              <div className="mt-1 h-1 w-full overflow-hidden rounded-full bg-muted">
                <div
                  className="h-full bg-accent"
                  style={{
                    width: `${Math.min(100, (entry.currentPage / entry.totalPages) * 100)}%`,
                  }}
                />
              </div>
            ) : null}
          </>
        )}
      </div>

      <select
        value={entry.status}
        onChange={(event) => onMove(event.target.value as ShelfStatus)}
        aria-label={t('bookshelfTitle')}
        className="shrink-0 rounded-[12px] border border-border bg-transparent px-2 py-1.5 text-sm focus:outline-none"
      >
        <option value="READING">{t('bookshelfTabReading')}</option>
        <option value="WANT_TO_READ">{t('bookshelfTabWantToRead')}</option>
        <option value="FINISHED">{t('bookshelfTabFinished')}</option>
      </select>

      <button
        onClick={onRemove}
        aria-label={t('bookDetailShelfRemove')}
        title={t('bookDetailShelfRemove')}
        className="shrink-0 rounded-[12px] p-2.5 text-muted-foreground hover:bg-muted hover:text-danger-text"
      >
        <Trash2 size={18} />
      </button>
    </li>
  );
}
