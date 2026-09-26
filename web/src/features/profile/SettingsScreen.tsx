import { useState } from 'react';
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { Link } from 'react-router-dom';
import { useTranslation } from 'react-i18next';
import { ScreenHeader } from '@/components/layout/ScreenHeader';
import {
  analyticsSupported,
  getAnalyticsConsent,
  setAnalyticsConsent,
} from '@/lib/analytics/analytics';
import {
  BarChart3,
  Bell,
  BookOpen,
  ChevronDown,
  ChevronRight,
  Coffee,
  Eye,
  FileUp,
  Gavel,
  Globe,
  Heart,
  HelpCircle,
  Images,
  Layers,
  LogOut,
  Map as MapIcon,
  MessageSquare,
  Moon,
  Pencil,
  PlayCircle,
  QrCode,
  Rss,
  Shield,
  ShieldCheck,
  Sparkles,
  Trash2,
  TrendingUp,
  Trophy,
  UserRound,
  Users,
  Repeat,
  LifeBuoy,
  AlertTriangle,
} from 'lucide-react';
import { profileKeys, profileRepository } from './profileRepository';
import { Switch } from '@/components/ui/Switch';
import { Spinner } from '@/components/ui';
import { useToast } from '@/components/ui/Toast';
import { useAuth } from '@/features/auth/AuthProvider';
import { ProfileQrDialog } from '@/components/ui/ProfileQrDialog';
import { api } from '@/lib/api/client';
import { useTheme, type ThemeMode } from '@/lib/theme/themeStore';
import { setLocale, SUPPORTED_LOCALES, type AppLocale } from '@/lib/i18n';
import { cn } from '@/lib/utils/cn';
import { isCategoryEnabled, NOTIFICATION_CATEGORIES } from './notificationCategories';

const LOCALE_NAMES: Record<string, string> = {
  ro: 'Română',
  en: 'English',
  de: 'Deutsch',
  hu: 'Magyar',
};

