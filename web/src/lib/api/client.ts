import type { TokenStorage } from '@/lib/storage/tokenStorage';
import { webTokenStorage } from '@/lib/storage/tokenStorage';

declare const __API_BASE_URL__: string;

/** Injectat de Vite la build (vezi `define` din vite.config.ts). */
export const API_BASE_URL: string = __API_BASE_URL__;

/** Timeout identic cu cel din Dio (connect/receive 10s). */
const TIMEOUT_MS = 10_000;

/**
 * Eroare de rețea/API. Ține statusul și corpul răspunsului, ca apelanții să
 * poată distinge cazuri (ex. 401 cu `requiresCaptcha` la login) fără să
 * parseze din nou textul.
 */
export class ApiError extends Error {
  constructor(
    message: string,
    readonly status: number | null,
    readonly data: unknown,
  ) {
    super(message);
    this.name = 'ApiError';
  }

  /** True dacă cererea nu a primit niciun răspuns (offline, DNS, timeout). */
  get isNetworkError(): boolean {
    return this.status === null;
  }
}

export interface RequestOptions {
  method?: 'GET' | 'POST' | 'PUT' | 'PATCH' | 'DELETE';
  body?: unknown;
  query?: Record<string, string | number | boolean | undefined | null>;
  signal?: AbortSignal;
  /** Sare peste atașarea JWT-ului (folosit de /auth/refresh, ca să nu se auto-reintre). */
  anonymous?: boolean;
  /** Pentru upload-uri: trimite FormData brut, fără JSON.stringify. */
  formData?: FormData;
  /**
   * Peste timeout-ul implicit, pentru cererile care chiar durează (importul de
   * CSV cu câteva mii de rânduri). Aceeași excepție pe care o face și Dio în
   * `importListingsCsv`.
   */
  timeoutMs?: number;
}

/**
 * Clientul HTTP central. Port direct al clasei `ApiClient` din
 * frontend/lib/core/network/api_client.dart: atașează JWT-ul la fiecare
 * cerere și reîncearcă O SINGURĂ dată cu refresh token dacă primește 401.
 */
export class ApiClient {
  constructor(
    private readonly tokens: TokenStorage,
    private readonly onSessionExpired?: () => void,
  ) {}

  /**
   * Reîmprospătarea e "single-flight": dacă trei cereri paralele iau 401
   * simultan, se face UN singur POST /auth/refresh, iar celelalte două
   * așteaptă același rezultat. Altfel, refresh token-ul fiind rotit de
   * backend la fiecare folosire, a doua cerere l-ar prezenta pe cel deja
   * consumat și ar primi 401 - adică exact deconectarea pe care încercăm
   * să o evităm. Se vede doar pe ecranele care lansează mai multe cereri
   * odată (Home), nu la login.
   */
  private refreshInFlight: Promise<boolean> | null = null;

  async request<T>(path: string, options: RequestOptions = {}): Promise<T> {
    const response = await this.send(path, options);

    if (response.status === 401 && !options.anonymous) {
      const refreshed = await this.refreshOnce();
      if (refreshed) {
        const retry = await this.send(path, options);
        return this.parse<T>(retry);
      }
      // Refresh token invalid/expirat/revocat (ex. contul a fost șters).
      // Fără semnalul ăsta, userul rămâne "logat" vizual, cu fiecare cerere
      // eșuând tăcut la 401, până la un refresh manual de pagină.
      this.onSessionExpired?.();
    }

    return this.parse<T>(response);
  }

  get<T>(path: string, options?: Omit<RequestOptions, 'method' | 'body'>) {
    return this.request<T>(path, { ...options, method: 'GET' });
  }

  post<T>(path: string, body?: unknown, options?: Omit<RequestOptions, 'method' | 'body'>) {
    return this.request<T>(path, { ...options, method: 'POST', body });
  }

  patch<T>(path: string, body?: unknown, options?: Omit<RequestOptions, 'method' | 'body'>) {
    return this.request<T>(path, { ...options, method: 'PATCH', body });
  }

  put<T>(path: string, body?: unknown, options?: Omit<RequestOptions, 'method' | 'body'>) {
    return this.request<T>(path, { ...options, method: 'PUT', body });
  }

  delete<T>(path: string, options?: Omit<RequestOptions, 'method' | 'body'>) {
    return this.request<T>(path, { ...options, method: 'DELETE' });
  }

