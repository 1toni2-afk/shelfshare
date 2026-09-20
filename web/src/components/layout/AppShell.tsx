import { createContext, useCallback, useEffect, useMemo, useState, use } from 'react';
import { NavLink, Outlet, useLocation } from 'react-router-dom';
import { useQuery } from '@tanstack/react-query';
import { useTranslation } from 'react-i18next';
import {
  Bell,
  BookMarked,
  BookOpen,
  Check,
  Compass,
  Heart,
  Images,
  LayoutGrid,
  Map,
  Menu,
  MessageCircle,
  Pencil,
  Repeat,
  Rss,
  Settings,
  Smartphone,
  Sparkles,
  Trash2,
  TrendingUp,
  Trophy,
  Users,
  X,
} from 'lucide-react';
import { chatKeys, chatRepository } from '@/features/chat/chatRepository';
import {
  notificationsKeys,
  notificationsRepository,
} from '@/features/notifications/notificationsRepository';
import { adminKeys } from '@/features/admin/adminRepository';
import { api } from '@/lib/api/client';
import { Avatar } from '@/components/ui/Avatar';
import { cn } from '@/lib/utils/cn';
import { ScreenHeaderSlot } from './ScreenHeader';
import { useAuth } from '@/features/auth/AuthProvider';
import {
  availableShortcuts,
  readShortcuts,
  writeShortcuts,
  type ShortcutSpec,
} from './sidebarShortcuts';
import { useCompleteOnboardingTodo } from '@/features/home/onboardingTodo';

/** kSidebarBreakpoint din main_scaffold.dart. */
const DESKTOP_BREAKPOINT = 900;

const ShellContext = createContext<{ openShortcutsEditor: () => void }>({
  openShortcutsEditor: () => {},
});

/**
 * Deschide editarea scurtăturilor din afara meniului - e nevoie pentru pasul
 * „pune-ți scurtăturile" din lista „Descoperă ShelfShare", care stă pe Home.
 * Pe telefon deschide și panoul glisant: altfel butonul n-ar face nimic
 * vizibil, fiindcă meniul e ascuns.
 */
export function useOpenShortcutsEditor(): () => void {
  return use(ShellContext).openShortcutsEditor;
}

interface NavItem {
  to: string;
  labelKey: string;
  icon: typeof BookOpen;
}

const MAIN_NAV: NavItem[] = [
  { to: '/', labelKey: 'navHome', icon: LayoutGrid },
  { to: '/search', labelKey: 'navSearch', icon: Compass },
  { to: '/library', labelKey: 'navLibrary', icon: BookOpen },
  { to: '/activity-feed', labelKey: 'navActivityFeed', icon: Rss },
  { to: '/chat', labelKey: 'navChat', icon: MessageCircle },
  { to: '/notifications', labelKey: 'navNotifications', icon: Bell },
];

/** Iconița fiecărei scurtături, pe cheia din `sidebarShortcuts.ts`. */
const SHORTCUT_ICONS: Record<string, typeof BookOpen> = {
  myBooks: BookMarked,
  exchanges: Repeat,
  wishlist: Heart,
  collections: Images,
  activityFeed: Rss,
  smartMatches: Sparkles,
  following: Users,
  leaderboard: Trophy,
  globalStats: TrendingUp,
  map: Map,
  groups: Users,
  sellerAnalytics: TrendingUp,
  trash: Trash2,
};

/**
 * Shell-ul aplicației după autentificare: pe desktop sidebar permanent în
 * stânga, pe mobil același conținut într-un panou glisant.
 *
 * Sidebar-ul e randat ÎN AFARA zonei care se schimbă la navigare (`Outlet`),
 * nu în interiorul fiecărui ecran. În Flutter bug-ul „meniul dispare când dau
 * click pe Notificări" venea exact de aici.
 */
