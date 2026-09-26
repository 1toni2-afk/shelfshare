import { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { Link } from 'react-router-dom';
import { useTranslation } from 'react-i18next';
import { HeaderAction, ScreenHeader } from '@/components/layout/ScreenHeader';
import { ChatSafetyPane } from './ChatSafetyPane';
import {
  Archive,
  ArchiveRestore,
  Check,
  ListChecks,
  MessageSquarePlus,
  Search,
  Trash2,
  X,
} from 'lucide-react';
import { chatKeys, chatRepository, type Conversation } from './chatRepository';
import { chatSocket } from '@/lib/socket/chatSocket';
import { Avatar } from '@/components/ui/Avatar';
import { FolderTabs } from '@/components/ui/FolderTabs';
import { ErrorNotice, Spinner } from '@/components/ui';
import { cn } from '@/lib/utils/cn';
import { formatRelativeTime } from '@/lib/utils/time';

type Filter = 'all' | 'unread' | 'archived';

export function ConversationsListScreen() {
  const { t } = useTranslation();
  const queryClient = useQueryClient();
  const [filter, setFilter] = useState<Filter>('all');
  const [search, setSearch] = useState('');

  /**
   * Selecția în masă. `null` = modul e oprit; un Set (fie el și gol) = pornit.
   * Două stări separate (un bool plus un Set) s-ar putea contrazice, iar „modul
   * e pornit dar nu e nimic bifat" e o stare validă - exact cea în care intri
   * apăsând butonul din antet.
   */
  const [selection, setSelection] = useState<ReadonlySet<string> | null>(null);
  const selectionOn = selection !== null;

  // Pe fila „Arhivate" acțiunea în masă e inversă, iar lista vine din alt loc:
  // serverul întoarce ori inboxul, ori arhiva, niciodată amândouă.
  const onArchivedTab = filter === 'archived';

  const inbox = useQuery({
    queryKey: chatKeys.conversations(false),
    queryFn: ({ signal }) => chatRepository.getConversations(false, signal),
  });

  // Arhiva se cere doar când fila e deschisă - e o listă pe care majoritatea
  // oamenilor n-o deschid niciodată.
  const archive = useQuery({
    queryKey: chatKeys.conversations(true),
    queryFn: ({ signal }) => chatRepository.getConversations(true, signal),
    enabled: onArchivedTab,
  });

  const conversations = onArchivedTab ? archive : inbox;

  const exitSelection = useCallback(() => setSelection(null), []);

  /*
    Escape iese din selecție. Pe telefon nu se vede o tastatură, dar pe desktop
    e reflexul normal, iar aici costă trei linii - spre deosebire de butonul de
    închidere, care pe telefon nu putea sta în colțul din stânga sus: acolo
    plutește butonul de meniu al shell-ului și l-ar fi acoperit complet. De
    asta ieșirea stă în DREAPTA, lângă celelalte acțiuni.
  */
  useEffect(() => {
    if (!selectionOn) return;
    const onKey = (event: KeyboardEvent) => {
      if (event.key === 'Escape') exitSelection();
    };
    window.addEventListener('keydown', onKey);
    return () => window.removeEventListener('keydown', onKey);
  }, [selectionOn, exitSelection]);

  function toggleSelected(id: string) {
    setSelection((current) => {
      const next = new Set(current ?? []);
      if (!next.delete(id)) next.add(id);
      return next;
    });
  }

  function startSelectionWith(id: string) {
    setSelection(new Set([id]));
  }

  // Actualizări live. Lista s-a încărcat deja pe HTTP - socketul doar o ține
  // proaspătă, deci nu îl așteptăm și nu tratăm eșecul lui ca eroare de ecran.
  useEffect(() => {
    const off = chatSocket.on('message_notification', () => {
      void queryClient.invalidateQueries({ queryKey: chatKeys.conversations() });
      void queryClient.invalidateQueries({ queryKey: chatKeys.unreadCount() });
    });
    return off;
  }, [queryClient]);

  const visible = useMemo(() => {
    const all = conversations.data ?? [];
    const term = search.trim().toLowerCase();

    return all
      .filter((conversation) => {
        // Separarea arhivă/inbox o face deja serverul, prin lista cerută.
        // Aici rămâne doar „necitite", care e o felie din inbox.
        if (filter === 'unread') return conversation.unreadCount > 0;
        return true;
      })
      .filter((conversation) => {
        if (!term) return true;
        const name = conversation.otherUser.name ?? conversation.otherUser.username ?? '';
        return (
          name.toLowerCase().includes(term) ||
          (conversation.lastMessage?.content ?? '').toLowerCase().includes(term)
        );
      });
  }, [conversations.data, filter, search]);

  // Contorul de pe fila „Necitite" NU ține cont de căutare: e o proprietate a
  // inboxului, nu a filtrării curente, altfel ar scădea în timp ce tastezi.
  // Arhivatele nu intră, ca să nu promită mesaje pe care fila nu le arată.
  // Din INBOX, nu din lista afișată: pe fila „Arhivate" lista curentă e arhiva,
  // iar contorul ar arăta necititele de acolo.
  const unreadConversations = useMemo(
    () => (inbox.data ?? []).filter((conversation) => conversation.unreadCount > 0).length,
    [inbox.data],
  );

  const selectedCount = selection?.size ?? 0;

  const bulk = useMutation({
    // Secvențial, nu `Promise.all`: sunt câteva conversații, iar o rafală de
    // ștergeri paralele n-ar aduce nimic în afară de un vârf inutil pe server.
    mutationFn: async (action: 'archive' | 'delete') => {
      for (const id of selection ?? []) {
        if (action === 'delete') await chatRepository.remove(id);
        else if (onArchivedTab) await chatRepository.unarchive(id);
        else await chatRepository.archive(id);
      }
    },
    onSettled: () => {
      exitSelection();
      void queryClient.invalidateQueries({ queryKey: chatKeys.conversations() });
      void queryClient.invalidateQueries({ queryKey: chatKeys.unreadCount() });
    },
  });

  const header = (
    <ScreenHeader
      title={selectionOn ? t('chatSelectedCount', { count: selectedCount }) : t('navChat')}
      actions={
        selectionOn ? (
          <>
            <HeaderAction
              onClick={() => bulk.mutate('archive')}
              disabled={selectedCount === 0 || bulk.isPending}
              label={t(onArchivedTab ? 'chatUnarchive' : 'chatArchive')}
            >
              {onArchivedTab ? <ArchiveRestore size={22} /> : <Archive size={22} />}
            </HeaderAction>
            <HeaderAction
              onClick={() => {
                if (window.confirm(`${t('chatDeleteTitle')}

${t('chatDeleteConfirm')}`)) {
                  bulk.mutate('delete');
                }
              }}
              disabled={selectedCount === 0 || bulk.isPending}
              label={t('chatDeleteTitle')}
            >
              <Trash2 size={22} className="text-danger-text" />
            </HeaderAction>
            {/*
              Ieșirea din selecție. Stă în DREAPTA, nu ca „X" în colțul din
              stânga sus: acolo plutește butonul de meniu al shell-ului pe
              telefon și l-ar acoperi complet - motivul pentru care din modul de
              selecție nu se putea ieși decât repornind aplicația.
            */}
            <HeaderAction onClick={exitSelection} label={t('commonCancel')}>
              <X size={22} />
            </HeaderAction>
          </>
        ) : (
          <>
            {/* Selecția are un BUTON, nu doar apăsare lungă: un gest nevăzut
                nu e o funcție, e un secret. Apăsarea lungă rămâne, ca scurtătură. */}
            <HeaderAction onClick={() => setSelection(new Set())} label={t('commonEdit')}>
              <ListChecks size={22} />
            </HeaderAction>
            {/* „Conversație nouă" duce la căutarea de oameni: o conversație se
                deschide de pe profilul cuiva, nu dintr-un formular gol. */}
            <HeaderAction to="/search" label={t('chatNewConversationTooltip')}>
              <MessageSquarePlus size={22} />
            </HeaderAction>
          </>
        )
      }
    />
  );

  if (conversations.isPending) {
    return (
      <div className="flex min-h-dvh items-center justify-center text-accent">
        {header}
        <Spinner size={28} />
      </div>
    );
  }

  if (conversations.isError) {
    return (
      <div className="mx-auto max-w-2xl p-6">
        {header}
        <ErrorNotice message={t('chatLoadError')} onRetry={() => void conversations.refetch()} />
      </div>
    );
  }

  const emptyMessage =
    search.trim().length > 0
      ? t('chatNoResults')
      : filter === 'unread'
        ? t('chatEmptyUnread')
        : filter === 'archived'
          ? t('chatEmptyArchived')
          : t('chatEmptyConversations');

  /*
    Pe desktop chatul e un layout cu două panouri, ca în Flutter: lista la
    360px în stânga, iar în dreapta panoul de siguranță cât timp nu e deschisă
    nicio conversație. Sub prag rămâne o singură coloană.
  */
  return (
    <div className="flex min-h-[calc(100dvh-4rem)] items-stretch">
      {header}
      <div className="mx-auto w-full max-w-[760px] px-5 pb-16 pt-2 min-[1100px]:mx-0 min-[1100px]:w-[360px] min-[1100px]:shrink-0 min-[1100px]:max-w-none min-[1100px]:border-r min-[1100px]:border-border min-[1100px]:px-4">
      <div className="mb-4 flex items-center gap-2 rounded-[16px] bg-muted px-4">
        <Search size={18} className="shrink-0 text-muted-foreground" />
        <input
          value={search}
          onChange={(event) => setSearch(event.target.value)}
          placeholder={t('chatSearchHint')}
          aria-label={t('chatSearchHint')}
          className="w-full bg-transparent py-3.5 text-foreground placeholder:text-muted-foreground focus:outline-none"
        />
      </div>

      <FolderTabs
        className="mb-6"
        label={t('chatFiltersLabel')}
        value={filter}
        onChange={setFilter}
        tabs={[
          { value: 'all', label: t('chatFilterAll') },
          { value: 'unread', label: t('chatFilterUnread'), badge: unreadConversations },
          { value: 'archived', label: t('chatFilterArchived') },
        ]}
      >
        {/*
          Rândurile NU mai sunt carduri cu margine proprie: interiorul
          dosarului e deja o suprafață delimitată, iar un card în card ar
          desena a doua ramă în jurul aceluiași lucru. Rămâne o linie subțire
          de despărțire, ca în mapa de hârtie.
        */}
        {visible.length === 0 ? (
          <p className="py-16 text-center text-muted-foreground">{emptyMessage}</p>
        ) : (
          <ul className="flex flex-col divide-y divide-border">
            {visible.map((conversation) => (
              <ConversationRow
                key={conversation.id}
                conversation={conversation}
                selectionOn={selectionOn}
                selected={selection?.has(conversation.id) ?? false}
                onToggle={() => toggleSelected(conversation.id)}
                onStartSelection={() => startSelectionWith(conversation.id)}
              />
            ))}
          </ul>
        )}
      </FolderTabs>
      </div>

      {/* Panoul din dreapta apare doar când e loc pentru el; conversația
          deschisă are ruta ei (`/chat/:id`), deci aici rămâne panoul de
          siguranță. */}
      <div className="hidden min-w-0 flex-1 overflow-y-auto min-[1100px]:block">
        <ChatSafetyPane />
      </div>
    </div>
  );
}

/** Cât ține apăsarea până intră în selecție. */
const LONG_PRESS_MS = 450;

function ConversationRow({
  conversation,
  selectionOn,
  selected,
  onToggle,
  onStartSelection,
}: {
  conversation: Conversation;
  selectionOn: boolean;
  selected: boolean;
  onToggle: () => void;
  onStartSelection: () => void;
}) {
  const { t, i18n } = useTranslation();
  const timer = useRef<number | null>(null);

  const name =
    conversation.otherUser.name ?? conversation.otherUser.username ?? t('commonUnknownUser');

  const preview = conversation.lastMessage?.content
    ? conversation.lastMessage.content
    : conversation.lastMessage?.photo
      ? t('chatPhotoPreview')
      : '';

  function cancelLongPress() {
    if (timer.current !== null) {
      window.clearTimeout(timer.current);
      timer.current = null;
    }
  }

  /*
    Apăsarea lungă pornește selecția. Odată pornită NU se mai armează: în
    selecție, o apăsare scurtă bifează deja rândul, iar un al doilea gest peste
    ea ar comuta de două ori.
  */
  function startLongPress() {
    if (selectionOn) return;
    cancelLongPress();
    timer.current = window.setTimeout(() => {
      timer.current = null;
      onStartSelection();
    }, LONG_PRESS_MS);
  }

  // Curățenie la demontare: un rând care dispare din listă (arhivat, șters,
  // filtrat) în timpul apăsării ar porni selecția după ce a plecat de pe ecran.
  useEffect(() => cancelLongPress, []);

  const body = (
    <>
      {/*
        Bifa ia locul avatarului, nu îl dublează: două cercuri de 44px unul
        lângă altul pe un ecran de telefon lasă numele fără loc.
      */}
      {selectionOn ? (
        <span
          aria-hidden
          className={cn(
            'flex size-11 shrink-0 items-center justify-center rounded-full border-2 transition',
            selected ? 'border-accent bg-accent text-accent-foreground' : 'border-border',
          )}
        >
          {selected && <Check size={22} strokeWidth={3} />}
        </span>
      ) : (
        <Avatar src={conversation.otherUser.profileImage} name={name} size={44} />
      )}

      <div className="min-w-0 flex-1">
        <div className="flex items-baseline justify-between gap-2">
          <p className="truncate font-semibold">{name}</p>
          <span className="shrink-0 text-xs text-muted-foreground">
            {formatRelativeTime(conversation.updatedAt, i18n.language)}
          </span>
        </div>
        <p
          className={cn(
            'truncate text-sm',
            conversation.unreadCount > 0 ? 'font-medium text-foreground' : 'text-muted-foreground',
          )}
        >
          {preview}
        </p>
      </div>

      {conversation.unreadCount > 0 && (
        <span className="shrink-0 rounded-full bg-accent px-2 py-0.5 text-[11px] font-bold text-accent-foreground">
          {conversation.unreadCount > 99 ? '99+' : conversation.unreadCount}
        </span>
      )}
    </>
  );

  const shared = cn(
    'flex w-full items-center gap-3 rounded-[12px] px-2 py-2.5 text-left transition',
    // `select-none`: fără el, apăsarea lungă selectează textul din rând și
    // scoate lupa de copiere peste interfață exact când intri în selecție.
    'select-none hover:bg-foreground/5',
    selected && 'bg-accent/15',
  );

  const pressHandlers = {
    onPointerDown: startLongPress,
    onPointerUp: cancelLongPress,
    onPointerLeave: cancelLongPress,
    onPointerCancel: cancelLongPress,
    // Meniul contextual e ce declanșează apăsarea lungă în multe browsere de
    // telefon; îl folosim ca a doua cale de intrare și îl oprim să apară.
    onContextMenu: (event: { preventDefault: () => void }) => {
      event.preventDefault();
      if (!selectionOn) onStartSelection();
    },
  };

  return (
    <li>
      {selectionOn ? (
        <button
          type="button"
          aria-pressed={selected}
          onClick={onToggle}
          {...pressHandlers}
          className={shared}
        >
          {body}
        </button>
      ) : (
        <Link to={`/chat/${conversation.id}`} {...pressHandlers} className={shared}>
          {body}
        </Link>
      )}
    </li>
  );
}
