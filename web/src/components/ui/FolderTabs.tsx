import { useEffect, type KeyboardEvent, type ReactNode } from 'react';
import { useEdgeFade } from '@/lib/hooks/useEdgeFade';
import { cn } from '@/lib/utils/cn';

/**
 * Categoriile desenate ca file de dosar: fila activă e portocaliu plin, iar
 * panoul de dedesubt se stinge în negru sub ea, așa încât fila și conținutul
 * ei citesc ca o singură mapă deschisă - nu ca niște pastile care plutesc
 * deasupra unei liste fără legătură cu ele.
 *
 * Banda de file se derulează pe orizontală când categoriile nu încap pe
 * lățimea unui telefon, iar capătul se estompează DOAR în partea în care chiar
 * mai există ceva dincolo de margine: o estompare permanentă la ambele capete
 * ar sugera conținut ascuns și acolo unde toate filele sunt deja vizibile.
 */

export interface FolderTab<T extends string> {
  value: T;
  label: string;
  /** Contor opțional, desenat ca pastilă în filă (ex. numărul de necitite). */
  badge?: number;
}

interface FolderTabsProps<T extends string> {
  tabs: readonly FolderTab<T>[];
  value: T;
  onChange: (value: T) => void;
  /** Numele benzii pentru cititoarele de ecran (ex. „Filtre conversații"). */
  label: string;
  children: ReactNode;
  className?: string;
  /** Clase pentru interiorul dosarului, când are nevoie de alt padding. */
  panelClassName?: string;
}

export function FolderTabs<T extends string>({
  tabs,
  value,
  onChange,
  label,
  children,
  className,
  panelClassName,
}: FolderTabsProps<T>) {
  const { ref: stripRef, maskStyle } = useEdgeFade<HTMLDivElement>([tabs.length]);

  // Fila activă trebuie să fie vizibilă chiar dacă a fost aleasă din afara
  // benzii (dintr-o notificare, dintr-un link cu filtru în URL).
  useEffect(() => {
    const active = stripRef.current?.querySelector<HTMLElement>('[aria-selected="true"]');
    active?.scrollIntoView({
      inline: 'nearest',
      block: 'nearest',
      behavior: window.matchMedia('(prefers-reduced-motion: reduce)').matches ? 'auto' : 'smooth',
    });
  }, [value]);

  const move = (event: KeyboardEvent<HTMLDivElement>) => {
    const step = event.key === 'ArrowRight' ? 1 : event.key === 'ArrowLeft' ? -1 : 0;
    if (step === 0) return;
    event.preventDefault();
    const index = tabs.findIndex((tab) => tab.value === value);
    const next = tabs[(index + step + tabs.length) % tabs.length];
    if (next) onChange(next.value);
  };

  return (
    <div className={className}>
      <div
        ref={stripRef}
        role="tablist"
        aria-label={label}
        onKeyDown={move}
        // `-mb-px` lipește fila de panou: fără el, între marginea de sus a
        // panoului și baza filei rămâne o linie subțire de fundal.
        className="ss-noscrollbar -mb-px flex items-end gap-[3px] overflow-x-auto"
        style={maskStyle}
      >
        {tabs.map((tab) => {
          const selected = tab.value === value;
          return (
            <button
              key={tab.value}
              role="tab"
              type="button"
              aria-selected={selected}
              tabIndex={selected ? 0 : -1}
              onClick={() => onChange(tab.value)}
              className={cn(
                'flex shrink-0 items-center gap-1.5 rounded-t-[12px] px-[18px] pb-2.5 pt-2.5',
                'text-[13.5px] whitespace-nowrap transition',
                'focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-accent',
                selected
                  ? 'bg-accent font-bold text-accent-foreground'
                  : 'bg-muted font-medium text-muted-foreground hover:text-foreground',
              )}
            >
              {tab.label}
              {tab.badge !== undefined && tab.badge > 0 && (
                <span
                  className={cn(
                    'rounded-full px-1.5 text-[11px] font-bold tabular-nums',
                    selected ? 'bg-accent-foreground/20 text-accent-foreground' : 'bg-accent text-accent-foreground',
                  )}
                >
                  {tab.badge > 99 ? '99+' : tab.badge}
                </span>
              )}
            </button>
          );
        })}
      </div>

      {/*
        Interiorul dosarului. Fundalul e amestecat cu `color-mix` din tokenul
        de accent și cel de fundal, ca aceeași regulă să dea portocaliu peste
        negru în dark și un cald discret peste crem în light - fără o a doua
        paletă scrisă de mână pentru tema deschisă.
      */}
      <div
        role="tabpanel"
        className={cn('rounded-[0_14px_16px_16px] border-t-2 border-accent p-2.5', panelClassName)}
        style={{
          background:
            'linear-gradient(180deg,' +
            ' color-mix(in srgb, var(--ss-accent) 22%, var(--ss-background))' +
            ' 0%,' +
            ' color-mix(in srgb, var(--ss-accent) 6%, var(--ss-background))' +
            ' 78%)',
        }}
      >
        {children}
      </div>
    </div>
  );
}