export function AppShell() {
  const [drawerOpen, setDrawerOpen] = useState(false);
  // Editarea scurtăturilor stă aici, nu în `SidebarContent`: bara laterală e
  // randată de două ori (fixă pe desktop, glisantă pe telefon), iar starea
  // ținută înăuntru s-ar fi dublat - plus că se pornește și din afara meniului.
  const [editingShortcuts, setEditingShortcuts] = useState(false);
  // Nodul în care ecranul curent își desenează bara de sus (vezi ScreenHeader).
  const [headerSlot, setHeaderSlot] = useState<HTMLElement | null>(null);
  const location = useLocation();

  const openShortcutsEditor = useCallback(() => {
    setEditingShortcuts(true);
    if (window.innerWidth < DESKTOP_BREAKPOINT) setDrawerOpen(true);
  }, []);

  const shellValue = useMemo(() => ({ openShortcutsEditor }), [openShortcutsEditor]);

  // Panoul se închide la fiecare navigare. Fără asta rămâne deschis peste
  // ecranul nou, iar pe telefon userul crede că nu s-a întâmplat nimic.
  useEffect(() => {
    setDrawerOpen(false);
  }, [location.pathname]);

  useEffect(() => {
    if (!drawerOpen) return;
    const onKey = (event: KeyboardEvent) => {
      if (event.key === 'Escape') setDrawerOpen(false);
    };
    window.addEventListener('keydown', onKey);
    return () => window.removeEventListener('keydown', onKey);
  }, [drawerOpen]);

  return (
    <ShellContext value={shellValue}>
    <div className="flex min-h-dvh bg-background">
      {/* `sticky top-0 h-dvh`: fără ele, bara laterală derulează odată cu
          pagina și dispare pe ecranele lungi. */}
      <aside className="sticky top-0 hidden h-dvh w-[240px] shrink-0 flex-col overflow-y-auto border-r border-border bg-card min-[900px]:flex">
        <SidebarContent editing={editingShortcuts} setEditing={setEditingShortcuts} />
      </aside>

      {drawerOpen && (
        <div className="fixed inset-0 z-50 min-[900px]:hidden">
          <button
            aria-label="Close menu"
            onClick={() => setDrawerOpen(false)}
            className="absolute inset-0 bg-black/50"
          />
          <div className="absolute inset-y-0 left-0 flex w-[240px] flex-col overflow-y-auto bg-card shadow-xl">
            <SidebarContent
              editing={editingShortcuts}
              setEditing={setEditingShortcuts}
              onClose={() => setDrawerOpen(false)}
            />
          </div>
        </div>
      )}

      <div className="flex min-w-0 flex-1 flex-col">
        {/* Butonul de meniu stă fix în același colț pe orice ecran; în Flutter
            se muta la dreapta când ecranul avea o săgeată de back, iar poziția
            „sărea" stânga-dreapta la navigare. */}
        <button
          onClick={() => setDrawerOpen(true)}
          aria-label="Open menu"
          className="fixed left-2 top-2 z-40 rounded-full bg-card p-3.5 shadow-md min-[900px]:hidden"
        >
          <Menu size={22} />
        </button>

        {/* Goală până o umple ecranul, deci fără înălțime proprie: un ecran
            care nu-și pune bară nu rămâne cu o fâșie albă în cap. */}
        <header
          ref={setHeaderSlot}
          className="sticky top-0 z-30 flex shrink-0 flex-col bg-background"
        />

        <main className="min-w-0 flex-1">
          <ScreenHeaderSlot slot={headerSlot}>
            <Outlet />
          </ScreenHeaderSlot>
        </main>
      </div>
    </div>
    </ShellContext>
  );
}

