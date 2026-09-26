import { createContext, use, useLayoutEffect, type ReactNode } from 'react';
import { useTranslation } from 'react-i18next';
import { createPortal } from 'react-dom';
import { Link, useLocation, useNavigate } from 'react-router-dom';
import { ArrowLeft } from 'lucide-react';
import { cn } from '@/lib/utils/cn';

/**
 * Unde își desenează ecranul curent bara de sus. Nodul e ținut de `AppShell`.
 *
 * Un portal, nu o stare partajată: bara e conținut al ECRANULUI (în Flutter
 * fiecare ecran își are propriul `Scaffold` cu `AppBar`-ul lui), doar că e
 * desenată deasupra zonei care derulează. Cu stare ar fi trebuit scrisă dintr-un
 * efect, iar un titlu construit din JSX la fiecare randare ar fi pornit o buclă
 * infinită de „setState în efect fără dependențe stabile".
 */
const SlotContext = createContext<HTMLElement | null>(null);

/**
 * Bara de sus de pe telefon (cea cu meniul și logo-ul, din AppShell): trei
 * locuri în care ecranul își poate muta săgeata, titlul și acțiunile, plus
 * funcția prin care îi spune shell-ului ce a ocupat - ca acesta să-și ascundă
 * butonul de meniu și numele ShelfShare.
 */
export interface MobileBar {
  left: HTMLElement | null;
  title: HTMLElement | null;
  actions: HTMLElement | null;
  setUsage: (usage: MobileBarUsage | null) => void;
}

export interface MobileBarUsage {
  back: boolean;
  title: boolean;
}

const MobileBarContext = createContext<MobileBar | null>(null);

/**
 * Ce rută stă la fiecare poziție din istoric (`history.state.idx` e pus de
 * React Router). O săgeată cu rută fixă se uită aici: dacă pasul din spate e
 * chiar ruta cerută, face `navigate(-1)` în loc să împingă o intrare nouă -
 * altfel „Pregătire schimb" → „Schimburile mele" → back ducea iar la pregătire,
 * la nesfârșit.
 */
const pathAtIndex = new Map<number, string>();

function historyIndex(): number | null {
  const idx = (window.history.state as { idx?: unknown } | null)?.idx;
  return typeof idx === 'number' ? idx : null;
}

function useTrackHistoryPaths() {
  const location = useLocation();
  useLayoutEffect(() => {
    const idx = historyIndex();
    if (idx !== null) pathAtIndex.set(idx, location.pathname);
  }, [location]);
}

export function ScreenHeaderSlot({
  slot,
  mobileBar,
  children,
}: {
  slot: HTMLElement | null;
  mobileBar: MobileBar;
  children: ReactNode;
}) {
  useTrackHistoryPaths();
  return (
    <SlotContext value={slot}>
      <MobileBarContext value={mobileBar}>{children}</MobileBarContext>
    </SlotContext>
  );
}

/**
 * Săgeata de back: portocalie, pe fundalul temei, cu un contur tot portocaliu -
 * aceeași pe telefon și pe desktop.
 */
export function BackButton({ to }: { to: true | string }) {
  const { t } = useTranslation();
  const navigate = useNavigate();
  return (
    <button
      onClick={() => {
        if (to === true) return void navigate(-1);
        const idx = historyIndex();
        // Pasul din spate e chiar ruta fixă: înapoi în istoric, nu înainte.
        if (idx !== null && idx > 0 && pathAtIndex.get(idx - 1) === to) return void navigate(-1);
        // Altfel înlocuiește intrarea curentă, ca back-ul de pe ruta fixă să nu
        // ne mai aducă aici.
        void navigate(to, { replace: true });
      }}
      aria-label={t('commonBack')}
      title={t('commonBack')}
      className="shrink-0 rounded-full border-[1.5px] border-accent bg-background p-2 text-accent transition hover:bg-accent/10"
    >
      <ArrowLeft size={20} />
    </button>
  );
}

/**
 * Bara de sus a unui ecran: săgeată de back (opțional), titlu centrat, acțiuni
 * în dreapta și un rând suplimentar dedesubt (tab-uri). Port al `AppBar`-ului
 * per ecran din Flutter, unde `centerTitle: true` vine din temă.
 *
 * Se randează oriunde în interiorul ecranului; nu ocupă loc acolo unde e scrisă.
 * Un ecran care n-o folosește lasă bara complet goală, deci înaltă de 0 - nu
 * rămâne o fâșie albă în capul paginii.
 */
