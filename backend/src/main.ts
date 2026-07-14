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

  if (process.env.NODE_ENV === 'production') {
    const allowed = process.env.FRONTEND_URL ?? 'http://localhost:8080';
    callback(null, origin === allowed);
    return;
  }

  const isLocalhost = /^https?:\/\/(localhost|127\.0\.0\.1):\d+$/.test(origin);
  callback(null, isLocalhost);
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