function SidebarContent({
  editing,
  setEditing,
  onClose,
}: {
  editing: boolean;
  setEditing: (editing: boolean) => void;
  onClose?: () => void;
}) {
  const { t } = useTranslation();
  const { user } = useAuth();
  const [shortcuts, setShortcuts] = useState<string[]>(readShortcuts);
  const completeTodo = useCompleteOnboardingTodo();

  // Badge-urile se citesc aici, în shell: e mereu montat, deci numerele rămân
  // corecte indiferent pe ce pagină e userul.
  const unreadMessages = useQuery({
    queryKey: chatKeys.unreadCount(),
    queryFn: ({ signal }) => chatRepository.getUnreadCount(signal),
    select: (data) => data.count,
    enabled: !!user,
  });

  const unreadNotifications = useQuery({
    queryKey: notificationsKeys.list(),
    queryFn: ({ signal }) => notificationsRepository.list(signal),
    select: (items) => items.filter((item) => !item.isRead).length,
    enabled: !!user,
  });

  const badges: Record<string, number | undefined> = {
    '/chat': unreadMessages.data,
    '/notifications': unreadNotifications.data,
  };

  const allowed = availableShortcuts(user?.canAccessAdvancedStats === true);
  // O scurtătură salvată cândva poate să nu mai fie accesibilă acum (ex.
  // „Analize vânzător" după ce expiră Premium-ul) - lăsată în meniu, ar duce
  // garantat într-un 403.
  const visible = shortcuts.filter((key) => allowed.some((spec) => spec.key === key));

  function toggleShortcut(key: string) {
    const next = visible.includes(key)
      ? visible.filter((value) => value !== key)
      : [...visible, key];
    setShortcuts(next);
    writeShortcuts(next);
    // Pasul „pune-ți scurtăturile" se bifează când lista chiar s-a schimbat,
    // indiferent de unde s-a pornit editarea - din creion sau din cardul de pe
    // Home (vezi _markTodoDone din sidebar_shortcuts.dart).
    completeTodo('shortcuts');
  }

  return (
    <>
      <div className="flex items-center gap-2.5 px-5 pb-4 pt-5">
        <span className="rounded-lg bg-accent/15 p-1.5 text-accent">
          <BookOpen size={20} />
        </span>
        <span className="font-display text-base font-bold">ShelfShare</span>
        <OnlineUsersBadge />
        {onClose && (
          <button onClick={onClose} aria-label="Close menu" className="ml-auto p-1">
            <X size={18} />
          </button>
        )}
      </div>

      <nav className="flex-1">
        {MAIN_NAV.map((item) => (
          <SidebarTile
            key={item.to}
            to={item.to}
            icon={item.icon}
            label={t(item.labelKey)}
            badge={badges[item.to]}
            exact={item.to === '/'}
          />
        ))}

        <div className="mt-5 flex items-center gap-1 pl-5 pr-2">
          <span className="flex-1 text-[11px] font-semibold uppercase tracking-[0.1em] text-muted-foreground">
            {t('navShortcuts')}
          </span>
          <button
            onClick={() => setEditing(!editing)}
            aria-label={t(editing ? 'shortcutsDoneTooltip' : 'shortcutsEditTooltip')}
            title={t(editing ? 'shortcutsDoneTooltip' : 'shortcutsEditTooltip')}
            className="rounded-md p-1.5 text-muted-foreground hover:bg-muted"
          >
            {editing ? <Check size={16} /> : <Pencil size={16} />}
          </button>
        </div>

        {editing ? (
          // În editare se arată TOATE scurtăturile disponibile, bifate sau nu -
          // altfel n-ar exista nicio cale de a adăuga una scoasă anterior.
          <div className="mt-1">
            {allowed.map((spec) => (
              <ShortcutToggle
                key={spec.key}
                spec={spec}
                checked={visible.includes(spec.key)}
                onToggle={() => toggleShortcut(spec.key)}
              />
            ))}
          </div>
        ) : (
          <div className="mt-1">
            {visible.map((key) => {
              const spec = allowed.find((item) => item.key === key);
              if (!spec) return null;
              return (
                <SidebarTile
                  key={key}
                  to={spec.route}
                  icon={SHORTCUT_ICONS[key] ?? BookOpen}
                  label={t(spec.labelKey)}
                />
              );
            })}
          </div>
        )}

        <AndroidInstallCard />
      </nav>

      <div className="border-t border-border">
        <SidebarTile to="/settings" icon={Settings} label={t('profileSettings')} />
        <ProfileFooter />
      </div>
    </>
  );
}

function SidebarTile({
  to,
  icon: Icon,
  label,
  badge,
  exact = false,
}: {
  to: string;
  icon: typeof BookOpen;
  label: string;
  badge?: number;
  exact?: boolean;
}) {
  return (
    <NavLink
      to={to}
      // `end` doar pentru rădăcină: fără el, „/" ar fi marcat activ pe orice
      // rută, fiindcă e prefixul tuturor.
      end={exact}
      className={({ isActive }) =>
        cn(
          'mx-3 flex items-center gap-3 rounded-[12px] px-3 py-2.5 text-sm transition',
          isActive ? 'bg-accent/15 font-semibold text-accent' : 'text-foreground hover:bg-muted',
        )
      }
    >
      <Icon size={20} className="shrink-0" />
      <span className="flex-1 truncate">{label}</span>
      {badge != null && badge > 0 && (
        <span className="rounded-full bg-accent px-1.5 py-0.5 text-[11px] font-bold text-accent-foreground">
          {badge > 99 ? '99+' : badge}
        </span>
      )}
    </NavLink>
  );
}

