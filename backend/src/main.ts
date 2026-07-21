import { NestFactory } from '@nestjs/core';
import { ValidationPipe } from '@nestjs/common';
import { AppModule } from './app.module';

type CorsOriginCallback = (err: Error | null, allow?: boolean) => void;

function corsOrigin(
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

async function bootstrap() {
  const app = await NestFactory.create(AppModule);

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
