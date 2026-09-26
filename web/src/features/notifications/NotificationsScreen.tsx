import { useEffect, useMemo, useState } from 'react';
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { useNavigate } from 'react-router-dom';
import { useTranslation } from 'react-i18next';
import { ScreenHeader } from '@/components/layout/ScreenHeader';
import {
  Bell,
  BookmarkIcon,
  BookOpen,
  CalendarDays,
  CheckCheck,
  CircleCheck,
  CircleX,
  FileSearch,
  Gavel,
  Handshake,
  Heart,
  Hourglass,
  Library,
  MapPin,
  MessageCircle,
  PhoneCall,
  Repeat,
  Sparkles,
  Tag,
  TrendingUp,
  UserPlus,
  Users,
  LifeBuoy,
} from 'lucide-react';
import {
  categoryOf,
  notificationsKeys,
  notificationsRepository,
  routeForNotification,
  type AppNotification,
} from './notificationsRepository';
import { chatSocket } from '@/lib/socket/chatSocket';
import { ErrorNotice, Spinner } from '@/components/ui';
import { FolderTabs } from '@/components/ui/FolderTabs';
import { formatRelativeTime } from '@/lib/utils/time';
import { cn } from '@/lib/utils/cn';

type Filter = 'all' | 'unread' | 'messages' | 'exchanges';

