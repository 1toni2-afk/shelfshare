import { useState } from 'react';
import { useQuery } from '@tanstack/react-query';
import { useNavigate } from 'react-router-dom';
import { useTranslation } from 'react-i18next';
import { ScreenHeader } from '@/components/layout/ScreenHeader';
import {
  ArrowRight,
  BookOpen,
  Check,
  Circle,
  Heart,
  LayoutGrid,
  Lock,
  Repeat,
  Sparkles,
} from 'lucide-react';
import type { LucideIcon } from 'lucide-react';
import { profileKeys, profileRepository } from '@/features/profile/profileRepository';
import { Button, ErrorNotice, Spinner } from '@/components/ui';
import { useAuth } from '@/features/auth/AuthProvider';
import { useCompleteOnboardingTodo } from '@/features/home/onboardingTodo';
import { toNumber } from '@/types/models';

/**
 * Ecranele de CONȚINUT: „Despre aplicație", „Plan de dezvoltare", turul rapid
 * și analizele de vânzător. Stau împreună fiindcă sunt toate variații pe
 * aceeași structură - o listă de secțiuni titlu + text din .arb - și separate
 * ar fi patru fișiere de câte 40 de linii care se repetă.
 */

function Section({ title, body }: { title: string; body: string }) {
  return (
    <section className="mb-5 rounded-[16px] border border-border bg-card p-5">
      <h2 className="mb-2 font-display text-lg font-bold">{title}</h2>
      {/* `whitespace-pre-line`: textele din .arb au liste cu „•" pe rânduri
          separate, iar fără asta ar curge toate într-un singur paragraf. */}
      <p className="whitespace-pre-line leading-relaxed text-muted-foreground">{body}</p>
    </section>
  );
}

/**
 * Cate XP intra intr-un nivel. Backendul il trimite in `/profile/gamification`
 * (`xpPerLevel`), dar ecranul „Despre aplicatie" nu incarca profilul - la fel
 * ca in Flutter, unde `about_app_screen.dart` foloseste `?? 100`.
 */
const XP_PER_LEVEL = 100;

const ABOUT_SECTIONS = [
  'HomeSections',
  'Shelves',
  'Exchanges',
  'Chat',
  'Trust',
  'Badges',
  'Sustainability',
  'AccountDeletion',
] as const;

export function AboutAppScreen() {
  const { t } = useTranslation();

  return (
    <div className="mx-auto w-full max-w-[680px] px-5 pb-16 pt-4 min-[900px]:px-8">
      <ScreenHeader title={t('aboutAppTitle')} back="/settings" />
      <p className="mb-6 whitespace-pre-line text-muted-foreground">{t('aboutAppIntro')}</p>

      {ABOUT_SECTIONS.map((key) => (
        <Section key={key} title={t(`aboutApp${key}Title`)} body={t(`aboutApp${key}Body`)} />
      ))}

      <section className="rounded-[16px] border border-border bg-card p-5">
        <h2 className="mb-2 font-display text-lg font-bold">{t('aboutAppXpTitle')}</h2>
        <p className="mb-3 text-muted-foreground">
          {t('gamificationXpIntro', { n: XP_PER_LEVEL })}
        </p>
        <ul className="flex flex-col gap-1.5 text-muted-foreground">
          {['BookListed', 'ExchangeCompleted', 'SaleCompleted', 'ReviewWritten'].map((key) => (
            <li key={key} className="flex gap-2">
              <Circle size={6} className="mt-2 shrink-0 fill-accent text-accent" />
              {t(`gamificationXp${key}`)}
            </li>
          ))}
        </ul>
        <p className="mt-3 text-sm text-muted-foreground">{t('gamificationNoMaxLevel')}</p>
      </section>
    </div>
  );
}

const ROADMAP_ITEMS = [
  { key: 'GoodreadsImport', live: true },
  { key: 'UpcomingReleases', live: false },
  { key: 'AiRecommendations', live: false },
  { key: 'BookstoreIntegrations', live: false },
  { key: 'Giveaway', live: false },
] as const;

