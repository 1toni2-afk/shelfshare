import { NestFactory } from '@nestjs/core';
import { ValidationPipe } from '@nestjs/common';
import { AppModule } from './app.module';

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
    origin: (
      origin: string | undefined,
      callback: (err: Error | null, allow?: boolean) => void,
    ) => {
      if (!origin) return callback(null, true);

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
        return callback(null, origin === allowed || isPublicHostname);
      }

      const isLocalhost = /^https?:\/\/(localhost|127\.0\.0\.1):\d+$/.test(
        origin,
      );

      callback(null, isLocalhost || isPublicHostname);
    },
    credentials: true,
  });

  await app.listen(process.env.PORT ?? 3000);
}
bootstrap().catch((error) => {
  console.error('Eroare la pornirea aplicației:', error);
  process.exit(1);
});
