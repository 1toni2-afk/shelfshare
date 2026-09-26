import { useEffect, useState } from 'react';
import { useTranslation } from 'react-i18next';
import {
  analyticsSupported,
  getAnalyticsConsent,
  setAnalyticsConsent,
  subscribeAnalyticsConsent,
} from '@/lib/analytics/analytics';
import { staticPageUrl } from '@/lib/staticPages';

/**
 * Bannerul de consimțământ pentru Google Analytics - același comportament ca
 * în Flutter: apare doar cât timp nu există o alegere, iar până la „Accept"
 * nu pleacă nicio cerere spre Google. Vezi lib/analytics/analytics.ts.
 *
 * Stă în afara routerului (main.tsx), deci linkul spre politica de
 * confidențialitate e un `<a>` simplu - oricum e o pagină HTML statică, nu o
 * rută a aplicației.
 */
export function AnalyticsConsentBanner() {
  const { t, i18n } = useTranslation();
  const [visible, setVisible] = useState(false);

  useEffect(() => {
    if (!analyticsSupported() || getAnalyticsConsent() !== null) return;
    // O clipă după primul cadru, ca în Flutter: bannerul nu concurează cu
    // încărcarea paginii pentru atenție.
    const timer = window.setTimeout(() => setVisible(true), 400);
    const unsubscribe = subscribeAnalyticsConsent(() => {
      if (getAnalyticsConsent() !== null) setVisible(false);
    });
    return () => {
      window.clearTimeout(timer);
      unsubscribe();
    };
  }, []);

  if (!visible) return null;

  return (
    <div
      role="dialog"
      aria-live="polite"
      aria-label={t('settingsAnalyticsTitle')}
      className="fixed inset-x-3 bottom-3 z-[60] mx-auto max-w-[560px] rounded-[16px] border border-border bg-card p-4 text-sm shadow-lg sm:bottom-5"
    >
      <p className="leading-relaxed text-foreground">
        {t('analyticsBannerText')}{' '}
        <a
          href={staticPageUrl('privacy', i18n.language)}
          className="font-semibold text-accent underline-offset-2 hover:underline"
        >
          {t('analyticsBannerDetails')}
        </a>
        .
      </p>
      <div className="mt-3 flex justify-end gap-2">
        <button
          type="button"
          onClick={() => setAnalyticsConsent(false)}
          className="rounded-full px-4 py-2 text-sm font-semibold text-muted-foreground hover:bg-muted"
        >
          {t('analyticsBannerReject')}
        </button>
        <button
          type="button"
          onClick={() => setAnalyticsConsent(true)}
          className="rounded-full bg-primary px-4 py-2 text-sm font-bold text-primary-foreground"
        >
          {t('analyticsBannerAccept')}
        </button>
      </div>
    </div>
  );
}
