import { lazy, Suspense, type ReactNode } from 'react';
import { useLocation, useNavigate } from 'react-router-dom';
import { useTranslation } from 'react-i18next';
import { ArrowLeft, BookOpen } from 'lucide-react';

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
          {/*
            `relative` pe antet, iar săgeata așezată absolut peste el: coloana
            din mijloc rămâne centrată pe card, nu pe spațiul rămas la dreapta
            butonului. Un rând flex cu săgeata în stânga ar fi împins logo-ul și
            titlul cu jumătate de buton spre dreapta - suficient cât să se vadă.
          */}
          <div className="relative mb-8 flex flex-col items-center gap-3 text-center">
            <BackButton />
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

/**
 * Săgeata de ieșire din ecranele de autentificare.
 *
 * Ecranele astea nu stau în shell-ul aplicației, deci n-au nici bara laterală,
 * nici `ScreenHeader` - până acum, cine ajungea pe /login dintr-un link nu avea
 * niciun drum înapoi în interfață, doar butonul browserului.
 *
 * `location.key === 'default'` înseamnă că pagina asta e PRIMA intrare din
 * istoricul aplicației: s-a intrat direct pe adresă, dintr-un email sau de pe
 * un motor de căutare. Acolo `navigate(-1)` ar scoate omul de pe site cu totul
 * (înapoi la Google), deci îl ducem pe pagina principală. Altfel, un pas
 * înapoi - exact de unde a venit.
 */
function BackButton() {
  const { t } = useTranslation();
  const navigate = useNavigate();
  const location = useLocation();
  const isFirstEntry = location.key === 'default';

  return (
    <button
      type="button"
      onClick={() => (isFirstEntry ? void navigate('/') : void navigate(-1))}
      aria-label={t('commonBack')}
      title={t('commonBack')}
      className="absolute left-0 top-0 rounded-full p-2.5 text-muted-foreground transition hover:bg-muted hover:text-foreground"
    >
      <ArrowLeft size={22} />
    </button>
  );
}