export function NotificationsScreen() {
  const { t, i18n } = useTranslation();
  const navigate = useNavigate();
  const queryClient = useQueryClient();
  const [filter, setFilter] = useState<Filter>('all');

  const notifications = useQuery({
    queryKey: notificationsKeys.list(),
    queryFn: ({ signal }) => notificationsRepository.list(signal),
  });

  useEffect(() => {
    const offNew = chatSocket.on('notification', () => {
      void queryClient.invalidateQueries({ queryKey: notificationsKeys.list() });
    });
    const offRead = chatSocket.on('notification_read', () => {
      void queryClient.invalidateQueries({ queryKey: notificationsKeys.list() });
    });
    return () => {
      offNew();
      offRead();
    };
  }, [queryClient]);

  const markRead = useMutation({
    mutationFn: (id: string) => notificationsRepository.markRead(id),
    // Optimist: la click navigăm imediat, deci userul nu mai e pe ecran ca să
    // vadă rezultatul cererii. Dacă am aștepta răspunsul, s-ar întoarce și ar
    // găsi notificarea tot nebifată pentru o clipă.
    onMutate: async (id) => {
      await queryClient.cancelQueries({ queryKey: notificationsKeys.list() });
      const previous = queryClient.getQueryData<AppNotification[]>(notificationsKeys.list());
      queryClient.setQueryData<AppNotification[]>(notificationsKeys.list(), (current) =>
        current?.map((item) => (item.id === id ? { ...item, isRead: true } : item)),
      );
      return { previous };
    },
    onError: (_error, _id, context) => {
      if (context?.previous) {
        queryClient.setQueryData(notificationsKeys.list(), context.previous);
      }
    },
  });

  const markAllRead = useMutation({
    mutationFn: () => notificationsRepository.markAllRead(),
    onSuccess: () => queryClient.invalidateQueries({ queryKey: notificationsKeys.list() }),
  });

  const all = useMemo(() => notifications.data ?? [], [notifications.data]);
  const unreadCount = all.filter((item) => !item.isRead).length;

  const visible = useMemo(() => {
    if (filter === 'unread') return all.filter((item) => !item.isRead);
    if (filter === 'messages') return all.filter((item) => categoryOf(item) === 'messages');
    if (filter === 'exchanges') return all.filter((item) => categoryOf(item) === 'exchanges');
    return all;
  }, [all, filter]);

  // Notificările identice consecutive se strâng într-un rând cu „×N": cinci
  // rânduri „X a listat o carte nouă" unul sub altul sunt zgomot, nu informație.
  const collapsed = useMemo(() => collapseRepeats(visible), [visible]);

  // Gruparea pe zile: azi / ieri / mai devreme. Cu zeci de notificări pe zi,
  // o listă plată nu lasă să se vadă ce e nou.
  const groups = useMemo(() => groupByRecency(collapsed), [collapsed]);

  function open(notification: AppNotification) {
    if (!notification.isRead) markRead.mutate(notification.id);
    const route = routeForNotification(notification);
    if (route) void navigate(route);
  }

  const header = <ScreenHeader title={t('notificationsTitle')} />;

  if (notifications.isPending) {
    return (
      <div className="flex min-h-dvh items-center justify-center text-accent">
        {header}
        <Spinner size={28} />
      </div>
    );
  }

  if (notifications.isError) {
    return (
      <div className="mx-auto max-w-2xl p-6">
        {header}
        <ErrorNotice
          message={t('notificationsLoadError')}
          onRetry={() => void notifications.refetch()}
        />
      </div>
    );
  }

  return (
    <div className="mx-auto w-full max-w-[760px] px-5 pb-16 pt-2 min-[900px]:px-8">
      {header}
      {unreadCount > 0 && (
        <div className="mb-2 flex flex-wrap items-center justify-between gap-3">
          <span className="rounded-full bg-accent/15 px-2.5 py-1 text-xs font-semibold text-accent">
            {t('notificationsUnreadCount', { count: unreadCount })}
          </span>
          <button
            onClick={() => markAllRead.mutate()}
            disabled={markAllRead.isPending}
            className="flex items-center gap-2 rounded-[12px] px-3 py-2 text-sm font-semibold text-accent hover:bg-muted disabled:opacity-60"
          >
            <CheckCheck size={16} />
            {t('notificationsMarkAllRead')}
          </button>
        </div>
      )}

      {/*
        Ordinea e cea din Flutter: toate, necitite, schimburi, mesaje. Categoriile
        NU se mai rup pe două rânduri când nu încap: banda se derulează pe
        orizontală, cu estompare la capătul în care mai e ceva de văzut.
      */}
      <FolderTabs
        className="mb-4"
        label={t('notificationsTitle')}
        value={filter}
        onChange={setFilter}
        tabs={(['all', 'unread', 'exchanges', 'messages'] as const).map((value) => ({
          value,
          label: t(FILTER_KEYS[value]),
          badge: value === 'unread' ? unreadCount : undefined,
        }))}
      >
      {visible.length === 0 ? (
        <p className="py-16 text-center text-muted-foreground">{t('notificationsEmpty')}</p>
      ) : (
        <div className="flex flex-col gap-6">
          {groups.map(({ labelKey, items }) => (
            <section key={labelKey}>
              <h2 className="mb-2 text-xs font-semibold uppercase tracking-wider text-muted-foreground">
                {t(labelKey)}
              </h2>
              <ul className="flex flex-col gap-2">
                {items.map(({ notification, count }) => {
                  const clickable = routeForNotification(notification) !== null;
                  const Icon = ICONS[notification.type] ?? Bell;
                  return (
                    <li key={notification.id}>
                      {/*
                        Un <button> doar când chiar duce undeva. O notificare
                        fără destinație randată ca link ducea userul nicăieri
                        la click, ceea ce arăta ca un bug.
                      */}
                      <div
                        role={clickable ? 'button' : undefined}
                        tabIndex={clickable ? 0 : undefined}
                        onClick={clickable ? () => open(notification) : undefined}
                        onKeyDown={
                          clickable
                            ? (event) => {
                                if (event.key === 'Enter' || event.key === ' ') {
                                  event.preventDefault();
                                  open(notification);
                                }
                              }
                            : undefined
                        }
                        className={cn(
                          'flex items-start gap-3 rounded-[12px] px-2.5 py-3 text-left',
                          !notification.isRead && 'bg-accent/[0.08]',
                          clickable && 'cursor-pointer hover:bg-muted',
                        )}
                      >
                        {notification.isRead ? (
                          <span className="w-[15px] shrink-0" />
                        ) : (
                          <span className="mt-1.5 size-[7px] shrink-0 rounded-full bg-accent" />
                        )}

                        <span className="flex size-[34px] shrink-0 items-center justify-center rounded-full bg-muted text-muted-foreground">
                          <Icon size={17} />
                        </span>

                        <p className="min-w-0 flex-1 text-sm">
                          {notification.message}
                          {count > 1 && (
                            <span className="text-muted-foreground">
                              {' '}
                              {t('notificationsRepeatedCount', { count })}
                            </span>
                          )}
                        </p>

                        <span className="shrink-0 text-xs text-muted-foreground">
                          {formatRelativeTime(notification.createdAt, i18n.language)}
                        </span>
                      </div>
                    </li>
                  );
                })}
              </ul>
            </section>
          ))}
        </div>
      )}
      </FolderTabs>
    </div>
  );
}

const FILTER_KEYS: Record<Filter, string> = {
  all: 'notificationsFilterAll',
  unread: 'notificationsFilterUnread',
  messages: 'notificationsFilterMessages',
  exchanges: 'notificationsFilterExchanges',
};

