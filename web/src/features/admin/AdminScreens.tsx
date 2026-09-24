import { useState } from 'react';
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { Link, Navigate, useParams } from 'react-router-dom';
import { useTranslation } from 'react-i18next';
import { ScreenHeader } from '@/components/layout/ScreenHeader';
import { ChevronRight, Search, Send, ShieldOff, Star } from 'lucide-react';
import {
  adminChatRepository,
  adminKeys,
  adminRepository,
  type AdminReport,
  type AdminUser,
} from './adminRepository';
import { Avatar } from '@/components/ui/Avatar';
import { Button, ErrorNotice, Spinner } from '@/components/ui';
import { useToast } from '@/components/ui/Toast';
import { useAuth } from '@/features/auth/AuthProvider';
import { formatRelativeTime } from '@/lib/utils/time';
import { cn } from '@/lib/utils/cn';

/**
 * Panoul de administrare. Toate ecranele lui stau împreună: sunt variații pe
 * „listă + o acțiune", iar separate ar fi zece fișiere care repetă aceeași
 * schelă de încărcare/eroare/gol.
 *
 * Accesul e verificat AICI, nu doar în meniu: intrarea din sidebar se ascunde
 * pentru non-admini, dar ruta rămâne tastabilă. Backendul refuză oricum, însă
 * un 403 brut arată ca un bug, nu ca o interdicție.
 */
export function RequireAdmin({ children }: { children: React.ReactNode }) {
  const { user, status } = useAuth();
  if (status.kind === 'restoring') return null;
  if (!user?.isAdmin) return <Navigate to="/" replace />;
  return <>{children}</>;
}

/**
 * Bara de sus a unui ecran de admin. Toate au aceeasi forma in Flutter - titlu
 * centrat si sageata inapoi spre panou - deci merita un singur loc.
 */
function AdminHeader({ title, to = '/admin' }: { title: string; to?: string }) {
  return <ScreenHeader title={title} back={to} />;
}

const ADMIN_LINKS = [
  { to: '/admin/users', titleKey: 'adminUsersCount', descKey: null },
  { to: '/admin/reports', titleKey: 'adminReportsTitle', descKey: 'adminReportsDesc' },
  { to: '/admin/usage', titleKey: 'adminStatsTitle', descKey: 'adminStatsGrowthDesc' },
  { to: '/admin/listings/inactive', titleKey: 'adminInactiveListingsCount', descKey: null },
  { to: '/admin/administrators', titleKey: 'adminAdministratorsTitle', descKey: 'adminAdministratorsDesc' },
  { to: '/admin/roles', titleKey: 'adminRolesTitle', descKey: null },
  { to: '/admin/feature-access', titleKey: 'adminFeatureAccessTitle', descKey: 'adminFeatureAccessDesc' },
  { to: '/admin/chat', titleKey: 'adminChatInboxTitle', descKey: 'adminChatInboxDesc' },
  { to: '/admin/book-requests', titleKey: 'adminBookRequestsTitle', descKey: 'adminBookRequestsDesc' },
  { to: '/admin/stores', titleKey: 'adminStoresTitle', descKey: 'adminStoresSubtitle' },
] as const;

