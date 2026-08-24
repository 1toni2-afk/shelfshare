import type { Request } from 'express';

/**
 * IP-ul real al clientului, nu al proxy-ului din față.
 *
 * În producție API-ul stă în spatele Cloudflare Tunnel
 * (api.shelfshare.ro -> cloudflared -> 127.0.0.1:3000), deci socket-ul care
 * ajunge la Express aparține MEREU tunelului. Fără `trust proxy` (vezi
 * main.ts), `req.ip` era același pentru toți userii, cu două consecințe:
 *
 *  1. Rate-limiting-ul se prăbușea într-o singură găleată globală -
 *     `@Throttle({ limit: 10 })` pe /auth/login nu însemna 10 încercări per
 *     atacator, ci 10 pe tot site-ul: un singur client putea consuma limita
 *     și bloca login-ul pentru toată lumea, fără ca el să fie încetinit
 *     individual.
 *  2. `SecurityEvent` (LOGIN_FAILED, ACCOUNT_LOCKED, PASSWORD_RESET) înregistra
 *     IP-ul tunelului, deci jurnalul de securitate nu putea spune de unde a
 *     venit un atac - exact informația pentru care există.
 *
 * `CF-Connecting-IP` e pus de Cloudflare și e mai de încredere decât ultimul
 * hop din `X-Forwarded-For`, dar oricine poate falsifica ambele header-e dacă
 * ajunge direct la aplicație. De aceea îl citim doar când `TRUST_PROXY` e
 * activ, iar portul e publicat exclusiv pe loopback
 * (`127.0.0.1:3000:3000` în docker-compose.prod.yml), ca singura cale de
 * intrare să fie tunelul.
 */
export function clientIp(req: Request): string {
  if (process.env.TRUST_PROXY === 'true') {
    const cfIp = req.headers['cf-connecting-ip'];
    if (typeof cfIp === 'string' && cfIp.length > 0) {
      return cfIp;
    }
  }
  // Cu `trust proxy` setat, Express rezolvă deja `req.ip` din X-Forwarded-For.
  return req.ip ?? '';
}
