import {
  createContext,
  use,
  useCallback,
  useEffect,
  useMemo,
  useRef,
  useState,
  type ReactNode,
} from 'react';
import { useQueryClient } from '@tanstack/react-query';
import { ApiError, SESSION_EXPIRED_EVENT } from '@/lib/api/client';
// `messageOf` e o funcție pură, în afara componentei, deci instanța i18next
// direct - `useTranslation` e un hook și n-are ce căuta acolo.
import i18n from '@/lib/i18n';
import { chatSocket } from '@/lib/socket/chatSocket';
import { authRepository } from './authRepository';
import type { AppUser, CaptchaChallenge } from '@/types/models';

/**
 * Stările de autentificare, portate din auth_state.dart.
 *
 * `restoring` e distinct de `unauthenticated` DINADINS. La pornire citim
 * token-ul din storage și cerem /profile/me - cât durează, nu știm încă dacă
 * userul e logat. Dacă am colapsa starea asta peste "neautentificat", fiecare
 * reîncărcare de pagină ar arunca un user logat pe /login pentru o fracțiune
 * de secundă, iar navigarea directă la o rută protejată (bookmark, link din
 * email, push) l-ar duce definitiv la login. Gardienii de rută trebuie deci
 * să trateze `restoring` ca "așteaptă", nu ca "respinge".
 */
export type AuthStatus =
  | { kind: 'restoring' }
  | { kind: 'authenticated'; user: AppUser }
  | { kind: 'unauthenticated' }
  | { kind: 'error'; message: string }
  /** Contul există, parola e bună, dar emailul nu e confirmat încă. */
  | { kind: 'emailNotVerified'; email: string }
  | { kind: 'captchaRequired'; captcha: CaptchaChallenge; email: string; password: string; message: string | null };

interface AuthContextValue {
  status: AuthStatus;
  /** Userul curent, sau null. Scurtătură pentru cazul cel mai des folosit. */
  user: AppUser | null;
  busy: boolean;
  login(input: { email: string; password: string; captchaToken?: string; captchaAnswer?: number }): Promise<void>;
  completeExternalLogin(code: string): Promise<void>;
  register(input: { email: string; password: string; referralCode?: string }): Promise<void>;
  logout(): Promise<void>;
  /** Actualizează userul după o editare de profil, fără un tur complet prin API. */
  setUser(user: AppUser): void;
  clearError(): void;
}

const AuthContext = createContext<AuthContextValue | null>(null);

