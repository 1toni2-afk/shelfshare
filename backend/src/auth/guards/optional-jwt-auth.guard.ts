import { Injectable } from '@nestjs/common';
import { AuthGuard } from '@nestjs/passport';

/** Populează req.user dacă tokenul e valid, dar nu respinge cererea când lipsește/e invalid. */
@Injectable()
export class OptionalJwtAuthGuard extends AuthGuard('jwt') {
  handleRequest<TUser = unknown>(err: unknown, user: TUser): TUser {
    return user;
  }
}