export function RoadmapScreen() {
  const { t } = useTranslation();

  return (
    <div className="mx-auto w-full max-w-[680px] px-5 pb-16 pt-4 min-[900px]:px-8">
      <ScreenHeader title={t('profileRoadmap')} back="/settings" />
      <p className="mb-6 text-muted-foreground">{t('roadmapSubtitle')}</p>

      {ROADMAP_ITEMS.map((item) => (
        <section key={item.key} className="mb-4 rounded-[16px] border border-border bg-card p-5">
          <div className="mb-2 flex flex-wrap items-center gap-2">
            <h2 className="font-display text-lg font-bold">{t(`roadmap${item.key}Title`)}</h2>
            <span
              className={
                'rounded-full border px-2.5 py-0.5 text-[11px] font-medium ' +
                (item.live ? 'border-success/40 text-success' : 'border-border text-muted-foreground')
              }
            >
              {t(item.live ? 'roadmapStatusLive' : 'roadmapStatusPlanned')}
            </span>
          </div>
          <p className="whitespace-pre-line leading-relaxed text-muted-foreground">
            {t(`roadmap${item.key}Body`)}
          </p>
        </section>
      ))}
    </div>
  );
}

/**
 * Pașii turului, fiecare cu semnul lui.
 *
 * Nu sunt capturi de ecran: o captură îmbătrânește la prima schimbare de
 * interfață și trebuie refăcută în patru limbi. Semnul e același pe care omul
 * îl vede în aplicație pentru acel lucru, deci face legătura fără să ceară
 * întreținere. Dacă vrem totuși capturi, aici se schimbă.
 */
const TUTORIAL_STEPS = [
  { key: 'Shelf', icon: BookOpen },
  { key: 'Match', icon: Sparkles },
  { key: 'Swap', icon: Repeat },
  { key: 'Wishlist', icon: Heart },
  { key: 'Shortcuts', icon: LayoutGrid },
] as const satisfies readonly { key: string; icon: LucideIcon }[];

export function TutorialScreen() {
  const { t } = useTranslation();
  const navigate = useNavigate();
  const completeTodo = useCompleteOnboardingTodo();
  const [step, setStep] = useState(0);

  const isLast = step === TUTORIAL_STEPS.length - 1;
  const current = TUTORIAL_STEPS[step];
  const StepIcon = current.icon;

  /**
   * Pasul „vezi turul" se bifează doar dacă omul a ajuns la capăt - „sari
   * peste" nu e un tur văzut, iar lista ar minți dacă l-ar tăia oricum.
   */
  function finish() {
    completeTodo('tutorial');
    void navigate('/');
  }

  return (
    <div className="mx-auto flex min-h-[80dvh] w-full max-w-[520px] flex-col justify-center px-5 py-8">
      <ScreenHeader
        title={t('tutorialTitle')}
        back
        actions={
          <button
            onClick={() => void navigate('/')}
            className="shrink-0 rounded-[12px] px-3 py-2 text-sm font-semibold text-accent hover:bg-muted"
          >
            {t('tutorialSkip')}
          </button>
        }
      />
      <div className="mb-6 flex justify-center gap-1.5">
        {TUTORIAL_STEPS.map((item, index) => (
          <span
            key={item.key}
            className={
              'h-1.5 rounded-full transition-all ' +
              (index === step ? 'w-6 bg-accent' : 'w-1.5 bg-border')
            }
          />
        ))}
      </div>

      {/* Semnul pasului, pe fundalul cald al aplicației: turul avea doar text,
          iar cinci ecrane la rând de text arată la fel și nu se ține minte. */}
      <div
        className="mx-auto mb-7 flex aspect-[4/3] w-full max-w-[280px] items-center justify-center rounded-[20px] border border-accent/25"
        style={{
          background:
            'linear-gradient(160deg,' +
            ' color-mix(in srgb, var(--ss-accent) 20%, var(--ss-background)),' +
            ' color-mix(in srgb, var(--ss-accent) 5%, var(--ss-background)))',
        }}
      >
        <StepIcon size={72} strokeWidth={1.25} className="text-accent" />
      </div>

      <h1 className="mb-3 text-center font-display text-2xl font-bold">
        {t(`tutorial${current.key}Title`)}
      </h1>
      <p className="mb-8 text-center leading-relaxed text-muted-foreground">
        {t(`tutorial${current.key}Body`)}
      </p>

      {/* Un singur „sari peste", cel din antet. Al doilea, sub „Mai departe",
          punea ieșirea exact sub butonul de continuare - două acțiuni opuse
          lipite una de alta. */}
      <Button
        fullWidth
        onClick={() => (isLast ? finish() : setStep((current) => current + 1))}
      >
        {t(isLast ? 'tutorialDone' : 'tutorialNext')}
        {!isLast && <ArrowRight size={18} />}
      </Button>
    </div>
  );
}