  private async send(path: string, options: RequestOptions): Promise<Response> {
    const url = new URL(path.replace(/^\//, ''), ensureTrailingSlash(API_BASE_URL));
    if (options.query) {
      for (const [key, value] of Object.entries(options.query)) {
        if (value !== undefined && value !== null) url.searchParams.set(key, String(value));
      }
    }

    const headers = new Headers({
      // Fetch respectă cache-ul HTTP al browserului, care NU ține cont de
      // header-ul Authorization. Fără asta, un GET autentificat putea întoarce
      // răspunsul cache-uit al userului anterior logat pe același browser
      // (ex. /profile/me imediat după login).
      'Cache-Control': 'no-cache',
    });

    if (!options.anonymous) {
      const token = await this.tokens.getAccessToken();
      if (token) headers.set('Authorization', 'Bearer ' + token);
    }

    let body: BodyInit | undefined;
    if (options.formData) {
      // Fără Content-Type explicit: îl pune browserul, cu boundary-ul corect.
      body = options.formData;
    } else if (options.body !== undefined) {
      headers.set('Content-Type', 'application/json');
      body = JSON.stringify(options.body);
    }

    // Timeout propriu: fetch nu are unul. O cerere de refresh blocată ținea
    // în loc ensureFreshToken, iar prin el autentificarea socketului, care
    // nu mai apela niciodată callback-ul de conectare.
    const timeout = AbortSignal.timeout(options.timeoutMs ?? TIMEOUT_MS);
    const signal = options.signal ? AbortSignal.any([options.signal, timeout]) : timeout;

    try {
      return await fetch(url, { method: options.method ?? 'GET', headers, body, signal });
    } catch (error) {
      throw new ApiError(networkMessage(error), null, null);
    }
  }

  private async parse<T>(response: Response): Promise<T> {
    if (response.status === 204 || response.headers.get('content-length') === '0') {
      return undefined as T;
    }

    const text = await response.text();
    let data: unknown = null;
    if (text) {
      try {
        data = JSON.parse(text);
      } catch {
        data = text;
      }
    }

    if (!response.ok) {
      throw new ApiError(extractMessage(data), response.status, data);
    }
    return data as T;
  }

  private refreshOnce(): Promise<boolean> {
    this.refreshInFlight ??= this.doRefresh().finally(() => {
      this.refreshInFlight = null;
    });
    return this.refreshInFlight;
  }

  private async doRefresh(): Promise<boolean> {
    const refreshToken = await this.tokens.getRefreshToken();
    if (!refreshToken) return false;

    try {
      const response = await this.send('/auth/refresh', {
        method: 'POST',
        body: { refreshToken },
        anonymous: true,
      });
      if (!response.ok) {
        await this.tokens.clear();
        return false;
      }
      const data = (await response.json()) as { accessToken: string; refreshToken: string };
      await this.tokens.saveTokens(data);
      return true;
    } catch {
      await this.tokens.clear();
      return false;
    }
  }

  /**
   * Se asigură că token-ul din storage e valid, reîmprospătându-l dacă a
   * expirat (sau e pe punctul să expire).
   *
   * Există pentru socketul de chat, care are nevoie de un token proaspăt la
   * (re)conectare. Nu face niciun request cât timp token-ul e încă valid - ne
   * uităm doar la `exp` din payload-ul JWT. Varianta naivă (un GET pe
   * /profile/me doar ca să declanșeze reîmprospătarea) descărca profilul
   * complet de fiecare dată când socketul se autentifica: se vedeau 4 cereri
   * /profile/me una după alta în waterfall-ul de pornire.
   */
  async ensureFreshToken(): Promise<void> {
    const token = await this.tokens.getAccessToken();
    if (token && !isExpiringSoon(token)) return;
    await this.refreshOnce();
  }
}

/**
 * `exp` din payload-ul JWT (secunde Unix), cu marjă de 30s: un token care
 * expiră chiar în timpul handshake-ului e tratat ca expirat. Orice token pe
 * care nu îl putem citi e considerat expirat - reîmprospătarea e ieftină, un
 * handshake cu token invalid nu e.
 */
function isExpiringSoon(token: string): boolean {
  try {
    const parts = token.split('.');
    if (parts.length !== 3) return true;
    const payload = JSON.parse(decodeBase64Url(parts[1])) as { exp?: unknown };
    if (typeof payload.exp !== 'number') return true;
    return payload.exp * 1000 < Date.now() + 30_000;
  } catch {
    return true;
  }
}

function decodeBase64Url(value: string): string {
  const base64 = value.replace(/-/g, '+').replace(/_/g, '/');
  const padded = base64.padEnd(base64.length + ((4 - (base64.length % 4)) % 4), '=');
  // atob dă latin1; trecem prin UTF-8 ca payload-urile cu diacritice
  // (ex. numele userului) să nu se corupă.
  const binary = atob(padded);
  const bytes = Uint8Array.from(binary, (c) => c.charCodeAt(0));
  return new TextDecoder().decode(bytes);
}

/**
 * Mesajul de eroare al backendului. NestJS întoarce `message` fie ca string,
 * fie ca listă (erorile de validare din class-validator).
 */
function extractMessage(data: unknown): string {
  if (data && typeof data === 'object' && 'message' in data) {
    const message = (data as { message: unknown }).message;
    if (Array.isArray(message)) return message.join(', ');
    if (message != null) return String(message);
  }
  return 'A apărut o eroare. Încearcă din nou.';
}

function networkMessage(error: unknown): string {
  if (error instanceof DOMException && error.name === 'TimeoutError') {
    return 'Serverul nu a răspuns la timp. Încearcă din nou.';
  }
  return 'A apărut o eroare. Încearcă din nou.';
}

function ensureTrailingSlash(url: string): string {
  return url.endsWith('/') ? url : url + '/';
}

/** Evenimentul prin care stratul de rețea anunță UI-ul că sesiunea a picat. */
export const SESSION_EXPIRED_EVENT = 'shelfshare:session-expired';

/** Instanța folosită de aplicație. AuthProvider ascultă evenimentul de mai sus. */
export const api = new ApiClient(webTokenStorage, () => {
  window.dispatchEvent(new Event(SESSION_EXPIRED_EVENT));
});

export { webTokenStorage as tokenStorage };
