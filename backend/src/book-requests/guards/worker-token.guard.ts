import {
  CanActivate,
  ExecutionContext,
  Injectable,
  UnauthorizedException,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import type { Request } from 'express';
import { createHash, timingSafeEqual } from 'crypto';

/**
 * Poarta prin care intră scraperele de magazine (rulează pe gazdă, în Python,
 * nu în container - vezi scripts/book-requests/nightly_book_requests.py). Nu
 * pot folosi JWT-ul de user: nu sunt un user, iar un cont de serviciu cu
 * parolă ar fi un cont în plus de păzit. Un singur secret din mediu,
 * `BOOK_REQUEST_WORKER_TOKEN`, trimis în antetul `x-worker-token`.
 *
 * Fără secretul setat, rutele sunt ÎNCHISE - nu deschise. Un deploy care uită
 * variabila trebuie să pice cererile scriptului, nu să lase pe oricine să
 * scrie în catalog.
 */
@Injectable()
export class WorkerTokenGuard implements CanActivate {
  constructor(private config: ConfigService) {}

  canActivate(context: ExecutionContext): boolean {
    const expected = this.config.get<string>('BOOK_REQUEST_WORKER_TOKEN');
    if (!expected) {
      throw new UnauthorizedException('Worker-ul de cereri nu e configurat');
    }

    const request = context.switchToHttp().getRequest<Request>();
    const header = request.headers['x-worker-token'];
    const provided = Array.isArray(header) ? header[0] : header;
    if (!provided) throw new UnauthorizedException('Token lipsă');

    // Comparație în timp constant pe hash-uri, ca lungimile diferite să nu
    // arunce (timingSafeEqual cere buffere egale) și ca un atacator să nu
    // poată ghici tokenul octet cu octet, măsurând timpul răspunsului.
    const digest = (value: string) => createHash('sha256').update(value).digest();
    if (!timingSafeEqual(digest(provided), digest(expected))) {
      throw new UnauthorizedException('Token invalid');
    }
    return true;
  }
}