export function AdminScreen() {
  const { t } = useTranslation();

  const stats = useQuery({
    queryKey: adminKeys.stats(),
    queryFn: ({ signal }) => adminRepository.stats(signal),
  });

  return (
    <RequireAdmin>
      <div className="mx-auto w-full max-w-[760px] px-5 pb-16 pt-4 min-[900px]:px-8">
        <ScreenHeader title={t('profileAdminPanel')} />

        {stats.isSuccess && (
          <div className="mb-6 grid grid-cols-2 gap-3 min-[560px]:grid-cols-3">
            <StatTile
              label={t('adminStatsUsersLabel')}
              value={stats.data.users?.total}
              hint={
                stats.data.users?.verified !== undefined
                  ? t('adminStatsUsersSubtitle', { count: stats.data.users.verified })
                  : undefined
              }
            />
            <StatTile
              label={t('adminStatsBooksLabel')}
              value={stats.data.books?.totalInCatalog}
              hint={
                stats.data.books?.totalListings !== undefined
                  ? t('adminStatsBooksSubtitle', { count: stats.data.books.totalListings })
                  : undefined
              }
            />
            <StatTile
              label={t('adminStatsExchangesLabel')}
              value={stats.data.exchanges?.total}
              hint={
                stats.data.exchanges?.completed !== undefined
                  ? t('adminStatsExchangesSubtitle', {
                      completed: stats.data.exchanges.completed,
                      pending: stats.data.exchanges.pending ?? 0,
                    })
                  : undefined
              }
            />
          </div>
        )}

        <div className="overflow-hidden rounded-[16px] border border-border bg-card">
          {ADMIN_LINKS.map((link) => (
            <Link
              key={link.to}
              to={link.to}
              className="flex items-center justify-between gap-3 border-b border-border px-4 py-3.5 last:border-b-0 hover:bg-muted"
            >
              <span className="min-w-0">
                <span className="block truncate font-medium">
                  {/* Cheile cu `{count}` sunt și titluri de secțiune în
                      Flutter; le dăm 0 ca ICU să nu arunce pe placeholder
                      lipsă, iar numărul real se vede în ecranul respectiv. */}
                  {t(link.titleKey, { count: 0 })}
                </span>
                {link.descKey && (
                  <span className="block truncate text-sm text-muted-foreground">
                    {t(link.descKey)}
                  </span>
                )}
              </span>
              <ChevronRight size={16} className="shrink-0 text-muted-foreground" />
            </Link>
          ))}
        </div>
      </div>
    </RequireAdmin>
  );
}

function StatTile({ label, value, hint }: { label: string; value: unknown; hint?: string }) {
  return (
    <div className="rounded-[16px] border border-border bg-card p-4">
      <p className="font-display text-2xl font-bold">
        {value === undefined || value === null ? '—' : String(value)}
      </p>
      <p className="text-xs text-muted-foreground">{label}</p>
      {hint && <p className="mt-0.5 text-[11px] text-muted-foreground">{hint}</p>}
    </div>
  );
}

export function AdminUsersScreen() {
  const { t } = useTranslation();
  const queryClient = useQueryClient();
  const toast = useToast();
  const [term, setTerm] = useState('');
  const [query, setQuery] = useState('');

  const users = useQuery({
    queryKey: adminKeys.users(query),
    queryFn: ({ signal }) => adminRepository.users({ q: query }, signal),
  });

  const act = useMutation({
    mutationFn: ({ id, action }: { id: string; action: 'ban' | 'unban' | 'premium' }) =>
      action === 'ban'
        ? adminRepository.banUser(id)
        : action === 'unban'
          ? adminRepository.unbanUser(id)
          : adminRepository.togglePremium(id),
    onSuccess: () => queryClient.invalidateQueries({ queryKey: ['admin', 'users'] }),
    onError: () => toast.show(t('commonGenericError'), 'danger'),
  });

  return (
    <RequireAdmin>
      <div className="mx-auto w-full max-w-[760px] px-5 pb-16 pt-4 min-[900px]:px-8">
        <AdminHeader title={t('adminUsersCount', { count: users.data?.length ?? 0 })} />

        <form
          onSubmit={(event) => {
            event.preventDefault();
            setQuery(term.trim());
          }}
          className="mb-6 flex items-center gap-2 rounded-[16px] bg-muted px-4"
        >
          <Search size={18} className="shrink-0 text-muted-foreground" />
          <input
            value={term}
            onChange={(event) => setTerm(event.target.value)}
            placeholder={t('adminFeatureAccessSearchHint')}
            aria-label={t('adminFeatureAccessSearchHint')}
            className="w-full bg-transparent py-3.5 text-foreground placeholder:text-muted-foreground focus:outline-none"
          />
        </form>

        {users.isPending ? (
          <div className="flex h-40 items-center justify-center text-accent">
            <Spinner size={26} />
          </div>
        ) : users.isError ? (
          <ErrorNotice message={t('adminLoadError')} onRetry={() => void users.refetch()} />
        ) : users.data.length === 0 ? (
          <p className="py-16 text-center text-muted-foreground">
            {t('adminFeatureAccessNoResults')}
          </p>
        ) : (
          <ul className="flex flex-col gap-2">
            {users.data.map((person) => (
              <AdminUserRow
                key={person.id}
                person={person}
                busy={act.isPending}
                onAct={(action) => act.mutate({ id: person.id, action })}
              />
            ))}
          </ul>
        )}
      </div>
    </RequireAdmin>
  );
}

