import {
  createContext,
  use,
  useCallback,
  useMemo,
  useRef,
  useState,
  type ReactNode,
} from 'react';

/**
 * Echivalentul lui `ScaffoldMessenger.showSnackBar` din Flutter: mesaje scurte,
 * efemere, care nu întrerup fluxul (cod retrimis, parolă schimbată, carte
 * adăugată). Pentru erori care CER o decizie se folosesc mesaje inline, ca în
 * aplicația de telefon - un toast care dispare singur nu e locul unde afli că
 * n-ai putut salva ceva.
 */
interface Toast {
  id: number;
  message: string;
  tone: 'neutral' | 'danger';
}

interface ToastContextValue {
  show(message: string, tone?: Toast['tone']): void;
}

const ToastContext = createContext<ToastContextValue | null>(null);

const DURATION_MS = 4000;

export function ToastProvider({ children }: { children: ReactNode }) {
  const [toasts, setToasts] = useState<Toast[]>([]);
  const nextId = useRef(0);

  const show = useCallback((message: string, tone: Toast['tone'] = 'neutral') => {
    const id = nextId.current++;
    setToasts((current) => [...current, { id, message, tone }]);
    window.setTimeout(() => {
      setToasts((current) => current.filter((toast) => toast.id !== id));
    }, DURATION_MS);
  }, []);

  const value = useMemo(() => ({ show }), [show]);

  return (
    <ToastContext value={value}>
      {children}
      {/*
        `pointer-events-none` pe container, `auto` pe fiecare mesaj: altfel
        zona invizibilă de deasupra conținutului ar înghiți clickurile pe tot
        ce e sub ea, inclusiv când nu e afișat niciun toast.
      */}
      <div
        aria-live="polite"
        className="pointer-events-none fixed inset-x-0 bottom-0 z-[100] flex flex-col items-center gap-2 p-4"
      >
        {toasts.map((toast) => (
          <div
            key={toast.id}
            className={
              'pointer-events-auto max-w-[92vw] rounded-[12px] px-4 py-3 text-sm shadow-lg ' +
              (toast.tone === 'danger'
                ? 'bg-destructive text-white'
                : 'bg-foreground text-background')
            }
          >
            {toast.message}
          </div>
        ))}
      </div>
    </ToastContext>
  );
}

export function useToast(): ToastContextValue {
  const context = use(ToastContext);
  if (!context) throw new Error('useToast folosit în afara ToastProvider');
  return context;
}
