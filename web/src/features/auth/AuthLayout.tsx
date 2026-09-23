import { lazy, Suspense, type ReactNode } from 'react';
import { BookOpen } from 'lucide-react';

/*
  Pagina publică, randată ESTOMPAT în spatele formularului.

  `lazy`, nu un import obișnuit: altfel toată pagina de prezentare (cu
  rândurile ei de cărți) ar intra în bucata de JavaScript a ecranului de
  autentificare, care e primul lucru descărcat de cineva care se loghează.
  Așa rămâne o bucată separată, cerută după ce formularul e deja pe ecran.
*/
const PublicLandingScreen = lazy(() =>
  import('@/features/public/PublicLandingScreen').then((m) => ({
    default: m.PublicLandingScreen,
  })),
);

/**
 * Carcasa comună a ecranelor de autentificare (login, înregistrare, resetare
 * parolă). În Flutter fiecare ecran își repeta singur logo-ul, lățimea maximă
 * și centrarea, iar cele trei ajunseseră să difere cu câțiva pixeli între ele.
 *
 * Fundalul nu e o suprafață goală, ci chiar aplicația așa cum o vede un om
 * fără cont, estompată: cine ajunge la formular vede ce primește după el, nu
 * un dreptunghi pe fond uniform. Același gest ca la `GuestGate` - acolo
 * fundalul se estompează când vizitatorul apasă ceva ce cere cont.
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
    <div className="relative min-h-dvh overflow-hidden bg-background">
      {/*
        `aria-hidden` + `pointer-events-none`: pentru cititoarele de ecran și
        pentru tastatură fundalul nu există deloc. Fără asta, Tab-ul ar plimba
        omul prin zeci de linkuri invizibile înainte să ajungă la câmpul de
        email, iar cititorul de ecran ar citi toată pagina de prezentare peste
        formular.

        `select-none` pentru că un text estompat care se poate selecta arată a
        defect, nu a fundal.
      */}
      <div
        aria-hidden="true"
        className="pointer-events-none absolute inset-0 select-none overflow-hidden opacity-45 blur-[7px] saturate-[0.6]"
      >
        {/*
          Fără indicator de încărcare: e decor. Un spinner în spatele
          formularului ar atrage privirea exact unde nu trebuie.
        */}
        <Suspense fallback={null}>
          <PublicLandingScreen decorative />
        </Suspense>
      </div>

      {/*
        Un văl peste fundal, separat de estompare: numai `blur` nu garantează
        contrastul - o copertă deschisă la culoare sub textul secundar îl face
        ilizibil, iar asta depinde de ce cărți s-au listat în ziua aia.
      */}
      <div aria-hidden="true" className="absolute inset-0 bg-background/65" />

      <div className="relative flex min-h-dvh flex-col items-center justify-center px-5 py-10">
        <div className="w-full max-w-[400px] rounded-[20px] border border-border bg-card/80 p-6 shadow-xl backdrop-blur-xl min-[560px]:p-8">
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
    </div>
  );
}
