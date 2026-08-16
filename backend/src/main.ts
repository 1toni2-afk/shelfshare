import { NestFactory } from '@nestjs/core';
import { ValidationPipe } from '@nestjs/common';
import helmet from 'helmet';
import type { Request, Response, NextFunction } from 'express';
import { AppModule } from './app.module';
import { corsOrigin } from './common/utils/cors-origin';

/**
 * CaptchaService cade pe un secret public din cod dacă CAPTCHA_SECRET
 * lipsește din env - bun pentru dev local, dar în producție ar însemna că
 * oricine poate falsifica un răspuns de captcha valid (vezi captcha.service.ts).
 * Preferăm să nu pornim deloc decât să degradăm silențios o protecție
 * adăugată explicit (Milestone 17).
 */
function assertProductionSecrets() {
  if (process.env.NODE_ENV !== 'production') return;

  const missing: string[] = [];
  if (!process.env.CAPTCHA_SECRET) missing.push('CAPTCHA_SECRET');

  if (missing.length > 0) {
    throw new Error(
      `Lipsesc variabile de mediu obligatorii în producție: ${missing.join(', ')}. ` +
        'Setează-le în .env înainte de a porni serverul.',
    );
  }
}

async function bootstrap() {
  assertProductionSecrets();
  const app = await NestFactory.create(AppModule);

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
