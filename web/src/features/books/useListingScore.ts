import { useEffect, useSyncExternalStore } from 'react';
import { booksRepository } from './booksRepository';

/**
 * Cache partajat pentru scorurile de anunț, cu cerere GRUPATĂ.
 *
 * Fiecare card cere scorul lui, dar cererile nu pleacă una câte una: se strâng
 * 30 ms și pleacă într-un singur POST. O grilă de discover are 20-30 de carduri
 * care se montează în același frame - fără gruparea asta ar fi 30 de dus-întors
 * la fiecare derulare.
 *
 * E un store în afara React, nu un query per card: React Query ar face o
 * intrare de cache per id și tot n-ar putea grupa cererile.
 */
const scores = new Map<string, number | null>();
const pending = new Set<string>();
const listeners = new Set<() => void>();
let timer: number | undefined;

/** Limita backendului (ArrayMaxSize(100)) - trimitem în tranșe, nu tot. */
const MAX_BATCH = 100;

function notify() {
  for (const listener of listeners) listener();
}

async function flush() {
  const ids = [...pending];
  pending.clear();
  if (ids.length === 0) return;

  for (let i = 0; i < ids.length; i += MAX_BATCH) {
    const batch = ids.slice(i, i + MAX_BATCH);
    try {
      const result = await booksRepository.getListingScores(batch);
      for (const id of batch) {
        // `null` explicit pentru un anunț fără scor: fără el, id-ul ar rămâne
        // în afara hărții și fiecare randare l-ar cere din nou, la nesfârșit.
        scores.set(id, result[id] ?? null);
      }
    } catch {
      // Scorul e un ajutor de moderare, nu conținut. Un eșec nu trebuie să
      // rupă cardul; marcăm ca „fără scor" ca să nu reintre în coadă.
      for (const id of batch) scores.set(id, null);
    }
  }
  notify();
}

function request(userBookId: string) {
  if (scores.has(userBookId) || pending.has(userBookId)) return;
  pending.add(userBookId);
  window.clearTimeout(timer);
  timer = window.setTimeout(() => void flush(), 30);
}

function subscribe(listener: () => void): () => void {
  listeners.add(listener);
  return () => listeners.delete(listener);
}

/** Golește cache-ul la schimbarea de cont - scorurile depind de cine întreabă. */
export function clearListingScores(): void {
  scores.clear();
  pending.clear();
  notify();
}

/**
 * Scorul unui anunț, sau `null` cât timp se încarcă / dacă nu există.
 * `enabled` false nu cere nimic - badge-ul e doar pentru admini.
 */
export function useListingScore(userBookId: string, enabled: boolean): number | null {
  useEffect(() => {
    if (enabled) request(userBookId);
  }, [userBookId, enabled]);

  return useSyncExternalStore(
    subscribe,
    () => (enabled ? (scores.get(userBookId) ?? null) : null),
    () => null,
  );
}