function AdminUserRow({
  person,
  busy,
  onAct,
}: {
  person: AdminUser;
  busy: boolean;
  onAct: (action: 'ban' | 'unban' | 'premium') => void;
}) {
  const { t } = useTranslation();
  const name = person.name ?? person.username ?? person.email;

  return (
    <li className="flex items-center gap-3 rounded-[16px] border border-border bg-card p-3">
      <Avatar src={person.profileImage} name={name} size={40} />
      <div className="min-w-0 flex-1">
        <Link to={`/users/${person.id}`} className="truncate font-semibold hover:underline">
          {name}
        </Link>
        <p className="truncate text-sm text-muted-foreground">{person.email}</p>
        <p className="flex flex-wrap gap-2 text-[11px] text-muted-foreground">
          {person.isAdmin && <span className="text-accent">admin</span>}
          {person.isPremium && <span className="text-warning">premium</span>}
          {person.isBanned && <span className="text-danger-text">blocat</span>}
        </p>
      </div>

      <button
        onClick={() => onAct('premium')}
        disabled={busy}
        title="premium"
        aria-label="premium"
        className="shrink-0 rounded-[12px] p-2.5 text-muted-foreground hover:bg-muted hover:text-warning disabled:opacity-50"
      >
        <Star size={18} />
      </button>
      <button
        onClick={() => onAct(person.isBanned ? 'unban' : 'ban')}
        disabled={busy}
        title={t(person.isBanned ? 'adminUserUnblock' : 'adminUserBlock')}
        aria-label={t(person.isBanned ? 'adminUserUnblock' : 'adminUserBlock')}
        className="shrink-0 rounded-[12px] p-2.5 text-muted-foreground hover:bg-muted hover:text-danger-text disabled:opacity-50"
      >
        <ShieldOff size={18} />
      </button>
    </li>
  );
}

const REPORT_TARGET_KEYS: Record<string, string> = {
  USER: 'adminReportTargetUser',
  LISTING: 'adminReportTargetListing',
  REVIEW: 'adminReportTargetReview',
  CONVERSATION: 'adminReportTargetConversation',
  GROUP_POST: 'adminReportTargetGroupPost',
  EXCHANGE: 'adminReportTargetExchange',
};

