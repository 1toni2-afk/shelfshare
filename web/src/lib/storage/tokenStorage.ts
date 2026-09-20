/**
 * Stocarea token-urilor, izolată în spatele unei interfețe asincrone.
 *
 * Pe web nu există echivalent real pentru keychain/keystore - localStorage e
 * ce avem. Interfața e totuși `Promise`, chiar dacă implementarea de acum e
 * sincronă: pe Android/iOS (Capacitor) va fi înlocuită cu un plugin de secure
 * storage, care e inerent asincron. Dacă am expune-o sincron acum, fiecare
 * apelant ar trebui rescris atunci.
 */
export interface TokenStorage {
  getAccessToken(): Promise<string | null>;
  getRefreshToken(): Promise<string | null>;
  saveTokens(tokens: { accessToken: string; refreshToken: string }): Promise<void>;
  clear(): Promise<void>;
}

const ACCESS_KEY = 'shelfshare.access_token';
const REFRESH_KEY = 'shelfshare.refresh_token';

/**
 * Fiecare acces e într-un try/catch: în incognito cu cookies blocate,
 * `localStorage` nu întoarce null, ci ARUNCĂ la citire. Fără protecție aici,
 * aplicația cădea cu ecran alb înainte să apuce să randeze login-ul.
 */
function safeRead(key: string): string | null {
  try {
    return window.localStorage.getItem(key);
  } catch {
    return null;
  }
}

function safeWrite(key: string, value: string): void {
  try {
    window.localStorage.setItem(key, value);
  } catch {
    /* sesiune fără storage - userul rămâne logat doar până la refresh */
  }
}

function safeRemove(key: string): void {
  try {
    window.localStorage.removeItem(key);
  } catch {
    /* nimic de curățat dacă n-am putut nici scrie */
  }
}

export const webTokenStorage: TokenStorage = {
  async getAccessToken() {
    return safeRead(ACCESS_KEY);
  },
  async getRefreshToken() {
    return safeRead(REFRESH_KEY);
  },
  async saveTokens({ accessToken, refreshToken }) {
    safeWrite(ACCESS_KEY, accessToken);
    safeWrite(REFRESH_KEY, refreshToken);
  },
  async clear() {
    safeRemove(ACCESS_KEY);
    safeRemove(REFRESH_KEY);
  },
};
