import { useLayoutEffect, useState, type ReactNode } from 'react';
import { cn } from '@/lib/utils/cn';

/** `kBookCardMaxWidth` din shared/widgets/book_grid_metrics.dart. */
export const BOOK_CARD_MAX_WIDTH = 220;

/** `crossAxisSpacing` / `mainAxisSpacing` din grilele de cărți. */
const COLUMN_GAP = 16;
const ROW_GAP = 20;

/**
 * Câte coloane intră într-o lățime dată.
 *
 * `ceil`, nu `floor`, fiindcă asta face `SliverGridDelegateWithMaxCrossAxisExtent`:
 * 220 e lățimea MAXIMĂ a unei cărți, nu cea minimă, deci grila mai bagă o
 * coloană și strânge cărțile, în loc să lase un gol. Diferența nu e teoretică -
 * pe un ecran de 1280 Flutter arată 5 coloane acolo unde un `auto-fill` de CSS
 * (care se poartă ca `floor`) arăta 4.
 *
 * Limita de jos, 2, e cerința de pe telefon: ~360-430dp trebuie să iasă exact
 * pe două coloane.
 */
export function bookGridColumns(width: number): number {
  if (!(width > 0)) return 2;
  const count = Math.ceil(width / (BOOK_CARD_MAX_WIDTH + COLUMN_GAP));
  return Math.min(8, Math.max(2, count));
}

/**
 * Măsoară un element și spune câte coloane are grila lui.
 *
 * Nodul vine printr-un ref de tip callback, ținut în stare: ecranele afișează
 * întâi un spinner, deci un `useRef` ar fi fost gol exact când efectul a rulat,
 * o singură dată, și n-ar mai fi măsurat niciodată.
 */
export function useBookGridColumns(): [(node: HTMLElement | null) => void, number] {
  const [node, setNode] = useState<HTMLElement | null>(null);
  const [columns, setColumns] = useState(2);

  useLayoutEffect(() => {
    if (!node) return;

    const measure = () => {
      // 0 înseamnă că nodul e ascuns (ex. un tab inactiv): păstrăm ultima
      // valoare bună în loc să cădem pe minimul de 2.
      if (node.clientWidth <= 0) return;
      setColumns(bookGridColumns(node.clientWidth));
    };

    measure();
    const observer = new ResizeObserver(measure);
    observer.observe(node);
    return () => observer.disconnect();
  }, [node]);

  return [setNode, columns];
}

/**
 * Grila de cărți, aceeași pe toate ecranele. Numărul de coloane se măsoară, nu
 * se descrie în praguri de media query: `auto-fill` din CSS rotunjește în jos,
 * iar Flutter în sus (vezi [bookGridColumns]).
 *
 * `columns` se dă din afară doar acolo unde apelantul are deja nevoie de număr
 * pentru altceva - pe Home, ca să știe după câte cărți să taie o secțiune
 * tematică. Altfel grila se măsoară singură.
 */
export function BookGrid({
  columns,
  className,
  children,
}: {
  columns?: number;
  className?: string;
  children: ReactNode;
}) {
  const [measureRef, measured] = useBookGridColumns();

  return (
    <div
      ref={columns === undefined ? measureRef : undefined}
      className={cn('grid', className)}
      style={{
        columnGap: COLUMN_GAP,
        rowGap: ROW_GAP,
        gridTemplateColumns: `repeat(${columns ?? measured}, minmax(0, 1fr))`,
      }}
    >
      {children}
    </div>
  );
}