export function SettingsScreen() {
  const { t, i18n } = useTranslation();
  const { user, logout } = useAuth();
  const { mode, setMode } = useTheme();
  const queryClient = useQueryClient();
  const toast = useToast();

  const [qrOpen, setQrOpen] = useState(false);
  const [picker, setPicker] = useState<'language' | 'theme' | null>(null);

  const preferences = useQuery({
    queryKey: profileKeys.notificationPreferences(),
    queryFn: ({ signal }) => profileRepository.notificationPreferences(signal),
  });

  const savePreferences = useMutation({
    mutationFn: (next: Record<string, boolean>) =>
      profileRepository.saveNotificationPreferences(next),
    // Optimist: comutatoarele trebuie să răspundă instant. Cu așteptarea
    // răspunsului, fiecare bifă „sare" înapoi pentru o clipă.
    onMutate: async (changes) => {
      await queryClient.cancelQueries({ queryKey: profileKeys.notificationPreferences() });
      const previous = queryClient.getQueryData<Record<string, boolean>>(
        profileKeys.notificationPreferences(),
      );
      // Îmbinare, nu înlocuire: `changes` conține doar tipurile categoriei
      // comutate, iar restul trebuie să rămână cum erau.
      queryClient.setQueryData(profileKeys.notificationPreferences(), {
        ...previous,
        ...changes,
      });
      return { previous };
    },
    onError: (_error, _next, context) => {
      queryClient.setQueryData(profileKeys.notificationPreferences(), context?.previous);
      toast.show(t('notificationPrefSaveError'), 'danger');
    },
  });

  const listingPrivacy = useMutation({
    mutationFn: (input: Parameters<typeof profileRepository.update>[0]) =>
      profileRepository.update(input),
    onSuccess: (updated) => queryClient.setQueryData(profileKeys.me(), updated),
    onError: () => toast.show(t('profileSaveError'), 'danger'),
  });

  const header = <ScreenHeader title={t('profileSettings')} back />;

  const themeLabelKey =
    mode === 'system' ? 'profileThemeSystem' : mode === 'light' ? 'profileThemeLight' : 'profileThemeDark';

  return (
    <div className="mx-auto w-full max-w-[680px] px-5 pb-16 pt-2 min-[900px]:px-8">
      {header}
      <p className="mb-5 text-xs text-muted-foreground">{t('profileSettingsSubtitle')}</p>

      <Group title={t('profileGroupAccount')}>
        <Row icon={Pencil} to="/profile/edit" label={t('profileEditProfile')} />
        {/* Limba și tema arată valoarea curentă în dreapta, ca în Flutter:
            altfel trebuie deschis meniul ca să afli pe ce ești. */}
        <Row
          icon={Globe}
          label={t('profileLanguage')}
          value={LOCALE_NAMES[i18n.language] ?? i18n.language}
          onClick={() => setPicker('language')}
        />
        <Row
          icon={Moon}
          label={t('profileDarkModeSection')}
          value={t(themeLabelKey)}
          onClick={() => setPicker('theme')}
        />
        <Row icon={QrCode} label={t('profileQrTooltip')} onClick={() => setQrOpen(true)} />
      </Group>

      <Group title={t('profileGroupLibrary')}>
        <Row icon={BookOpen} to="/bookshelf" label={t('bookshelfTitle')} />
        <Row icon={Images} to="/collections" label={t('collectionsTitle')} />
        <Row icon={Users} to="/groups" label={t('groupsTitle')} />
        <Row icon={Repeat} to="/exchanges" label={t('profileMyExchanges')} />
      </Group>

      <Group title={t('profileGroupNotifications')}>
        <Expandable
          icon={Bell}
          title={t('notificationPrefTitle')}
          subtitle={t('notificationPrefSubtitle')}
        >
          {preferences.isPending ? (
            <div className="flex justify-center p-4 text-accent">
              <Spinner size={22} />
            </div>
          ) : preferences.isError ? (
            <p className="text-sm text-danger-text">{t('notificationPrefLoadError')}</p>
          ) : (
            <div className="flex flex-col gap-2">
              {NOTIFICATION_CATEGORIES.map((category) => (
                <Switch
                  key={category.id}
                  checked={isCategoryEnabled(category, preferences.data)}
                  label={t(category.labelKey)}
                  onChange={(value) =>
                    // Comutăm TOATE tipurile categoriei deodată. Trimitem doar
                    // aceste tipuri, nu toată harta: PUT-ul e parțial, deci un
                    // al doilea tab deschis nu se suprascrie cu ce vede el.
                    savePreferences.mutate(
                      Object.fromEntries(category.types.map((type) => [type, value])),
                    )
                  }
                />
              ))}
            </div>
          )}
        </Expandable>
      </Group>

      <Group title={t('profileGroupPrivacy')}>
        <Expandable
          icon={Eye}
          title={t('profileListingPrivacyTitle')}
          subtitle={t('profileListingPrivacySubtitle')}
        >
          <div className="flex flex-col gap-2">
            <Switch
              checked={!user?.hideSwapListingsPublic}
              label={t('shareListingModeSwap')}
              onChange={(visible) => listingPrivacy.mutate({ hideSwapListingsPublic: !visible })}
            />
            <Switch
              checked={!user?.hideSaleListingsPublic}
              label={t('shareListingModeSale')}
              onChange={(visible) => listingPrivacy.mutate({ hideSaleListingsPublic: !visible })}
            />
            <Switch
              checked={!user?.hideDonationListingsPublic}
              label={t('shareListingModeDonation')}
              onChange={(visible) =>
                listingPrivacy.mutate({ hideDonationListingsPublic: !visible })
              }
            />
            <Switch
              checked={!user?.hideAuctionListingsPublic}
              label={t('shareListingModeAuction')}
              onChange={(visible) => listingPrivacy.mutate({ hideAuctionListingsPublic: !visible })}
            />
          </div>
        </Expandable>
        <div className="h-3" />
        <AnalyticsConsentCard />
      </Group>

      <Group title={t('profileGroupActivityDiscovery')}>
        <Row icon={Rss} to="/activity-feed" label={t('profileActivityFeed')} />
        <Row icon={BarChart3} to="/global-stats" label={t('profileGlobalStats')} />
        {user?.canAccessAdvancedStats && (
          <Row icon={TrendingUp} to="/seller-analytics" label={t('premiumAnalyticsTitle')} />
        )}
        <Row icon={Layers} to="/smart-matches" label={t('profileSmartMatches')} />
        <Row icon={Heart} to="/following" label={t('profileFavoriteSellers')} />
        <Row icon={Trophy} to="/leaderboard" label={t('profileLeaderboard')} />
      </Group>

      <Group title={t('profileGroupSupportApp')}>
        {/* Donația stă jos dinadins - simpatică, dar nu primul lucru din Setări. */}
        <Row
          icon={Coffee}
          to="/info/about-dev"
          label={t('profileKeepAlive')}
          subtitle={t('profileKeepAliveSubtitle')}
        />
      </Group>

      <Group title={t('profileGroupHelpLegal')}>
        <Row icon={PlayCircle} to="/tutorial" label={t('tutorialTitle')} />
        <Row icon={FileUp} to="/import" label={t('importTitle')} />
        <Row icon={MapIcon} to="/roadmap" label={t('profileRoadmap')} />
        {/*
          Paginile publice HTML, dar deschise ÎN aplicație (`/info/:page`), nu
          într-un tab nou: un `target="_blank"` pe telefon înseamnă că omul a
          plecat din aplicație ca să citească regulile ei. Adresele publice
          rămân neatinse - verificarea OAuth a Google și Play Console le cer
          accesibile fără autentificare. Vezi StaticPageScreen.
        */}
        <Row icon={Shield} to="/info/safety-center" label={t('profileSafetyCenter')} />
        <Row icon={HelpCircle} to="/info/help-center" label={t('profileHelpCenter')} />
        <Row icon={UserRound} to="/info/about-dev" label={t('aboutDevTitle')} />
        <Row icon={ShieldCheck} to="/info/privacy" label={t('profilePrivacyPolicy')} />
        <Row icon={Gavel} to="/info/terms" label={t('profileTermsOfService')} />
        <Row icon={MessageSquare} to="/feedback" label={t('profileSendFeedback')} />
        <Row icon={LifeBuoy} to="/support/chat" label={t('adminChatTitle')} />
      </Group>

      <Group title={t('profileGroupAccountActions')}>
        {/* Intrările de admin stau împreună: toggle-ul de scor e util doar
            cuiva care are deja acces la panou. */}
        {user?.isAdmin && <Row icon={Sparkles} to="/admin" label={t('profileAdminPanel')} />}
        <Row
          icon={LogOut}
          label={t('profileLogout')}
          danger
          onClick={() => void logout()}
        />
      </Group>

      <DeleteAccountSection />

      <p className="mt-4 text-center text-xs text-muted-foreground">
        ShelfShare {__APP_VERSION__}
      </p>

      {qrOpen && user && <ProfileQrDialog userId={user.id} onClose={() => setQrOpen(false)} />}

      {picker === 'language' && (
        <PickerSheet title={t('profileLanguage')} onClose={() => setPicker(null)}>
          {SUPPORTED_LOCALES.map((locale) => (
            <PickerOption
              key={locale}
              selected={i18n.language === locale}
              onClick={() => {
                void setLocale(locale as AppLocale);
                setPicker(null);
              }}
            >
              {LOCALE_NAMES[locale] ?? locale}
            </PickerOption>
          ))}
        </PickerSheet>
      )}

      {picker === 'theme' && (
        <PickerSheet title={t('profileDarkModeSection')} onClose={() => setPicker(null)}>
          {(['system', 'light', 'dark'] as const).map((value) => (
            <PickerOption
              key={value}
              selected={mode === value}
              onClick={() => {
                setMode(value as ThemeMode);
                setPicker(null);
              }}
            >
              {t(
                value === 'system'
                  ? 'profileThemeSystem'
                  : value === 'light'
                    ? 'profileThemeLight'
                    : 'profileThemeDark',
              )}
            </PickerOption>
          ))}
        </PickerSheet>
      )}
    </div>
  );
}