export function ScreenHeader({
  title,
  actions,
  bottom,
  back,
  keepBrandOnMobile = false,
}: {
  title?: ReactNode;
  actions?: ReactNode;
  /** Rândul de sub titlu, pentru tab-uri (`bottom:` din AppBar). */
  bottom?: ReactNode;
  /** Săgeata de back: `true` = un pas înapoi, string = rută fixă. */
  back?: boolean | string;
  /**
   * Doar pentru Home. Pe telefon, bara de sus păstrează meniul, logo-ul și
   * numele ShelfShare, iar titlul (salutul) rămâne pe rândul lui, dedesubt.
   * Doar acțiunile urcă lângă logo: pe lățimea unui telefon, salutul centrat
   * nu le mai lăsa loc și ajungeau peste text.
   *
   * Pe restul ecranelor, pe telefon, săgeata și titlul iau locul butonului
   * de meniu și al numelui ShelfShare. Altfel numele și titlul ecranului
   * ar ocupa două bare una sub alta, doar cu titluri.
   */
  keepBrandOnMobile?: boolean;
}) {
  const slot = use(SlotContext);
  const mobileBar = use(MobileBarContext);
  const setUsage = mobileBar?.setUsage;
  const usesBack = !keepBrandOnMobile && !!back;
  const usesTitle = !keepBrandOnMobile && title != null && title !== '';

  // Doar booleeni în dependențe, deci efectul nu rulează la fiecare randare
  // (titlul e JSX nou de fiecare dată). Layout effect: shell-ul își ascunde
  // meniul și numele înainte de primul cadru, fără o clipire cu ambele.
  useLayoutEffect(() => {
    if (!setUsage) return;
    setUsage({ back: usesBack, title: usesTitle });
    return () => setUsage(null);
  }, [setUsage, usesBack, usesTitle]);

  if (!slot) return null;

  return createPortal(
    <>
      {mobileBar && !keepBrandOnMobile && (
        <>
          {back && mobileBar.left && createPortal(<BackButton to={back} />, mobileBar.left)}
          {usesTitle &&
            mobileBar.title &&
            createPortal(
              <h1 className="truncate font-display text-xl font-bold">{title}</h1>,
              mobileBar.title,
            )}
        </>
      )}
      {actions && mobileBar?.actions && createPortal(actions, mobileBar.actions)}
      {/*
        Grilă cu trei coloane, nu un rând flex.

        Cu flex, titlul era centrat pe spațiul RĂMAS după slotul din stânga și
        acțiunile din dreapta, adică pe ecran apărea centrat doar din întâmplare,
        când cele două aveau exact aceeași lățime. La Notificări și la Activitate
        recentă nu există nicio acțiune, deci titlul stătea mutat cu ~28px spre
        dreapta - cât jumătate din slotul rezervat butonului de meniu.

        Cu `1fr` pe ambele margini, coloanele laterale sunt egale prin
        construcție, deci mijlocul e mijlocul ecranului, indiferent câte
        iconițe sunt într-o parte. Contragreutatea scrisă de mână nu mai e
        necesară.
      */}
      {/*
        Pe telefon rândul acesta există doar pe Home (`keepBrandOnMobile`),
        pentru salut. Pe celelalte ecrane tot ce era în el a urcat în bara
        de sus, iar un rând gol ar fi furat 64px din ecran.
      */}
      <div
        className={cn(
          'grid-cols-[1fr_minmax(0,auto)_1fr] items-center gap-2 px-4 min-[900px]:h-16',
          // Pe telefon salutul stă imediat sub bara cu logo-ul: un rând fix de
          // 64px lăsa o fâșie goală deasupra și dedesubtul lui.
          keepBrandOnMobile ? 'grid pb-2 pt-0.5 min-[900px]:py-0' : 'hidden min-[900px]:grid',
        )}
      >
        <div className="flex min-w-0 items-center justify-start">
          {back && <BackButton to={back} />}
        </div>

        <h1 className="truncate text-center font-display text-xl font-bold">{title}</h1>

        {/* Pe telefon acțiunile stau în bara de sus; aici doar de la pragul
            de sidebar în sus, unde bara aceea nu există. */}
        <div className="hidden min-w-0 items-center justify-end min-[900px]:flex">{actions}</div>
      </div>
      {bottom}
    </>,
    slot,
  );
}

/** Un buton de iconiță din bara de sus - `IconButton` din `AppBar.actions`. */
export function HeaderAction({
  to,
  onClick,
  label,
  children,
  badge,
  disabled = false,
}: {
  to?: string;
  onClick?: () => void;
  label: string;
  children: ReactNode;
  badge?: number;
  disabled?: boolean;
}) {
  const className = cn(
    'relative shrink-0 rounded-full p-2.5 hover:bg-muted',
    disabled && 'opacity-40',
  );
  const content = (
    <>
      {children}
      {badge != null && badge > 0 && (
        <span className="absolute right-0.5 top-0.5 flex min-w-[18px] items-center justify-center rounded-full bg-destructive px-1 text-[10px] font-bold leading-[18px] text-white">
          {badge > 99 ? '99+' : badge}
        </span>
      )}
    </>
  );

  if (to) {
    return (
      <Link to={to} aria-label={label} title={label} className={className}>
        {content}
      </Link>
    );
  }
  return (
    <button
      onClick={onClick}
      disabled={disabled}
      aria-label={label}
      title={label}
      className={className}
    >
      {content}
    </button>
  );
}
