import { Injectable } from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';
import { RealtimeService } from '../realtime/realtime.service';
import { RevokedTokenService } from './revoked-token.service';

/**
 * Deconectarea unui user de peste tot: sesiunile de refresh, token-urile de
 * acces deja emise și socket-urile de chat deschise.
 *
 * Folosit la ban și la resetarea parolei - exact momentele în care cineva
 * poate avea în mână o sesiune care nu mai trebuie să meargă. Înainte, ban-ul
 * golea doar `refreshTokenHash`, iar userul se putea pur și simplu autentifica
 * din nou; resetul de parolă nu atingea token-urile de acces.
 */
@Injectable()
export class UserSessionsService {
  constructor(
    private prisma: PrismaService,
    private revokedTokens: RevokedTokenService,
    private realtime: RealtimeService,
  ) {}

  async revokeAll(userId: string) {
    await this.prisma.$transaction([
      this.prisma.refreshSession.deleteMany({ where: { userId } }),
      this.prisma.user.update({
        where: { id: userId },
        data: { refreshTokenHash: null },
      }),
    ]);
    this.revokedTokens.revokeAllForUser(userId);
    this.realtime.disconnectUser(userId);
  }
}