export function AuthProvider({ children }: { children: ReactNode }) {
  const [status, setStatus] = useState<AuthStatus>({ kind: 'restoring' });
  const [busy, setBusy] = useState(false);
  const queryClient = useQueryClient();

  // StrictMode montează de două ori în dev; fără garda asta, restaurarea
  // sesiunii pleacă de două ori și se văd două /profile/me la fiecare pornire.
  const restored = useRef(false);

  useEffect(() => {
    if (restored.current) return;
    restored.current = true;

    // Fără flag de anulare în cleanup, dinadins. Combinat cu garda de mai sus
    // ar bloca aplicația definitiv pe „restoring": în StrictMode, prima rulare
    // pornește cererea, cleanup-ul o marchează anulată, iar a doua rulare nu
    // mai pornește alta - deci nimeni nu mai apelează setStatus. Garda pe ref
    // garanteaza deja o singură cerere, deci nu e nimic de anulat.
    void authRepository.tryRestoreSession().then((user) => {
      setStatus(user ? { kind: 'authenticated', user } : { kind: 'unauthenticated' });
    });
  }, []);

  // Sesiunea a devenit invalidă la nivel de rețea (token revocat, cont șters).
  // Stratul de API nu poate naviga singur, deci emite un eveniment.
  useEffect(() => {
    const onExpired = () => {
      setStatus({ kind: 'unauthenticated' });
      queryClient.clear();
      chatSocket.disconnect();
    };
    window.addEventListener(SESSION_EXPIRED_EVENT, onExpired);
    return () => window.removeEventListener(SESSION_EXPIRED_EVENT, onExpired);
  }, [queryClient]);

  const login = useCallback<AuthContextValue['login']>(
    async (input) => {
      setBusy(true);
      try {
        // Golim cache-ul ÎNAINTE de a încărca userul nou. Altfel, un al doilea
        // login pe același browser afișează pentru o clipă datele contului
        // anterior (biblioteca, conversațiile), fiindcă cheile de query sunt
        // aceleași și React Query servește valoarea veche cât timp refetch-ul
        // e în zbor.
        queryClient.clear();
        const user = await authRepository.login(input);
        setStatus({ kind: 'authenticated', user });
      } catch (error) {
        setStatus(toFailureState(error, input.email, input.password));
      } finally {
        setBusy(false);
      }
    },
    [queryClient],
  );

  const completeExternalLogin = useCallback<AuthContextValue['completeExternalLogin']>(
    async (code) => {
      setBusy(true);
      try {
        queryClient.clear();
        const user = await authRepository.completeExternalLogin(code);
        setStatus({ kind: 'authenticated', user });
      } catch {
        setStatus({ kind: 'unauthenticated' });
      } finally {
        setBusy(false);
      }
    },
    [queryClient],
  );

  const register = useCallback<AuthContextValue['register']>(async (input) => {
    setBusy(true);
    try {
      await authRepository.register(input);
      // Înregistrarea NU loghează: userul trebuie întâi să confirme emailul.
      setStatus({ kind: 'unauthenticated' });
    } catch (error) {
      setStatus({ kind: 'error', message: messageOf(error) });
    } finally {
      setBusy(false);
    }
  }, []);

  const logout = useCallback(async () => {
    // Socketul se închide ÎNAINTE de orice altceva. Lăsat deschis, rămâne
    // autentificat cu tokenul contului tocmai deconectat, iar serverul continuă
    // să-l vadă pe userul respectiv „online" până expiră tokenul - prezența ar
    // deveni o minciună.
    chatSocket.disconnect();
    await authRepository.logout();
    setStatus({ kind: 'unauthenticated' });
    queryClient.clear();
  }, [queryClient]);

  const setUser = useCallback((user: AppUser) => {
    setStatus((current) => (current.kind === 'authenticated' ? { kind: 'authenticated', user } : current));
  }, []);

  const clearError = useCallback(() => {
    setStatus((current) =>
      current.kind === 'error' || current.kind === 'captchaRequired'
        ? { kind: 'unauthenticated' }
        : current,
    );
  }, []);

  const value = useMemo<AuthContextValue>(
    () => ({
      status,
      user: status.kind === 'authenticated' ? status.user : null,
      busy,
      login,
      completeExternalLogin,
      register,
      logout,
      setUser,
      clearError,
    }),
    [status, busy, login, completeExternalLogin, register, logout, setUser, clearError],
  );

  return <AuthContext value={value}>{children}</AuthContext>;
}

/**
 * Backendul cere un captcha după prea multe încercări eșuate (vezi
 * AuthService.requireCaptchaIfSuspicious). Vine ca 401 cu `requiresCaptcha`
 * în corp, nu ca status separat - deci îl distingem aici, nu după cod.
 */
function toFailureState(error: unknown, email: string, password: string): AuthStatus {
  if (error instanceof ApiError && error.data && typeof error.data === 'object') {
    const data = error.data as { requiresCaptcha?: unknown; captcha?: unknown; code?: unknown };

    /*
      Cont necomfirmat: îl deosebim după `code`, nu după mesaj - mesajul e
      tradus și s-ar rupe la prima limbă nouă. Ecranul de autentificare duce
      omul la confirmare în loc să-i arate un text fără ieșire.
    */
    if (data.code === 'EMAIL_NOT_VERIFIED') {
      return { kind: 'emailNotVerified', email };
    }

    if (data.requiresCaptcha === true && data.captcha && typeof data.captcha === 'object') {
      return {
        kind: 'captchaRequired',
        captcha: data.captcha as CaptchaChallenge,
        email,
        password,
        message: error.message,
      };
    }
  }
  return { kind: 'error', message: messageOf(error) };
}

function messageOf(error: unknown): string {
  return error instanceof ApiError ? error.message : i18n.t('commonGenericError');
}

export function useAuth(): AuthContextValue {
  const context = use(AuthContext);
  if (!context) throw new Error('useAuth folosit în afara AuthProvider');
  return context;
}