export function AdminReportsScreen() {
  const { t, i18n } = useTranslation();
  const queryClient = useQueryClient();
  const toast = useToast();
  const [typeFilter, setTypeFilter] = useState<string>('');
  const [statusFilter, setStatusFilter] = useState<string>('');

  const reports = useQuery({
    queryKey: adminKeys.reports(),
    queryFn: ({ signal }) => adminRepository.reports(signal),
  });

  const setStatus = useMutation({
    mutationFn: ({ id, status }: { id: string; status: string }) =>
      adminRepository.setReportStatus(id, status),
    onSuccess: () => queryClient.invalidateQueries({ queryKey: adminKeys.reports() }),
    onError: () => toast.show(t('adminReportUpdateError'), 'danger'),
  });

  const all = reports.data ?? [];
  const types = [...new Set(all.map((report) => report.targetType))];
  const statuses = [...new Set(all.map((report) => report.status))];
  const visible = all.filter(
    (report) =>
      (!typeFilter || report.targetType === typeFilter) &&
      (!statusFilter || report.status === statusFilter),
  );

  return (
    <RequireAdmin>
      <div className="mx-auto w-full max-w-[760px] px-5 pb-16 pt-4 min-[900px]:px-8">
        <AdminHeader title={t('adminReportsTitle')} />
        <p className="mb-6 text-muted-foreground">{t('adminReportsDesc')}</p>

        <FilterRow
          label={t('adminReportsFilterType')}
          options={types.map((type) => ({
            value: type,
            label: t(REPORT_TARGET_KEYS[type] ?? 'adminReportsFilterAll'),
          }))}
          selected={typeFilter}
          onSelect={setTypeFilter}
        />
        <FilterRow
          label={t('adminReportsFilterStatus')}
          options={statuses.map((status) => ({ value: status, label: status }))}
          selected={statusFilter}
          onSelect={setStatusFilter}
        />

        {reports.isPending ? (
          <div className="flex h-40 items-center justify-center text-accent">
            <Spinner size={26} />
          </div>
        ) : reports.isError ? (
          <ErrorNotice message={t('adminLoadError')} onRetry={() => void reports.refetch()} />
        ) : visible.length === 0 ? (
          <p className="py-16 text-center text-muted-foreground">{t('adminNoReports')}</p>
        ) : (
          <ul className="flex flex-col gap-2">
            {visible.map((report) => (
              <ReportRow
                key={report.id}
                report={report}
                locale={i18n.language}
                busy={setStatus.isPending}
                onStatus={(status) => setStatus.mutate({ id: report.id, status })}
              />
            ))}
          </ul>
        )}
      </div>
    </RequireAdmin>
  );
}

function ReportRow({
  report,
  locale,
  busy,
  onStatus,
}: {
  report: AdminReport;
  locale: string;
  busy: boolean;
  onStatus: (status: string) => void;
}) {
  const { t } = useTranslation();

  return (
    <li className="rounded-[16px] border border-border bg-card p-4">
      <div className="mb-2 flex flex-wrap items-center gap-2">
        <span className="rounded-full border border-border px-2.5 py-0.5 text-[11px]">
          {t(REPORT_TARGET_KEYS[report.targetType] ?? 'adminReportsFilterAll')}
        </span>
        <span className="rounded-full border border-border px-2.5 py-0.5 text-[11px] text-muted-foreground">
          {report.status}
        </span>
        <span className="ml-auto text-xs text-muted-foreground">
          {formatRelativeTime(report.createdAt, locale)}
        </span>
      </div>

      <p className="whitespace-pre-line break-words">{report.reason}</p>

      <div className="mt-3 flex flex-wrap gap-2">
        {['RESOLVED', 'DISMISSED'].map((status) => (
          <Button key={status} variant="outline" disabled={busy} onClick={() => onStatus(status)}>
            {status}
          </Button>
        ))}
      </div>
    </li>
  );
}

function FilterRow({
  label,
  options,
  selected,
  onSelect,
}: {
  label: string;
  options: Array<{ value: string; label: string }>;
  selected: string;
  onSelect: (value: string) => void;
}) {
  const { t } = useTranslation();
  if (options.length === 0) return null;

  return (
    <div className="mb-4">
      <p className="mb-2 text-xs font-semibold uppercase tracking-wider text-muted-foreground">
        {label}
      </p>
      <div className="flex flex-wrap gap-2">
        <Chip active={!selected} onClick={() => onSelect('')}>
          {t('adminReportsFilterAll')}
        </Chip>
        {options.map((option) => (
          <Chip
            key={option.value}
            active={selected === option.value}
            onClick={() => onSelect(selected === option.value ? '' : option.value)}
          >
            {option.label}
          </Chip>
        ))}
      </div>
    </div>
  );
}

