import { useState } from 'react';
import { Link, NavLink, Outlet } from 'react-router-dom';
import { useTranslation } from 'react-i18next';
import { BookOpen } from 'lucide-react';
import { cn } from '@/lib/utils/cn';
import { ScreenHeaderSlot } from './ScreenHeader';

/**
 * Shell-ul pentru vizitatorul NEAUTENTIFICAT, pe rutele publice (pagina de
 * prezentare, catalogul, o carte, un profil, un grup).
 *
 * Există fiindcă `AppShell` presupune un user: bara laterală citește badge-uri
 * de mesaje/notificări, scurtături personale și profilul din subsol - toate
 * fără sens pentru cineva care n-are cont. Randat pentru anonimi, ar fi produs
 * o coloană de meniu care duce numai în /login.
 *
 * Navigarea e din `<Link>`-uri, care emit `<a href>` reale în HTML: un crawler
 * care nu execută JavaScript trebuie să poată urma legăturile dintre paginile
 * publice. Vezi `PUBLIC_NAV` - aceleași adrese apar și în sitemap-ul generat
 * de scripts/beta-server.js.
 */
const PUBLIC_NAV: Array<{ to: string; labelKey: string; fallback: string }> = [
  { to: '/browse', labelKey: 'publicNavBrowse', fallback: 'Catalog' },
  { to: '/leaderboard', labelKey: 'publicNavLeaderboard', fallback: 'Clasament' },
  { to: '/global-stats', labelKey: 'publicNavStats', fallback: 'Statistici' },
];

/**
 * Paginile plain-HTML servite de beta-server.js (nu sunt rute ale aplicației).
 * Deci `<a>` obișnuit, nu `<Link>`: un `<Link>` le-ar rezolva prin routerul din
 * browser, care n-are rutele astea și ar afișa „pagină inexistentă".
 */
const FOOTER_LINKS: Array<{ href: string; labelKey: string; fallback: string }> = [
  { href: '/help-center', labelKey: 'settingsHelpCenter', fallback: 'Întrebări frecvente' },
  { href: '/safety-center', labelKey: 'settingsSafetyCenter', fallback: 'Centrul de siguranță' },
  { href: '/about-dev', labelKey: 'settingsAboutDev', fallback: 'Despre dezvoltator' },
  { href: '/privacy', labelKey: 'settingsPrivacy', fallback: 'Confidențialitate' },
  { href: '/terms', labelKey: 'settingsTerms', fallback: 'Termeni și condiții' },
];

export function PublicShell() {
  const { t } = useTranslation();
  /*
    Nodul în care ecranul curent își desenează bara de sus, exact ca în
    `AppShell`.

    Nu e un detaliu de stil: `ScreenHeader` se randează printr-un portal și
    întoarce `null` când nu găsește niciun slot. Fără el, ecranele publice își
    pierdeau tăcut bara - iar Clasamentul și Statisticile își pun FILELE acolo
    (`bottom`), deci un vizitator fără cont ar fi rămas blocat pe prima filă,
    fără nicio cale de a schimba, în timp ce un user logat le vedea normal.
  */
  const [headerSlot, setHeaderSlot] = useState<HTMLElement | null>(null);

  return (
    <div className="flex min-h-dvh flex-col bg-background">
      <header className="sticky top-0 z-30 border-b border-border bg-card/95 backdrop-blur">
        <div className="mx-auto flex w-full max-w-[1100px] flex-wrap items-center gap-x-5 gap-y-3 px-5 py-3 min-[900px]:px-8">
          <Link to="/" className="flex items-center gap-2.5">
            <span className="rounded-lg bg-accent/15 p-1.5 text-accent">
              <BookOpen size={20} />
            </span>
            <span className="font-display text-base font-bold">ShelfShare</span>
          </Link>

          <nav className="flex items-center gap-1">
            {PUBLIC_NAV.map((item) => (
              <NavLink
                key={item.to}
                to={item.to}
                className={({ isActive }) =>
                  cn(
                    'rounded-full px-3 py-1.5 text-sm transition',
                    isActive
                      ? 'bg-accent/15 font-semibold text-accent'
                      : 'text-muted-foreground hover:bg-muted hover:text-foreground',
                  )
                }
              >
                {t(item.labelKey, item.fallback)}
              </NavLink>
            ))}
          </nav>

          <div className="ml-auto flex items-center gap-2">
            <Link
              to="/login"
              className="rounded-full px-3 py-1.5 text-sm font-semibold text-foreground hover:bg-muted"
            >
              {t('authLoginSubmit', 'Conectare')}
            </Link>
            <Link
              to="/register"
              className="rounded-full bg-primary px-4 py-1.5 text-sm font-bold text-primary-foreground"
            >
              {t('authRegisterSubmit', 'Creează cont')}
            </Link>
          </div>
        </div>
      </header>

      {/* Goală până o umple ecranul, deci fără înălțime proprie: o pagină care
          nu-și pune bară nu rămâne cu o fâșie goală sub antet. */}
      <div ref={setHeaderSlot} className="sticky top-[57px] z-20 flex flex-col bg-background" />

      <main className="min-w-0 flex-1">
        <ScreenHeaderSlot slot={headerSlot}>
          <Outlet />
        </ScreenHeaderSlot>
      </main>

      <footer className="mt-12 border-t border-border bg-card">
        <div className="mx-auto w-full max-w-[1100px] px-5 py-8 min-[900px]:px-8">
          <nav className="flex flex-wrap gap-x-6 gap-y-2">
            {FOOTER_LINKS.map((item) => (
              <a
                key={item.href}
                href={item.href}
                className="text-sm text-muted-foreground hover:text-foreground"
              >
                {t(item.labelKey, item.fallback)}
              </a>
            ))}
          </nav>
          <p className="mt-5 text-xs text-muted-foreground">
            ShelfShare - comunitatea de cititori din România care își dau cărțile mai departe.
          </p>
        </div>
      </footer>
    </div>
  );
}
