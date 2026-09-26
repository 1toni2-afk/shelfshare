import { useEffect, useRef, useState, type CSSProperties } from 'react';

/**
 * Estomparea capetelor unei benzi care se derulează pe orizontală.
 *
 * Estomparea spune „mai e ceva dincolo de margine", deci se desenează DOAR pe
 * partea unde chiar mai e: o bandă estompată la ambele capete când toate
 * filele încap pe ecran promite conținut inexistent, iar una care rămâne
 * estompată la stânga după ce ai derulat până la capăt spune o minciună în
 * cealaltă direcție.
 *
 * Întoarce `ref`-ul de pus pe elementul care derulează și stilul de mască.
 */

/** Lățimea estompării de la fiecare capăt. */
const FADE_PX = 28;

export function useEdgeFade<T extends HTMLElement>(
  /** Se resincronizează când se schimbă (ex. numărul de file). */
  deps: unknown[] = [],
) {
  const ref = useRef<T>(null);
  const [edges, setEdges] = useState({ start: false, end: false });

  useEffect(() => {
    const strip = ref.current;
    if (!strip) return;

    const sync = () => {
      const max = strip.scrollWidth - strip.clientWidth;
      // Toleranță de 2px: pe ecrane cu scalare fracționară `scrollLeft` nu
      // ajunge niciodată fix la 0 sau la maxim, iar estomparea ar rămâne
      // agățată într-un capăt.
      setEdges({ start: strip.scrollLeft > 2, end: strip.scrollLeft < max - 2 });
    };

    strip.addEventListener('scroll', sync, { passive: true });
    const observer = new ResizeObserver(sync);
    observer.observe(strip);
    sync();

    return () => {
      strip.removeEventListener('scroll', sync);
      observer.disconnect();
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, deps);

  const mask = `linear-gradient(90deg, ${[
    edges.start ? `transparent 0, #000 ${FADE_PX}px` : '#000 0',
    edges.end ? `#000 calc(100% - ${FADE_PX}px), transparent 100%` : '#000 100%',
  ].join(', ')})`;

  const maskStyle: CSSProperties = { maskImage: mask, WebkitMaskImage: mask };

  return { ref, maskStyle };
}