function Chip({
  active,
  onClick,
  children,
}: {
  active: boolean;
  onClick: () => void;
  children: React.ReactNode;
}) {
  return (
    <button
      onClick={onClick}
      className={cn(
        'rounded-full border px-3.5 py-1.5 text-sm transition',
        active
          ? 'border-accent bg-accent/15 font-semibold text-accent'
          : 'border-border hover:bg-muted',
      )}
    >
      {children}
    </button>
  );
}

export function AdminUsageScreen() {
  const { t } = useTranslation();

  const usage = useQuery({
    queryKey: adminKeys.usage(),
    queryFn: ({ signal }) => adminRepository.usage(signal),
  });

  return (
    <RequireAdmin>
      <div className="mx-auto w-full max-w-[760px] px-5 pb-16 pt-4 min-[900px]:px-8">
        <AdminHeader title={t('adminStatsTitle')} />

        {usage.isPending ? (
          <div className="flex h-40 items-center justify-center text-accent">
            <Spinner size={26} />
          </div>
        ) : usage.isError ? (
          <ErrorNotice message={t('adminLoadError')} onRetry={() => void usage.refetch()} />
        ) : (
          // Forma exactă a răspunsului diferă de la o versiune de backend la
          // alta; îl randăm generic, cheie-valoare, în loc să presupunem
          // câmpuri care ar dispărea fără să observe nimeni.
          <div className="grid grid-cols-2 gap-3 min-[560px]:grid-cols-3">
            {Object.entries(usage.data)
              .filter(([, value]) => typeof value === 'number' || typeof value === 'string')
              .map(([key, value]) => (
                <StatTile key={key} label={key} value={value} />
              ))}
          </div>
        )}
      </div>
    </RequireAdmin>
  );
}

export function AdminInactiveListingsScreen() {
  const { t } = useTranslation();

  const listings = useQuery({
    queryKey: adminKeys.inactiveListings(),
    queryFn: ({ signal }) => adminRepository.inactiveListings(signal),
  });

  return (
    <RequireAdmin>
      <div className="mx-auto w-full max-w-[760px] px-5 pb-16 pt-4 min-[900px]:px-8">
        <AdminHeader
          title={t('adminInactiveListingsCount', { count: listings.data?.length ?? 0 })}
        />

        {listings.isPending ? (
          <div className="flex h-40 items-center justify-center text-accent">
            <Spinner size={26} />
          </div>
        ) : listings.isError ? (
          <ErrorNotice message={t('adminLoadError')} onRetry={() => void listings.refetch()} />
        ) : listings.data.length === 0 ? (
          <p className="py-16 text-center text-muted-foreground">
            {t('adminNoInactiveListings')}
          </p>
        ) : (
          <ul className="flex flex-col gap-2">
            {listings.data.map((listing, index) => (
              <li
                key={String(listing.id ?? index)}
                className="rounded-[16px] border border-border bg-card p-3"
              >
                <p className="truncate font-medium">{String(listing.title ?? listing.id ?? '')}</p>
                {listing.ownerEmail ? (
                  <p className="truncate text-sm text-muted-foreground">
                    {String(listing.ownerEmail)}
                  </p>
                ) : null}
              </li>
            ))}
          </ul>
        )}
      </div>
    </RequireAdmin>
  );
}

