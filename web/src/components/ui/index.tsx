import type { ButtonHTMLAttributes, InputHTMLAttributes, ReactNode } from 'react';
import { cn } from '@/lib/utils/cn';

/**
 * Primitivele de interfață, portate din `ThemeData` (app_theme.dart).
 *
 * Fiecare valoare de aici are un corespondent acolo - razele (12 pentru
 * butoane, 16 pentru câmpuri și carduri), padding-urile (24x16 pe butoane cu
 * text) și faptul că marginile sunt `border`, nu umbre. Nu inventăm un al
 * doilea sistem vizual: cele două aplicații trebuie să arate identic cât timp
 * coexistă.
 */

type ButtonVariant = 'primary' | 'outline' | 'text' | 'destructive';

const BUTTON_VARIANTS: Record<ButtonVariant, string> = {
  primary: 'bg-primary text-primary-foreground hover:brightness-110',
  outline: 'border border-border text-foreground hover:bg-muted',
  text: 'text-foreground hover:bg-muted',
  destructive: 'bg-destructive text-white hover:brightness-110',
};

interface ButtonProps extends ButtonHTMLAttributes<HTMLButtonElement> {
  variant?: ButtonVariant;
  loading?: boolean;
  fullWidth?: boolean;
}

export function Button({
  variant = 'primary',
  loading = false,
  fullWidth = false,
  className,
  children,
  disabled,
  ...props
}: ButtonProps) {
  return (
    <button
      // `disabled` cât timp încarcă, nu doar un spinner peste text: altfel un
      // dublu-click pe "Intră în cont" trimite două cereri de login, iar a
      // doua consumă încercarea și poate declanșa captcha-ul.
      disabled={disabled || loading}
      className={cn(
        'inline-flex items-center justify-center gap-2 rounded-[12px] px-6 py-4',
        'text-[15px] font-bold transition disabled:opacity-60 disabled:cursor-not-allowed',
        BUTTON_VARIANTS[variant],
        fullWidth && 'w-full',
        className,
      )}
      {...props}
    >
      {loading && <Spinner size={16} />}
      {children}
    </button>
  );
}

interface FieldProps extends InputHTMLAttributes<HTMLInputElement> {
  label: string;
  error?: string | null;
  /**
   * Explicație neutră sub câmp (nu o eroare): o regulă pe care omul trebuie
   * s-o știe ÎNAINTE să scrie, nu după ce a greșit. Eroarea o înlocuiește
   * când apare - două rânduri de text sub același câmp se bat cap în cap.
   */
  hint?: string;
  /**
   * Ascunde eticheta vizual, păstrând-o pentru cititoarele de ecran. Pentru
   * câmpurile unde textul din jur o face redundantă - codul de confirmare, de
   * pildă, are deja titlul și explicația deasupra, iar în Flutter câmpul n-are
   * etichetă deloc, doar hint-ul „000000".
   */
  hideLabel?: boolean;
}

export function Field({
  label,
  error,
  hint,
  className,
  id,
  hideLabel = false,
  ...props
}: FieldProps) {
  const inputId = id ?? props.name ?? label;
  return (
    <div className="flex flex-col gap-1.5">
      {/*
        Eticheta stă DEASUPRA câmpului, nu flotantă în interiorul lui. În
        Flutter am ajuns la `FloatingLabelBehavior.never` din același motiv:
        varianta flotantă cere loc rezervat deasupra valorii, deci câmpul are
        două geometrii diferite după cum e gol sau plin, iar textul tastat
        apărea împins spre baza pastilei.
      */}
      <label
        htmlFor={inputId}
        className={cn(
          'text-sm font-medium text-muted-foreground',
          // `sr-only`, nu `hidden`: ascuns cu display:none, textul dispare și
          // pentru cititoarele de ecran, iar câmpul rămâne fără nume.
          hideLabel && 'sr-only',
        )}
      >
        {label}
      </label>
      <input
        id={inputId}
        className={cn(
          'w-full rounded-[16px] bg-muted px-4 py-4 text-foreground',
          'placeholder:text-muted-foreground border border-transparent',
          'focus:outline-none focus:border-accent transition',
          // Un câmp blocat trebuie să ARATE blocat, nu doar să refuze tastele.
          props.disabled && 'cursor-not-allowed opacity-60',
          error && 'border-destructive',
          className,
        )}
        {...props}
      />
      {error ? (
        <p className="text-sm text-danger-text">{error}</p>
      ) : (
        hint && <p className="text-sm text-muted-foreground">{hint}</p>
      )}
    </div>
  );
}

export function Card({ className, children }: { className?: string; children: ReactNode }) {
  return (
    <div className={cn('rounded-[16px] border border-border bg-card', className)}>{children}</div>
  );
}

export function Spinner({ size = 20, className }: { size?: number; className?: string }) {
  return (
    <span
      role="status"
      aria-label="Se încarcă"
      style={{ width: size, height: size, borderWidth: Math.max(2, size / 10) }}
      className={cn(
        'inline-block animate-spin rounded-full border-current border-t-transparent opacity-70',
        className,
      )}
    />
  );
}

/** Ecran plin de încărcare - folosit cât se restaurează sesiunea. */
export function FullScreenLoader() {
  return (
    <div className="flex min-h-dvh items-center justify-center bg-background text-accent">
      <Spinner size={32} />
    </div>
  );
}

export function ErrorNotice({ message, onRetry }: { message: string; onRetry?: () => void }) {
  return (
    <div className="flex flex-col items-center gap-3 rounded-[16px] border border-border bg-card p-6 text-center">
      <p className="text-danger-text">{message}</p>
      {onRetry && (
        <Button variant="outline" onClick={onRetry}>
          Încearcă din nou
        </Button>
      )}
    </div>
  );
}