/**
 * Consimțământul pentru statistici de folosire; preferința e locală, nu pe
 * cont - ține de dispozitivul din fața userului.
 *
 * Pe web e EXACT consimțământul pentru Google Analytics (lib/analytics), deci
 * implicit OPRIT până la „Accept" - ca în Flutter web. Înainte comutatorul
 * scria o cheie pe care n-o citea nimeni. Pe Android rămâne cheia locală
 * (implicit pornit, ca în aplicația Flutter), până la portarea Firebase.
 */
function AnalyticsConsentCard() {
  const { t } = useTranslation();
  const web = analyticsSupported();
  const [enabled, setEnabled] = useState(() => {
    if (web) return getAnalyticsConsent() === 'granted';
    try {
      return window.localStorage.getItem('shelfshare.analytics') !== '0';
    } catch {
      return true;
    }
  });

  return (
    <Expandable icon={BarChart3} title={t('settingsAnalyticsTitle')} subtitle={t('settingsAnalyticsSubtitle')}>
      <Switch
        checked={enabled}
        label={t('settingsAnalyticsSwitch')}
        onChange={(value) => {
          setEnabled(value);
          if (web) {
            setAnalyticsConsent(value);
            return;
          }
          try {
            window.localStorage.setItem('shelfshare.analytics', value ? '1' : '0');
          } catch {
            /* storage blocat - alegerea ține doar cât sesiunea */
          }
        }}
      />
      <p className="mt-2 text-xs leading-relaxed text-muted-foreground">
        {t('settingsAnalyticsHelp')}
      </p>
    </Expandable>
  );
}

