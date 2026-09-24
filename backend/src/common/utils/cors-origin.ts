export type CorsOriginCallback = (err: Error | null, allow?: boolean) => void;

/**
 * Shared CORS origin policy for both the HTTP server (main.ts) and the
 * chat WebSocket gateway (chat.gateway.ts) - the socket used to allow any
 * origin (`origin: '*'`), inconsistent with the strict HTTP policy.
 */
export function corsOrigin(
  origin: string | undefined,
  callback: CorsOriginCallback,
): void {
  if (!origin) {
    callback(null, true);
    return;
  }

  // PUBLIC_HOSTNAME e verificat indiferent de mediu - altfel un domeniu
  // public setat pentru producție era ignorat de ramura de mai jos.
  const isPublicHostname = matchesPublicHostname(origin);

  if (process.env.NODE_ENV === 'production') {
    const allowed = process.env.FRONTEND_URL ?? 'http://localhost:8080';
    callback(null, origin === allowed || isPublicHostname);
    return;
  }

  const isLocalhost = /^https?:\/\/(localhost|127\.0\.0\.1):\d+$/.test(origin);
  callback(null, isLocalhost || isPublicHostname);
}

/**
 * `PUBLIC_HOSTNAME` acceptă MAI MULTE gazde, separate prin virgulă.
 *
 * Era o singură valoare, ceea ce forța o alegere între ele: mediul de test e
 * accesat și prin Tailscale (de pe telefon), și prin `beta.shelfshare.ro`
 * (frontendul nou), iar cu un singur nume unul dintre cele două rămânea
 * blocat de CORS - inclusiv socketul de chat, care folosește aceeași funcție.
 *
 * O singură valoare, fără virgulă, se comportă exact ca înainte.
 */
function matchesPublicHostname(origin: string): boolean {
  const configured = process.env.PUBLIC_HOSTNAME;
  if (!configured) return false;

  return configured
    .split(',')
    .map((hostname) => hostname.trim())
    .filter((hostname) => hostname.length > 0)
    .some((hostname) =>
      new RegExp(
        `^https?://(www\\.)?${hostname.replace(/\./g, '\\.')}(:\\d+)?$`,
      ).test(origin),
    );
}
