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
  const publicHostname = process.env.PUBLIC_HOSTNAME;
  const isPublicHostname = publicHostname
    ? new RegExp(
        `^https?://(www\\.)?${publicHostname.replace(/\./g, '\\.')}(:\\d+)?$`,
      ).test(origin)
    : false;

  if (process.env.NODE_ENV === 'production') {
    const allowed = process.env.FRONTEND_URL ?? 'http://localhost:8080';
    callback(null, origin === allowed || isPublicHostname);
    return;
  }

  const isLocalhost = /^https?:\/\/(localhost|127\.0\.0\.1):\d+$/.test(origin);
  callback(null, isLocalhost || isPublicHostname);
}
