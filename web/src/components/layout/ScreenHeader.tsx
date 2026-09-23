import { createContext, use, type ReactNode } from 'react';
import { useTranslation } from 'react-i18next';
import { createPortal } from 'react-dom';
import { Link, useNavigate } from 'react-router-dom';
import { ArrowLeft } from 'lucide-react';
import { cn } from '@/lib/utils/cn';
import { useEdgeFade } from '@/lib/hooks/useEdgeFade';

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
/** Colțul din dreapta al barei de brand, care există doar pe telefon. */
const BrandSlotContext = createContext<HTMLElement | null>(null);

export function ScreenHeaderSlot({
  slot,
  brandSlot,
  children,
}: {
  slot: HTMLElement | null;
  brandSlot: HTMLElement | null;
  children: ReactNode;
}) {
  return (
    <SlotContext value={slot}>
      <BrandSlotContext value={brandSlot}>{children}</BrandSlotContext>
    </SlotContext>
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
  actionsInBrandBar = false,
}: {
  title?: ReactNode;
  actions?: ReactNode;
  /** Rândul de sub titlu, pentru tab-uri (`bottom:` din AppBar). */
  bottom?: ReactNode;
  /** Săgeata de back: `true` = un pas înapoi, string = rută fixă. */
  back?: boolean | string;
  /**
   * Pe telefon, acțiunile urcă în bara de brand, lângă logo. Pentru titlurile
   * lungi (salutul de pe Home): pe lățimea unui telefon titlul centrat nu mai
   * lasă loc iconițelor, coloana lor se strângea la zero și ele ajungeau peste
   * text. Așa stau și în Flutter, în capul ecranului.
   */
  actionsInBrandBar?: boolean;
}) {
  const { t } = useTranslation();
  const slot = use(SlotContext);
  const brandSlot = use(BrandSlotContext);
  const navigate = useNavigate();
  if (!slot) return null;

  return createPortal(
    <>
      {actionsInBrandBar && actions && brandSlot && createPortal(actions, brandSlot)}
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
      <div className="grid h-16 grid-cols-[1fr_minmax(0,auto)_1fr] items-center gap-2 px-4">
        <div className="flex min-w-0 items-center justify-start">
          {/*
            Săgeata se vede pe ORICE lățime.

            Era ascunsă sub pragul de sidebar, iar alături stătea un slot gol de
            48px - amândouă pentru că butonul de meniu plutea fix în colțul
            ăsta și ar fi acoperit-o. De când butonul stă în bara de brand din
            AppShell, colțul e liber: ascunderea lăsa ecranele de pe telefon
            fără niciun drum înapoi în interfață, iar slotul gol ar fi împins
            acum săgeata cu 48px spre dreapta, degeaba.
          */}
          {back && (
            <button
              onClick={() => (typeof back === 'string' ? void navigate(back) : void navigate(-1))}
              aria-label={t('commonBack')}
              title={t('commonBack')}
              className="shrink-0 rounded-full p-2.5 hover:bg-muted"
            >
              <ArrowLeft size={22} />
            </button>
          )}
        </div>

        <h1 className="truncate text-center font-display text-lg font-bold">{title}</h1>

        <div
          className={cn(
            'flex min-w-0 items-center justify-end',
            // Bara de brand dispare de la pragul de sidebar în sus, deci acolo
            // acțiunile se întorc în bara ecranului.
            actionsInBrandBar && 'hidden min-[900px]:flex',
          )}
        >
          {actions}
        </div>
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

/**
 * Rândul de tab-uri de sub titlu (`bottom: TabBar(...)`). Tab-urile sunt
 * butoane, nu linkuri: în Flutter starea lor trăiește în `TabController`, nu în
 * rută, iar un refresh cade înapoi pe primul tab exact la fel.
 */
export function HeaderTabs<T extends string>({
  tabs,
  value,
  onChange,
  scrollable = false,
}: {
  tabs: Array<{ value: T; label: string }>;
  value: T;
  onChange: (value: T) => void;
  scrollable?: boolean;
}) {
  // Estomparea are sens doar când banda chiar se derulează; pe filele întinse
  // pe toată lățimea n-are ce ascunde.
  const { ref, maskStyle } = useEdgeFade<HTMLDivElement>([tabs.length]);

  return (
    <div
      ref={scrollable ? ref : undefined}
      style={scrollable ? maskStyle : undefined}
      className={cn(
        'flex border-b border-border px-2',
        scrollable ? 'ss-noscrollbar overflow-x-auto' : 'justify-stretch',
      )}
    >
      {tabs.map((tab) => (
        <button
          key={tab.value}
          onClick={() => onChange(tab.value)}
          className={cn(
            'shrink-0 whitespace-nowrap border-b-2 px-4 py-3 text-sm font-semibold transition',
            scrollable ? '' : 'flex-1',
            tab.value === value
              ? 'border-accent text-accent'
              : 'border-transparent text-muted-foreground hover:text-foreground',
          )}
        >
          {tab.label}
        </button>
      ))}
    </div>
  );
}