/**
 * Iconița fiecărui tip de notificare, aceeași ca `_iconFor` din
 * notifications_screen.dart. Tipurile necunoscute (backend mai nou decât
 * frontendul) cad pe clopoțel, nu pe nimic.
 */
const ICONS: Record<string, typeof Bell> = {
  WISHLIST_BOOK_AVAILABLE: Heart,
  NEW_MESSAGE: MessageCircle,
  EXCHANGE_REQUEST_RECEIVED: Repeat,
  EXCHANGE_REQUEST_ACCEPTED: Repeat,
  EXCHANGE_REQUEST_REJECTED: Repeat,
  EXCHANGE_MEETING_SCHEDULED: CalendarDays,
  EXCHANGE_MEETING_PROPOSED: CalendarDays,
  EXCHANGE_MEETING_ACCEPTED: CalendarDays,
  EXCHANGE_MEETING_DECLINED: CalendarDays,
  EXCHANGE_POSTPONED: CalendarDays,
  EXCHANGE_CONTACT_SHARED: PhoneCall,
  EXCHANGE_READY: Handshake,
  EXCHANGE_DONE_PENDING_CONFIRMATION: CircleCheck,
  EXCHANGE_COMPLETED: CircleCheck,
  EXCHANGE_DONE_DISPUTED: CircleX,
  EXCHANGE_CANCELLED: CircleX,
  EXCHANGE_BOOK_PENDING: Hourglass,
  EXCHANGE_REOPENED: Hourglass,
  PRICE_OFFER_RECEIVED: Tag,
  PRICE_OFFER_ACCEPTED: Tag,
  PRICE_OFFER_REJECTED: Tag,
  FOLLOWED_USER_NEW_BOOK: UserPlus,
  FOLLOWED_USER_FINISHED_BOOK: BookOpen,
  NEARBY_BOOK_LISTED: MapPin,
  INTEREST_BOOK_LISTED: Sparkles,
  SAVED_SEARCH_MATCH: BookmarkIcon,
  SERIES_VOLUME_AVAILABLE: Library,
  BOOK_REQUEST_FOUND: FileSearch,
  GROUP_POST: Users,
  ADMIN_MESSAGE: LifeBuoy,
  PRICE_CHANGED: TrendingUp,
  OUTBID: Gavel,
  AUCTION_WON: Gavel,
  AUCTION_ENDED: Gavel,
};

/** O notificare, plus de câte ori s-a repetat consecutiv. */
interface CollapsedNotification {
  notification: AppNotification;
  count: number;
}

/**
 * Strânge notificările CONSECUTIVE cu același tip și text, dacă sunt la mai
 * puțin de 12 ore una de alta. Aceeași regulă ca `_group` din Flutter: contează
 * vecinătatea în listă, nu o grupare globală - altfel două valuri separate de
 * zile ar ajunge în același rând.
 */
function collapseRepeats(notifications: AppNotification[]): CollapsedNotification[] {
  const TWELVE_HOURS = 12 * 60 * 60 * 1000;
  const out: CollapsedNotification[] = [];

  for (const notification of notifications) {
    const previous = out.at(-1);
    if (
      previous &&
      previous.notification.type === notification.type &&
      previous.notification.message === notification.message &&
      Math.abs(
        new Date(previous.notification.createdAt).getTime() -
          new Date(notification.createdAt).getTime(),
      ) < TWELVE_HOURS
    ) {
      previous.count += 1;
      // Necitit dacă MĂCAR una din cele strânse e necitită - altfel rândul ar
      // părea citit când de fapt ascunde ceva nou.
      if (!notification.isRead) previous.notification = { ...previous.notification, isRead: false };
      continue;
    }
    out.push({ notification, count: 1 });
  }

  return out;
}

function groupByRecency(notifications: CollapsedNotification[]) {
  const startOfToday = new Date();
  startOfToday.setHours(0, 0, 0, 0);
  const startOfYesterday = new Date(startOfToday);
  startOfYesterday.setDate(startOfYesterday.getDate() - 1);

  const buckets: Array<{ labelKey: string; items: CollapsedNotification[] }> = [
    { labelKey: 'notificationsToday', items: [] },
    { labelKey: 'notificationsYesterday', items: [] },
    { labelKey: 'notificationsEarlier', items: [] },
  ];

  for (const entry of notifications) {
    const created = new Date(entry.notification.createdAt);
    if (created >= startOfToday) buckets[0].items.push(entry);
    else if (created >= startOfYesterday) buckets[1].items.push(entry);
    else buckets[2].items.push(entry);
  }

  return buckets.filter((bucket) => bucket.items.length > 0);
}
