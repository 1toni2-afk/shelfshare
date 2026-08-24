import { ConfigService } from '@nestjs/config';
import type { Request } from 'express';
import { JwtStrategy } from './jwt.strategy';
import { RevokedTokenService } from '../../common/security/revoked-token.service';

/**
 * Un access token pus în URL ajunge în jurnalele Cloudflare, în istoricul
 * browserului și în header-ul `Referer` trimis către terți - de acolo poate fi
 * luat și refolosit. Îl acceptăm doar pe cele două descărcări `.ics`, care
 * sunt deschise direct de browser și deci nu pot trimite un header
 * `Authorization`. Testul ăsta ține suprafața aia închisă: e o singură linie
 * de reactivat din greșeală, fără niciun simptom vizibil.
 */
describe('JwtStrategy - extragerea token-ului', () => {
  const config = new ConfigService({ JWT_ACCESS_SECRET: 'x'.repeat(32) });
  const strategy = new JwtStrategy(config, new RevokedTokenService());

  // `jwtFromRequest` e ținut de passport-jwt pe instanță, sub `_jwtFromRequest`.
  const extract = (req: Partial<Request>): string | null =>
    (
      strategy as unknown as {
        _jwtFromRequest: (r: Partial<Request>) => string | null;
      }
    )._jwtFromRequest(req);

  // passport-jwt își parsează singur `request.url` (nu citește `req.query`),
  // deci mock-ul trebuie să poarte query string-ul acolo. În Express real,
  // `req.path` e derivat din `req.url`, deci cele două rămân consistente.
  const withQueryToken = (path: string): Partial<Request> => ({
    path,
    url: `${path}?token=token-din-url`,
    query: { token: 'token-din-url' },
    headers: {},
    get: () => undefined,
  });

  it('acceptă ?token= pe descărcarea .ics a unui schimb', () => {
    expect(extract(withQueryToken('/exchanges/abc/calendar.ics'))).toBe(
      'token-din-url',
    );
  });

  it('acceptă ?token= pe descărcarea .ics a unei vânzări', () => {
    expect(extract(withQueryToken('/offers/abc/calendar.ics'))).toBe(
      'token-din-url',
    );
  });

  it.each([
    '/profile/me',
    '/conversations',
    '/admin/users',
    // Sufixul trebuie să fie chiar segmentul final - nu doar să apară pe undeva.
    '/exchanges/calendar.ics/altceva',
  ])('ignoră ?token= pe %s', (path) => {
    expect(extract(withQueryToken(path))).toBeNull();
  });

  it('acceptă în continuare header-ul Authorization pe rutele normale', () => {
    expect(
      extract({
        path: '/profile/me',
        query: {},
        headers: { authorization: 'Bearer token-din-header' },
        get: (name: string) =>
          name.toLowerCase() === 'authorization'
            ? 'Bearer token-din-header'
            : undefined,
      } as unknown as Partial<Request>),
    ).toBe('token-din-header');
  });
});