function ShortcutToggle({
  spec,
  checked,
  onToggle,
}: {
  spec: ShortcutSpec;
  checked: boolean;
  onToggle: () => void;
}) {
  const { t } = useTranslation();
  const Icon = SHORTCUT_ICONS[spec.key] ?? BookOpen;

  return (
    <label className="mx-3 flex cursor-pointer items-center gap-3 rounded-[12px] px-3 py-2.5 text-sm hover:bg-muted">
      <Icon size={20} className="shrink-0 text-muted-foreground" />
      <span className="flex-1 truncate">{t(spec.labelKey)}</span>
      <input
        type="checkbox"
        checked={checked}
        onChange={onToggle}
        className="size-4 accent-[var(--ss-accent)]"
      />
    </label>
  );
}

interface OnlinePresence {
  users: number;
  connections: number;
  sample?: Array<{ name: string }>;
}

/**
 * Numărul de useri online, lângă logo. Doar pentru admini - e un indicator de
 * operare, nu conținut pentru public.
 */
function OnlineUsersBadge() {
  const { user } = useAuth();

  const presence = useQuery({
    queryKey: [...adminKeys.stats(), 'online'],
    queryFn: ({ signal }) => api.get<OnlinePresence>('/admin/stats/online', { signal }),
    enabled: user?.isAdmin === true,
    // Prezența e volatilă; o reîmprospătăm periodic, nu doar la montare.
    refetchInterval: 30_000,
  });

  if (!presence.data) return null;

  const names = (presence.data.sample ?? []).map((row) => row.name).filter(Boolean);
  const summary = `${presence.data.users} online (${presence.data.connections} conexiuni)`;

  return (
    <span
      title={names.length > 0 ? `${summary}\n${names.join(', ')}` : summary}
      className="ml-auto flex items-center gap-1.5 rounded-full bg-success/15 px-2 py-0.5"
    >
      <span className="size-[7px] rounded-full bg-success" />
      <span className="text-xs font-bold text-success">{presence.data.users}</span>
    </span>
  );
}

/**
 * Invitația de a instala aplicația de Android. Apare doar în meniul de
 * desktop: pe telefon aceeași invitație e banda lipită jos, iar în panoul
 * glisant ar fi văzută rar.
 */
function AndroidInstallCard() {
  const { t } = useTranslation();
  const [dismissed, setDismissed] = useState(() => {
    try {
      return window.localStorage.getItem('shelfshare.install_dismissed') === '1';
    } catch {
      return false;
    }
  });

  if (dismissed) return null;

  return (
    <div className="mx-3 mt-5 hidden rounded-[12px] border border-border bg-muted/50 p-3 min-[900px]:block">
      <div className="mb-1 flex items-start gap-2">
        <Smartphone size={16} className="mt-0.5 shrink-0 text-accent" />
        <span className="flex-1 text-sm font-semibold leading-snug">
          {t('installCardTitle')}
        </span>
        <button
          onClick={() => {
            setDismissed(true);
            try {
              window.localStorage.setItem('shelfshare.install_dismissed', '1');
            } catch {
              /* storage blocat - reapare la următoarea sesiune */
            }
          }}
          aria-label={t('commonClose')}
          className="shrink-0 text-muted-foreground hover:text-foreground"
        >
          <X size={14} />
        </button>
      </div>
      <p className="mb-2 text-xs leading-snug text-muted-foreground">{t('installCardText')}</p>
      <a
        href="/get-the-app"
        className="block rounded-full bg-primary px-3 py-2 text-center text-xs font-bold text-primary-foreground"
      >
        {t('installCardAction')}
      </a>
    </div>
  );
}

function ProfileFooter() {
  const { user } = useAuth();
  if (!user) return null;

  const displayName = user.name?.trim() ? user.name : user.email;

  return (
    <NavLink
      to="/profile"
      className={({ isActive }) =>
        cn('flex items-center gap-3 px-4 py-3', isActive ? 'bg-accent/[0.08]' : 'hover:bg-muted')
      }
    >
      <Avatar src={user.profileImage} name={displayName} size={36} />
      <span className="min-w-0 flex-1">
        {/* `min-w-0` pe container + `truncate`: fără el, un nume lung împinge
            totul în afara barei laterale. */}
        <span className="block truncate text-[13px] font-semibold">{displayName}</span>
        {user.username && (
          <span className="block truncate text-xs text-muted-foreground">@{user.username}</span>
        )}
      </span>
    </NavLink>
  );
}

export { DESKTOP_BREAKPOINT };
