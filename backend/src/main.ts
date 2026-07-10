import './types/express';
import { NestFactory } from '@nestjs/core';
import { ValidationPipe } from '@nestjs/common';
import { AppModule } from './app.module';

async function bootstrap() {
  const app = await NestFactory.create(AppModule);

  app.useGlobalPipes(
    new ValidationPipe({
      whitelist: true, // elimină automat câmpurile care nu sunt în DTO
      forbidNonWhitelisted: true, // respinge request-uri cu câmpuri în plus
      transform: true, // transformă payload-ul în instanța DTO
    }),
  );

  app.enableCors({
    origin: process.env.FRONTEND_URL ?? 'http://localhost:8080',
    credentials: true,
  });

  await app.listen(process.env.PORT ?? 3000);
}
bootstrap().catch((error) => {
  console.error('Eroare la pornirea aplicației:', error);
  process.exit(1);
});