export function SellerAnalyticsScreen() {
  const { t } = useTranslation();
  const { user } = useAuth();

  const analytics = useQuery({
    queryKey: profileKeys.sellerAnalytics(),
    queryFn: ({ signal }) => profileRepository.sellerAnalytics(signal),
    // Backendul întoarce 403 pentru cine n-are dreptul; `canAccessAdvancedStats`
    // vine deja calculat pe profil, deci nu mai cerem degeaba.
    enabled: user?.canAccessAdvancedStats === true,
  });

  if (user && !user.canAccessAdvancedStats) {
    return (
      <div className="mx-auto w-full max-w-[560px] px-5 pb-16 pt-4 min-[900px]:px-8">
        <ScreenHeader title={t('premiumAnalyticsTitle')} back="/settings" />
        <div className="flex flex-col items-center gap-3 rounded-[16px] border border-border bg-card p-8 text-center">
          <Lock size={28} className="text-muted-foreground" />
          <p className="text-muted-foreground">{t('premiumAnalyticsLocked')}</p>
        </div>
      </div>
    );
  }

  if (analytics.isPending) {
    return (
      <div className="flex min-h-dvh items-center justify-center text-accent">
        <Spinner size={28} />
      </div>
    );
  }

  if (analytics.isError) {
    return (
      <div className="mx-auto max-w-2xl p-6">
        <ErrorNotice
          message={t('premiumAnalyticsLoadError')}
          onRetry={() => void analytics.refetch()}
        />
      </div>
    );
  }

  const data = analytics.data as Record<string, unknown>;
  const metrics = [
    { labelKey: 'premiumAnalyticsTotalListings', value: data.totalListings },
    { labelKey: 'premiumAnalyticsTotalViews', value: data.totalViews },
    { labelKey: 'premiumAnalyticsOffersReceived', value: data.offersReceived },
    { labelKey: 'premiumAnalyticsConversionRate', value: data.conversionRate },
  ];

  return (
    <div className="mx-auto w-full max-w-[680px] px-5 pb-16 pt-4 min-[900px]:px-8">
      <ScreenHeader title={t('premiumAnalyticsTitle')} back="/settings" />

      <div className="mb-6 grid grid-cols-2 gap-3">
        {metrics.map((metric) => (
          <div key={metric.labelKey} className="rounded-[16px] border border-border bg-card p-4">
            <p className="font-display text-2xl font-bold">
              {/* Câmpurile lipsă se afișează ca „—", nu ca „undefined": un
                  endpoint care adaugă sau scoate o metrică nu trebuie să
                  strice ecranul. */}
              {metric.value === undefined || metric.value === null ? '—' : String(metric.value)}
            </p>
            <p className="text-xs text-muted-foreground">{t(metric.labelKey)}</p>
          </div>
        ))}
      </div>

      {typeof data.revenue === 'number' || typeof data.revenue === 'string' ? (
        <div className="mb-6 rounded-[16px] border border-border bg-card p-4">
          <p className="font-display text-2xl font-bold text-accent">
            {t('priceLei', { amount: toNumber(data.revenue as string) ?? 0 })}
          </p>
          <p className="text-xs text-muted-foreground">{t('premiumAnalyticsRevenue')}</p>
        </div>
      ) : null}

      {Array.isArray(data.topListings) && data.topListings.length > 0 && (
        <section>
          <h2 className="mb-3 font-display text-lg font-bold">
            {t('premiumAnalyticsTopListings')}
          </h2>
          <ul className="flex flex-col gap-2">
            {(data.topListings as Array<Record<string, unknown>>).map((listing, index) => (
              <li
                key={String(listing.id ?? index)}
                className="flex items-center gap-3 rounded-[16px] border border-border bg-card p-3"
              >
                <Check size={16} className="shrink-0 text-success" />
                <span className="min-w-0 flex-1 truncate">{String(listing.title ?? '')}</span>
                <span className="shrink-0 text-sm text-muted-foreground">
                  {String(listing.viewCount ?? 0)}
                </span>
              </li>
            ))}
          </ul>
        </section>
      )}
    </div>
  );
}