/**
 * Ștergerea contului, cu cele 15 zile de grație. Când e deja programată,
 * secțiunea devine un avertisment cu data și butonul de anulare.
 */
function DeleteAccountSection() {
  const { t, i18n } = useTranslation();
  const { user, setUser, logout } = useAuth();
  const queryClient = useQueryClient();
  const toast = useToast();

  const request = useMutation({
    mutationFn: () =>
      api.post<{ immediate?: boolean; deletionScheduledAt?: string }>('/account/delete-request'),
    onSuccess: async (result) => {
      // Backendul poate rula cu INSTANT_ACCOUNT_DELETION=true (testare locală):
      // contul nu mai există, deci un refresh de profil ar da 401.
      if (result.immediate) {
        await logout();
        return;
      }
      void queryClient.invalidateQueries({ queryKey: profileKeys.me() });
      toast.show(t('deleteAccountScheduled'));
    },
    onError: () => toast.show(t('deleteAccountScheduleFailed'), 'danger'),
  });

  const cancel = useMutation({
    mutationFn: () => api.delete<AppUserLike>('/account/delete-request'),
    onSuccess: (updated) => {
      if (updated && typeof updated === 'object' && 'id' in updated) setUser(updated as never);
      void queryClient.invalidateQueries({ queryKey: profileKeys.me() });
      toast.show(t('deleteAccountCancelled'));
    },
    onError: () => toast.show(t('deleteAccountCancelFailed'), 'danger'),
  });

  const scheduled = user?.deletionScheduledAt ? new Date(user.deletionScheduledAt) : null;

  if (scheduled) {
    const daysLeft = Math.floor((scheduled.getTime() - Date.now()) / 86_400_000);
    const date = new Intl.DateTimeFormat(i18n.language, {
      day: '2-digit',
      month: '2-digit',
      year: 'numeric',
    }).format(scheduled);

    return (
      <section className="mt-4 rounded-[12px] border border-destructive/40 bg-destructive/[0.08] p-4">
        <p className="flex items-center gap-2 font-bold text-destructive">
          <AlertTriangle size={20} />
          {t('deleteAccountPendingTitle')}
        </p>
        <p className="mt-2 whitespace-pre-line text-sm">
          {daysLeft > 0
            ? t('deleteAccountPendingIn', { date, days: daysLeft })
            : t('deleteAccountPendingToday', { date })}
        </p>
        <button
          onClick={() => cancel.mutate()}
          disabled={cancel.isPending}
          className="mt-3 rounded-[12px] bg-primary px-5 py-2.5 text-sm font-bold text-primary-foreground disabled:opacity-60"
        >
          {t('deleteAccountCancelAction')}
        </button>
      </section>
    );
  }

  return (
    <button
      onClick={() => {
        if (window.confirm(t('deleteAccountConfirmBody'))) request.mutate();
      }}
      disabled={request.isPending}
      className="mt-4 flex w-full items-center justify-center gap-2 rounded-[12px] border border-destructive/40 px-6 py-3.5 text-sm font-bold text-destructive hover:bg-destructive/10 disabled:opacity-60"
    >
      <Trash2 size={18} />
      {t('deleteAccountAction')}
    </button>
  );
}

