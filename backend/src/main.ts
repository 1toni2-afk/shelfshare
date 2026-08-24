import { NestFactory } from '@nestjs/core';
import { ValidationPipe } from '@nestjs/common';
import type { NestExpressApplication } from '@nestjs/platform-express';
import helmet from 'helmet';
import type { Request, Response, NextFunction } from 'express';
import { AppModule } from './app.module';
import { corsOrigin } from './common/utils/cors-origin';

/**
 * Lungimea minimă acceptată pentru un secret de semnare. 32 de caractere e
 * exact ce produce `openssl rand -hex 32` (recomandarea din .env.example);
 * sub atât, un secret ghicibil ar permite fabricarea de token-uri valide
 * pentru orice cont.
 */
const MIN_SECRET_LENGTH = 32;

/**
 * CaptchaService cade pe un secret public din cod dacă CAPTCHA_SECRET
 * lipsește din env - bun pentru dev local, dar în producție ar însemna că
 * oricine poate falsifica un răspuns de captcha valid (vezi captcha.service.ts).
 * Preferăm să nu pornim deloc decât să degradăm silențios o protecție
 * adăugată explicit (Milestone 17).
 *
 * Secretele JWT erau verificate doar indirect: passport aruncă la construirea
 * strategiei dacă lipsesc, deci aplicația oricum nu pornea. Ce NU prindea
 * nimeni era un secret prezent dar slab (ex. „secret", rămas dintr-un
 * .env de test) - de aceea verificăm aici și lungimea, nu doar prezența.
 */
function assertProductionSecrets() {
  if (process.env.NODE_ENV !== 'production') return;

  const missing: string[] = [];
  const tooShort: string[] = [];

  const required = [
    'CAPTCHA_SECRET',
    'JWT_ACCESS_SECRET',
    'JWT_REFRESH_SECRET',
  ] as const;

  for (const key of required) {
    const value = process.env[key];
    if (!value) {
      missing.push(key);
    } else if (key !== 'CAPTCHA_SECRET' && value.length < MIN_SECRET_LENGTH) {
      tooShort.push(key);
    }
  }

  // Două secrete identice înseamnă că un refresh token e acceptat oriunde e
  // așteptat un access token (și invers) - inclusiv acolo unde access
  // token-ul are durata scurtă tocmai ca să limiteze dauna unui token furat.
  if (
    process.env.JWT_ACCESS_SECRET &&
    process.env.JWT_ACCESS_SECRET === process.env.JWT_REFRESH_SECRET
  ) {
    tooShort.push('JWT_ACCESS_SECRET/JWT_REFRESH_SECRET (trebuie diferite)');
  }

  const problems = [
    ...missing.map((k) => `${k} lipsește`),
    ...tooShort.map(
      (k) => `${k} e prea slab (minim ${MIN_SECRET_LENGTH} caractere)`,
    ),
  ];

  if (problems.length > 0) {
    throw new Error(
      `Configurație de securitate invalidă în producție: ${problems.join('; ')}. ` +
        'Generează secrete cu `openssl rand -hex 32` și setează-le în .env.',
    );
  }
}

async function bootstrap() {
  assertProductionSecrets();
  const app = await NestFactory.create<NestExpressApplication>(AppModule);

  // Fără asta, `req.ip` e adresa tunelului Cloudflare pentru TOȚI userii -
  // vezi common/utils/client-ip.ts pentru ce strică asta (rate-limiting
  // global în loc de per-client, jurnal de securitate cu IP-ul greșit).
  //
  // O singură verigă de încredere: cloudflared. Un număr mai mare ar însemna
  // să credem pe cuvânt și hop-uri pe care nu le controlăm, deci un client
  // și-ar putea alege singur IP-ul aparent printr-un X-Forwarded-For fabricat.
  if (process.env.TRUST_PROXY === 'true') {
    app.set('trust proxy', 1);
  }

  app.use((req: Request, res: Response, next: NextFunction) => {
    // API JSON pură consumată de Flutter web - fără asta, browserul
    // cache-uiește GET-uri autentificate (ex. /profile/me) fără să țină
    // cont de header-ul Authorization, deci un login nou poate primi
    // înapoi profilul cache-uit al userului anterior de pe același browser.
    res.setHeader('Cache-Control', 'no-store');
    next();
  });

  app.use(
    helmet({
      // API JSON pură, fără pagini HTML - CSP n-are ce să constrângă aici
      // și doar ar crea confuzie; restul header-elor (HSTS, X-Frame-Options,
      // X-Content-Type-Options, Referrer-Policy) rămân active.
      contentSecurityPolicy: false,
      // Consumat de frontend-ul Flutter web de pe alt origin - politica
      // implicită "same-origin" ar bloca acel consum cross-origin.
      crossOriginResourcePolicy: { policy: 'cross-origin' },
    }),
  );

  app.useGlobalPipes(
    new ValidationPipe({
      whitelist: true,
      forbidNonWhitelisted: true,
      transform: true,
    }),
  );

  app.enableCors({
    origin: corsOrigin,
    credentials: true,
  });

  await app.listen(process.env.PORT ?? 3000);
}
bootstrap().catch((error) => {
  console.error('Eroare la pornirea aplicației:', error);
  process.exit(1);
});
