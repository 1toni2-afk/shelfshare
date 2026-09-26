import {
  createContext,
  use,
  useEffect,
  useMemo,
  useState,
  type MouseEvent,
  type ReactNode,
} from 'react';
import { Link } from 'react-router-dom';
import { useTranslation } from 'react-i18next';
import { Lock, X } from 'lucide-react';
import { BrandMark } from '@/components/ui/BrandMark';
import { useAuth } from './AuthProvider';
import { cn } from '@/lib/utils/cn';

/**
 * „Poarta" vizitatorului fără cont.
 *
 * Aplicația arată aceeași interfață și fără cont - aceeași bară laterală,
 * aceleași carduri, aceeași pagină principală - fiindcă o interfață complet
 * diferită înainte și după înregistrare îl pune pe om să învețe produsul de
 * două ori. Diferența e ce se ÎNTÂMPLĂ la click: tot ce nu e pagina principală
 * deschide dialogul de mai jos, cu fundalul estompat, în loc să navigheze.
 *
 * De ce oprim la click și nu la rută: rutele publice (`/browse`, `/books/:id`,
 * `/users/:id`) trebuie să rămână deschise pentru crawlere și pentru omul care
 * intră direct din Google - exact conținutul pe care îl pre-randează
 * scripts/beta-seo.js. Un gardian pe rută ar fi arătat robotului catalogul și
 * omului un dialog, adică fix discrepanța pe care o penalizează motoarele de
 * căutare.
 */
interface GuestGateValue {
  /** Sesiune fără cont. `false` cât timp sesiunea încă se restaurează. */
  isGuest: boolean;
  /** Deschide dialogul. Pentru un user logat nu face nimic. */
  open(): void;
  /**
   * `onClick` pentru un link sau buton interzis vizitatorului: oprește
   * navigarea și deschide dialogul. Pentru un user logat lasă clicul să treacă.
   */
  block(event: MouseEvent): void;
}

const GuestGateContext = createContext<GuestGateValue>({
  isGuest: false,
  open: () => {},
  block: () => {},
});

export function useGuestGate(): GuestGateValue {
  return use(GuestGateContext);
}

export function GuestGateProvider({ children }: { children: ReactNode }) {
  const { status } = useAuth();
  const [open, setOpen] = useState(false);

  // `restoring` NU e „vizitator": tratată așa, interfața ar pâlpâi cu numele
  // estompate și ar deschide dialogul la primul click de după o reîncărcare,
  // pentru un om care chiar e logat.
  const isGuest = status.kind !== 'authenticated' && status.kind !== 'restoring';

  const value = useMemo<GuestGateValue>(
    () => ({
      isGuest,
      open: () => {
        if (isGuest) setOpen(true);
      },
      block: (event: MouseEvent) => {
        if (!isGuest) return;
        event.preventDefault();
        event.stopPropagation();
        setOpen(true);
      },
    }),
    [isGuest],
  );

  return (
    <GuestGateContext value={value}>
      {children}
      {open && isGuest && <GuestGateDialog onClose={() => setOpen(false)} />}
    </GuestGateContext>
  );
}

function GuestGateDialog({ onClose }: { onClose: () => void }) {
  const { t } = useTranslation();

  useEffect(() => {
    const onKey = (event: KeyboardEvent) => {
      if (event.key === 'Escape') onClose();
    };
    window.addEventListener('keydown', onKey);
    return () => window.removeEventListener('keydown', onKey);
  }, [onClose]);

  return (
    // Peste panoul glisant de pe telefon (z-50), altfel dialogul deschis din
    // meniu ar rămâne dedesubt.
    <div
      role="dialog"
      aria-modal="true"
      className="fixed inset-0 z-[60] flex items-end justify-center min-[560px]:items-center"
    >
      {/*
        Fundalul se ESTOMPEAZĂ, nu se întunecă doar: omul vede că aplicația e
        acolo, plină de cărți, dar nu o poate citi - e toată diferența dintre
        „mai e ceva aici" și un perete negru.
      */}
      <button
        aria-label={t('commonClose', 'Închide')}
        onClick={onClose}
        className="absolute inset-0 bg-background/70 backdrop-blur-md"
      />

      <div className="relative w-full max-w-[420px] rounded-t-[20px] border border-border bg-card p-6 shadow-xl min-[560px]:rounded-[20px]">
        <button
          onClick={onClose}
          aria-label={t('commonClose', 'Închide')}
          className="absolute right-3 top-3 rounded-full p-2 text-muted-foreground hover:bg-muted"
        >
          <X size={18} />
        </button>

        <BrandMark size={42} />

        <h2 className="mt-3 font-display text-xl font-bold">
          {t('guestGateTitle', 'Creează-ți cont ca să continui')}
        </h2>
        <p className="mt-2 text-sm leading-relaxed text-muted-foreground">
          {t(
            'guestGateText',
            'Biblioteca ta, mesajele, schimburile și cine vinde fiecare carte sunt pentru cititorii cu cont. Îți faci unul în mai puțin de un minut și e gratuit.',
          )}
        </p>

        <div className="mt-6 flex flex-col gap-2">
          <Link
            to="/register"
            onClick={onClose}
            className="rounded-[12px] bg-primary px-6 py-3.5 text-center text-[15px] font-bold text-primary-foreground hover:brightness-110"
          >
            {t('guestGateRegister', 'Creează cont gratuit')}
          </Link>
          <Link
            to="/login"
            onClick={onClose}
            className="rounded-[12px] border border-border px-6 py-3.5 text-center text-[15px] font-bold text-foreground hover:bg-muted"
          >
            {t('guestGateLogin', 'Am deja cont')}
          </Link>
        </div>
      </div>
    </div>
  );
}

/**
 * Numele unui vânzător, ascuns pentru vizitatorul fără cont.
 *
 * Estompat, nu scos: locul din interfață rămâne exact același înainte și după
 * înregistrare, iar omul vede CE anume primește dacă își face cont. Clicul pe
 * el duce la dialogul de mai sus.
 *
 * Textul chiar ajunge în DOM (estomparea e doar un filtru CSS), deci nu e un
 * secret criptografic - nici nu poate fi, fiindcă API-ul public îl întoarce
 * oricum, la fel cum îl pre-randează pagina publică de profil pentru crawlere.
 * E o barieră de produs, nu una de securitate.
 */
export function SellerName({ name, className }: { name: string; className?: string }) {
  const { t } = useTranslation();
  const { isGuest } = useGuestGate();

  if (!isGuest) return <span className={className}>{name}</span>;

  return (
    // `<span>`, nu `<button>`: rândul din care face parte e el însuși
    // apăsabil (cardul vânzătorului), iar un buton în alt buton e HTML
    // invalid - React chiar se plânge în consolă. Clicul e tratat de părinte.
    <span
      title={t('guestSellerHidden', 'Creează-ți cont ca să vezi cine vinde cartea')}
      className="flex min-w-0 items-center gap-1.5"
    >
      {/* Numele rămâne în DOM, doar estompat: e o barieră de produs, nu una de
          securitate - API-ul public îl întoarce oricum, la fel cum îl
          pre-randează pagina publică de profil pentru crawlere. */}
      <span
        className={cn('truncate select-none blur-[5px]', className)}
        style={{ WebkitUserSelect: 'none', userSelect: 'none' }}
      >
        {name}
      </span>
      <Lock size={13} className="shrink-0 text-muted-foreground" />
      <span className="sr-only">
        {t('guestSellerHidden', 'Creează-ți cont ca să vezi cine vinde cartea')}
      </span>
    </span>
  );
}
