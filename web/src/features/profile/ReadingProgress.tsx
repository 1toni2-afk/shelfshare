import type { CurrentlyReading } from '@/types/models';

/** Fracție 0..1 din progresul la citit; `null` când nu știm câte pagini are cartea. */
export function readingFraction(current: CurrentlyReading): number | null {
  if (!current.totalPages || current.totalPages <= 0) return null;
  return Math.min(1, Math.max(0, current.currentPage / current.totalPages));
}

/** Bară groasă cu procentul alături - pentru „Citesc acum" și provocarea anuală. */
export function ProgressBar({ fraction }: { fraction: number }) {
  const percent = Math.round(fraction * 100);
  return (
    <div className="flex items-center gap-3">
      <div className="h-2.5 flex-1 overflow-hidden rounded-full bg-muted">
        <div className="h-full rounded-full bg-accent" style={{ width: `${percent}%` }} />
      </div>
      <span className="w-9 shrink-0 text-right text-xs text-muted-foreground">{percent}%</span>
    </div>
  );
}