export function AdministratorsScreen() {
  const { t } = useTranslation();

  const admins = useQuery({
    queryKey: adminKeys.administrators(),
    queryFn: ({ signal }) => adminRepository.administrators(signal),
  });

  return (
    <RequireAdmin>
      <div className="mx-auto w-full max-w-[680px] px-5 pb-16 pt-4 min-[900px]:px-8">
        <AdminHeader title={t('adminAdministratorsTitle')} />
        <p className="mb-6 text-muted-foreground">{t('adminAdministratorsDesc')}</p>

        {admins.isPending ? (
          <div className="flex h-40 items-center justify-center text-accent">
            <Spinner size={26} />
          </div>
        ) : admins.isError ? (
          <ErrorNotice
            message={t('adminAdministratorsLoadError')}
            onRetry={() => void admins.refetch()}
          />
        ) : (
          <ul className="flex flex-col gap-2">
            {admins.data.map((admin) => (
              <li
                key={admin.userId}
                className="flex items-center gap-3 rounded-[16px] border border-border bg-card p-3"
              >
                <Avatar name={admin.name ?? admin.email} size={40} />
                <div className="min-w-0 flex-1">
                  <p className="truncate font-semibold">{admin.name ?? admin.email}</p>
                  <p className="truncate text-sm text-muted-foreground">{admin.email}</p>
                </div>
                <span className="shrink-0 rounded-full border border-border px-2.5 py-0.5 text-[11px]">
                  {admin.role || t('adminAdministratorsNoRole')}
                </span>
              </li>
            ))}
          </ul>
        )}
      </div>
    </RequireAdmin>
  );
}

export function AdminRolesScreen() {
  const { t } = useTranslation();

  const roles = useQuery({
    queryKey: adminKeys.roles(),
    queryFn: ({ signal }) => adminRepository.roles(signal),
  });

  return (
    <RequireAdmin>
      <div className="mx-auto w-full max-w-[680px] px-5 pb-16 pt-4 min-[900px]:px-8">
        <AdminHeader title={t('adminRolesTitle')} />

        {roles.isPending ? (
          <div className="flex h-40 items-center justify-center text-accent">
            <Spinner size={26} />
          </div>
        ) : roles.isError ? (
          <ErrorNotice
            message={t('adminAdministratorsLoadError')}
            onRetry={() => void roles.refetch()}
          />
        ) : (
          <ul className="flex flex-col gap-2">
            {roles.data.map((role) => (
              <li key={role.id} className="rounded-[16px] border border-border bg-card p-4">
                <p className="font-semibold">{role.name}</p>
                <div className="mt-2 flex flex-wrap gap-1.5">
                  {role.permissions.map((permission) => (
                    <span
                      key={permission}
                      className="rounded-full border border-border px-2.5 py-0.5 text-[11px] text-muted-foreground"
                    >
                      {permission}
                    </span>
                  ))}
                </div>
              </li>
            ))}
          </ul>
        )}
      </div>
    </RequireAdmin>
  );
}

