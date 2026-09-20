import type { ReactNode } from 'react';
import { BookOpen } from 'lucide-react';

/**
 * Carcasa comună a ecranelor de autentificare (login, înregistrare, resetare
 * parolă). În Flutter fiecare ecran își repeta singur logo-ul, lățimea maximă
 * și centrarea, iar cele trei ajunseseră să difere cu câțiva pixeli între ele.
 */
export function AuthLayout({
  title,
  subtitle,
  children,
  footer,
}: {
  title: string;
  subtitle?: string;
  children: ReactNode;
  footer?: ReactNode;
}) {
  return (
    <div className="flex min-h-dvh flex-col items-center justify-center bg-background px-5 py-10">
      <div className="w-full max-w-[400px]">
        <div className="mb-8 flex flex-col items-center gap-3 text-center">
          <span className="rounded-2xl bg-accent/15 p-3 text-accent">
            <BookOpen size={32} />
          </span>
          <h1 className="font-display text-3xl font-bold">{title}</h1>
          {subtitle && <p className="text-muted-foreground">{subtitle}</p>}
        </div>

        {children}

        {footer}
      </div>
    </div>
  );
}
