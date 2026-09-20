import { useCallback, useSyncExternalStore } from 'react';

export type ThemeMode = 'light' | 'dark' | 'system';

/** Aceeași cheie pe care o citește scriptul inline din index.html. */
const STORAGE_KEY = 'shelfshare.theme';

const listeners = new Set<() => void>();
let mode: ThemeMode = readStoredMode();

function readStoredMode(): ThemeMode {
  try {
    const value = window.localStorage.getItem(STORAGE_KEY);
    if (value === 'light' || value === 'dark') return value;
  } catch {
    /* storage blocat */
  }
  return 'system';
}

function prefersDark(): boolean {
  return window.matchMedia('(prefers-color-scheme: dark)').matches;
}

export function isDark(current: ThemeMode = mode): boolean {
  return current === 'dark' || (current === 'system' && prefersDark());
}

function apply(): void {
  document.documentElement.setAttribute('data-theme', isDark() ? 'dark' : 'light');
  // Bara de sistem pe Android/iOS urmărește theme-color, nu CSS-ul paginii.
  // Fără linia asta, în dark mode bara de sus rămânea maro-deschis peste un
  // fundal aproape negru.
  document
    .querySelector('meta[name="theme-color"]')
    ?.setAttribute('content', isDark() ? '#0E0E0F' : '#7C3A1E');
  for (const listener of listeners) listener();
}

export function setThemeMode(next: ThemeMode): void {
  mode = next;
  try {
    if (next === 'system') window.localStorage.removeItem(STORAGE_KEY);
    else window.localStorage.setItem(STORAGE_KEY, next);
  } catch {
    /* storage blocat - alegerea ține doar cât sesiunea */
  }
  apply();
}

// Când userul e pe "system" și schimbă tema din sistemul de operare, pagina
// trebuie să urmeze fără reload.
window.matchMedia('(prefers-color-scheme: dark)').addEventListener('change', () => {
  if (mode === 'system') apply();
});

apply();

function subscribe(listener: () => void): () => void {
  listeners.add(listener);
  return () => listeners.delete(listener);
}

export function useTheme() {
  const current = useSyncExternalStore(
    subscribe,
    () => mode,
    () => 'system' as ThemeMode,
  );
  const dark = useSyncExternalStore(
    subscribe,
    () => isDark(mode),
    () => false,
  );
  const toggle = useCallback(() => setThemeMode(isDark() ? 'light' : 'dark'), []);
  return { mode: current, dark, setMode: setThemeMode, toggle };
}