export function AdminFeatureAccessScreen() {
  const { t } = useTranslation();
  const toast = useToast();
  const [term, setTerm] = useState('');
  const [query, setQuery] = useState('');
  const [selected, setSelected] = useState<AdminUser | null>(null);

  const flags = useQuery({
    queryKey: adminKeys.featureFlags(),
    queryFn: ({ signal }) => adminRepository.featureFlags(signal),
  });

  const users = useQuery({
    queryKey: adminKeys.users(query),
    queryFn: ({ signal }) => adminRepository.users({ q: query }, signal),
    enabled: query.length > 0,
  });

  const userFlags = useQuery({
    queryKey: ['admin', 'users', selected?.id, 'flags'],
    queryFn: ({ signal }) => adminRepository.userFeatureFlags(selected!.id, signal),
    enabled: !!selected,
  });

  const save = useMutation({
    mutationFn: (next: Record<string, boolean>) =>
      adminRepository.setUserFeatureFlags(selected!.id, next),
    onSuccess: () => {
      void userFlags.refetch();
      toast.show(t('adminFeatureAccessSaved'));
    },
    onError: () => toast.show(t('adminFeatureAccessSaveError'), 'danger'),
  });

  return (
    <RequireAdmin>
      <div className="mx-auto w-full max-w-[680px] px-5 pb-16 pt-4 min-[900px]:px-8">
        <AdminHeader title={t('adminFeatureAccessTitle')} />
        <p className="mb-6 text-muted-foreground">{t('adminFeatureAccessDesc')}</p>

        <form
          onSubmit={(event) => {
            event.preventDefault();
            setQuery(term.trim());
            setSelected(null);
          }}
          className="mb-6 flex items-center gap-2 rounded-[16px] bg-muted px-4"
        >
          <Search size={18} className="shrink-0 text-muted-foreground" />
          <input
            value={term}
            onChange={(event) => setTerm(event.target.value)}
            placeholder={t('adminFeatureAccessSearchHint')}
            aria-label={t('adminFeatureAccessSearchHint')}
            className="w-full bg-transparent py-3.5 text-foreground placeholder:text-muted-foreground focus:outline-none"
          />
        </form>

        {!query ? (
          <p className="py-12 text-center text-muted-foreground">
            {t('adminFeatureAccessSearchEmpty')}
          </p>
        ) : selected ? (
          <>
            <button
              onClick={() => setSelected(null)}
              className="mb-4 text-sm text-accent hover:underline"
            >
              {selected.email}
            </button>

            {userFlags.isPending ? (
              <div className="flex h-24 items-center justify-center text-accent">
                <Spinner size={22} />
              </div>
            ) : (
              <div className="flex flex-col gap-2">
                {flags.data?.map((flag) => {
                  const enabled = userFlags.data?.[flag.key] === true;
                  return (
                    <label
                      key={flag.key}
                      className="flex cursor-pointer items-center gap-3 rounded-[16px] border border-border bg-card p-4"
                    >
                      <input
                        type="checkbox"
                        checked={enabled}
                        onChange={(event) =>
                          save.mutate({ ...userFlags.data, [flag.key]: event.target.checked })
                        }
                        className="size-4 accent-[var(--ss-accent)]"
                      />
                      <span className="min-w-0 flex-1 truncate">
                        {t(`featureFlag${toPascal(flag.key)}`, { defaultValue: flag.key })}
                      </span>
                    </label>
                  );
                })}
              </div>
            )}
          </>
        ) : users.isPending ? (
          <div className="flex h-24 items-center justify-center text-accent">
            <Spinner size={22} />
          </div>
        ) : (users.data ?? []).length === 0 ? (
          <p className="py-12 text-center text-muted-foreground">
            {t('adminFeatureAccessNoResults')}
          </p>
        ) : (
          <ul className="flex flex-col gap-2">
            {users.data?.map((person) => (
              <li key={person.id}>
                <button
                  onClick={() => setSelected(person)}
                  className="flex w-full items-center gap-3 rounded-[16px] border border-border bg-card p-3 text-left hover:bg-muted"
                >
                  <Avatar src={person.profileImage} name={person.name ?? person.email} size={36} />
                  <span className="min-w-0 flex-1">
                    <span className="block truncate font-medium">
                      {person.name ?? person.username ?? person.email}
                    </span>
                    <span className="block truncate text-sm text-muted-foreground">
                      {person.email}
                    </span>
                  </span>
                </button>
              </li>
            ))}
          </ul>
        )}
      </div>
    </RequireAdmin>
  );
}

/** `advanced_statistics` -> `AdvancedStatistics`, ca să formeze cheia din .arb. */
function toPascal(key: string): string {
  return key
    .split('_')
    .map((part) => part.charAt(0).toUpperCase() + part.slice(1))
    .join('');
}