/** Tipul întors de anularea ștergerii - profilul actualizat sau nimic. */
type AppUserLike = Record<string, unknown> | undefined;

function Row({
  icon: Icon,
  label,
  value,
  subtitle,
  to,
  onClick,
  danger = false,
}: {
  icon: typeof Pencil;
  label: string;
  /**
   * Valoarea curentă a setării, la DREAPTA etichetei: „Română", „Întunecat".
   * E `shrink-0` dinadins - o valoare scurtă nu trebuie ciuntită. Pentru un
   * text lung folosește `subtitle`, altfel valoarea refuză să se micșoreze,
   * împinge eticheta afară din rând și iese din card.
   */
  value?: string;
  /** Explicație pe al doilea rând, SUB etichetă. Poate fi lungă. */
  subtitle?: string;
  to?: string;
  onClick?: () => void;
  danger?: boolean;
}) {
  const className = cn(
    'flex w-full items-center gap-3 border-b border-border px-4 py-3.5 text-left last:border-b-0 hover:bg-muted',
    danger && 'text-destructive',
  );
  const content = (
    <>
      <Icon size={20} className={cn('shrink-0', !danger && 'text-muted-foreground')} />
      <span className="min-w-0 flex-1">
        <span className="block truncate">{label}</span>
        {subtitle && (
          <span className="block truncate text-xs text-muted-foreground">{subtitle}</span>
        )}
      </span>
      {value && <span className="shrink-0 truncate text-sm text-muted-foreground">{value}</span>}
      <ChevronRight size={16} className="shrink-0 text-muted-foreground" />
    </>
  );

  if (to) {
    return (
      <Link to={to} className={className}>
        {content}
      </Link>
    );
  }
  return (
    <button onClick={onClick} className={className}>
      {content}
    </button>
  );
}


/** Card pliabil, ca `_ExpandableCard` din Flutter: titlu, subtitlu, conținut. */
function Expandable({
  icon: Icon,
  title,
  subtitle,
  children,
}: {
  icon: typeof Pencil;
  title: string;
  subtitle: string;
  children: React.ReactNode;
}) {
  return (
    <details className="group">
      <summary className="flex cursor-pointer list-none items-start gap-3 px-4 py-3.5">
        <Icon size={20} className="mt-0.5 shrink-0 text-muted-foreground" />
        <span className="min-w-0 flex-1">
          <span className="block font-semibold">{title}</span>
          <span className="block text-xs leading-snug text-muted-foreground">{subtitle}</span>
        </span>
        <ChevronDown
          size={18}
          className="mt-0.5 shrink-0 text-muted-foreground transition group-open:rotate-180"
        />
      </summary>
      <div className="px-4 pb-4">{children}</div>
    </details>
  );
}

function PickerSheet({
  title,
  children,
  onClose,
}: {
  title: string;
  children: React.ReactNode;
  onClose: () => void;
}) {
  const { t } = useTranslation();
  return (
    <div className="fixed inset-0 z-50 flex items-end justify-center min-[560px]:items-center">
      <button
        aria-label={t('commonClose')}
        onClick={onClose}
        className="absolute inset-0 bg-black/50"
      />
      <div className="relative w-full max-w-[380px] rounded-t-[20px] bg-card p-4 min-[560px]:rounded-[20px]">
        <h2 className="mb-2 font-display text-lg font-bold">{title}</h2>
        {children}
      </div>
    </div>
  );
}

function PickerOption({
  selected,
  onClick,
  children,
}: {
  selected: boolean;
  onClick: () => void;
  children: React.ReactNode;
}) {
  return (
    <button
      onClick={onClick}
      className={cn(
        'flex w-full items-center justify-between rounded-[12px] px-4 py-3 text-left hover:bg-muted',
        selected && 'font-semibold text-accent',
      )}
    >
      {children}
      {selected && <ChevronRight size={16} />}
    </button>
  );
}

function Group({ title, children }: { title: string; children: React.ReactNode }) {
  return (
    <section className="mb-5">
      <h2 className="mb-2 text-xs font-semibold text-muted-foreground">{title}</h2>
      <div className="overflow-hidden rounded-[16px] border border-border bg-card">{children}</div>
    </section>
  );
}




