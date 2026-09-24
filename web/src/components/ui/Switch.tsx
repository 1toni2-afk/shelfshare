import { useId } from 'react';
import { cn } from '@/lib/utils/cn';

/**
 * Comutator cu etichetă și explicație. Randat ca `<input type="checkbox">`
 * ascuns, nu ca `<div role="switch">`: primește gratis focus la Tab, comutare
 * cu Space, și e citit corect de cititoarele de ecran.
 */
export function Switch({
  checked,
  onChange,
  label,
  hint,
  disabled = false,
}: {
  checked: boolean;
  onChange: (value: boolean) => void;
  label: string;
  hint?: string;
  disabled?: boolean;
}) {
  const id = useId();

  return (
    <label
      htmlFor={id}
      className={cn(
        'flex cursor-pointer items-start gap-3 rounded-[16px] border border-border bg-card p-4',
        disabled && 'cursor-not-allowed opacity-60',
      )}
    >
      <input
        id={id}
        type="checkbox"
        checked={checked}
        disabled={disabled}
        onChange={(event) => onChange(event.target.checked)}
        className="peer sr-only"
      />

      <span
        aria-hidden="true"
        className={cn(
          'mt-0.5 flex h-6 w-11 shrink-0 items-center rounded-full p-0.5 transition',
          'peer-focus-visible:outline peer-focus-visible:outline-2 peer-focus-visible:outline-accent',
          checked ? 'bg-accent' : 'bg-muted-foreground/30',
        )}
      >
        <span
          className={cn(
            'size-5 rounded-full bg-white shadow transition',
            checked && 'translate-x-5',
          )}
        />
      </span>

      <span className="min-w-0 flex-1">
        <span className="block font-medium">{label}</span>
        {hint && <span className="mt-0.5 block text-sm text-muted-foreground">{hint}</span>}
      </span>
    </label>
  );
}