export function AdminChatInboxScreen() {
  const { t, i18n } = useTranslation();

  const inbox = useQuery({
    queryKey: adminKeys.adminChatInbox(),
    queryFn: ({ signal }) => adminChatRepository.inbox(signal),
  });

  return (
    <RequireAdmin>
      <div className="mx-auto w-full max-w-[680px] px-5 pb-16 pt-4 min-[900px]:px-8">
        <AdminHeader title={t('adminChatInboxTitle')} />
        <p className="mb-6 text-muted-foreground">{t('adminChatInboxDesc')}</p>

        {inbox.isPending ? (
          <div className="flex h-40 items-center justify-center text-accent">
            <Spinner size={26} />
          </div>
        ) : inbox.isError ? (
          <ErrorNotice message={t('adminLoadError')} onRetry={() => void inbox.refetch()} />
        ) : inbox.data.length === 0 ? (
          <p className="py-16 text-center text-muted-foreground">{t('adminChatInboxEmpty')}</p>
        ) : (
          <ul className="flex flex-col gap-2">
            {inbox.data.map((conversation) => {
              const name =
                conversation.user.name ?? conversation.user.username ?? t('commonUnknownUser');
              return (
                <li key={conversation.id}>
                  <Link
                    to={`/admin/chat/${conversation.id}`}
                    className="flex items-center gap-3 rounded-[16px] border border-border bg-card p-3 hover:bg-muted"
                  >
                    <Avatar src={conversation.user.profileImage} name={name} size={40} />
                    <div className="min-w-0 flex-1">
                      <p className="truncate font-semibold">{name}</p>
                      <p className="truncate text-sm text-muted-foreground">
                        {conversation.lastMessage?.content ?? ''}
                      </p>
                    </div>
                    <span className="shrink-0 text-xs text-muted-foreground">
                      {formatRelativeTime(conversation.updatedAt, i18n.language)}
                    </span>
                    {conversation.unreadCount > 0 && (
                      <span className="shrink-0 rounded-full bg-accent px-2 py-0.5 text-[11px] font-bold text-accent-foreground">
                        {conversation.unreadCount}
                      </span>
                    )}
                  </Link>
                </li>
              );
            })}
          </ul>
        )}
      </div>
    </RequireAdmin>
  );
}

export function AdminChatConversationScreen() {
  const { id = '' } = useParams();
  const { t } = useTranslation();
  const queryClient = useQueryClient();
  const [draft, setDraft] = useState('');

  const messages = useQuery({
    queryKey: adminKeys.adminChatMessages(id),
    queryFn: ({ signal }) => adminChatRepository.messages(id, signal),
    enabled: !!id,
  });

  const send = useMutation({
    mutationFn: () => adminChatRepository.sendAsAdmin(id, draft.trim()),
    onSuccess: () => {
      setDraft('');
      void queryClient.invalidateQueries({ queryKey: adminKeys.adminChatMessages(id) });
    },
  });

  return (
    <RequireAdmin>
      <div className="mx-auto w-full max-w-[680px] px-5 pb-16 pt-4 min-[900px]:px-8">
        <AdminHeader title={t('adminChatTitle')} to="/admin/chat" />

        {messages.isPending ? (
          <div className="flex h-40 items-center justify-center text-accent">
            <Spinner size={26} />
          </div>
        ) : messages.isError ? (
          <ErrorNotice message={t('adminLoadError')} onRetry={() => void messages.refetch()} />
        ) : (
          <ul className="mb-4 flex flex-col gap-2">
            {messages.data.map((message) => (
              <li
                key={message.id}
                className={cn(
                  'max-w-[80%] rounded-[16px] px-4 py-2.5',
                  message.fromAdmin
                    ? 'self-end bg-primary text-primary-foreground'
                    : 'self-start border border-border bg-card',
                )}
              >
                <p className="whitespace-pre-line break-words">{message.content}</p>
              </li>
            ))}
          </ul>
        )}

        <form
          onSubmit={(event) => {
            event.preventDefault();
            if (draft.trim()) send.mutate();
          }}
          className="flex items-end gap-2"
        >
          <textarea
            value={draft}
            onChange={(event) => setDraft(event.target.value)}
            rows={2}
            placeholder={t('adminChatInputHint')}
            aria-label={t('adminChatInputHint')}
            className="max-h-32 w-full resize-none rounded-[16px] bg-muted px-4 py-3.5 text-foreground placeholder:text-muted-foreground focus:outline-none"
          />
          <button
            type="submit"
            disabled={!draft.trim() || send.isPending}
            aria-label={t('commonSubmit')}
            className="shrink-0 rounded-full bg-primary p-3 text-primary-foreground disabled:opacity-50"
          >
            {send.isPending ? <Spinner size={20} /> : <Send size={20} />}
          </button>
        </form>
      </div>
    </RequireAdmin>
  );
}
