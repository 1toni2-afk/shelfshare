import { Injectable } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { User } from '@prisma/client';
import * as crypto from 'crypto';

const REFERRAL_CODE_LENGTH = 8;

@Injectable()
export class UsersService {
  constructor(private prisma: PrismaService) {}

  /**
   * Căutarea normalizează la litere mici, iar `create` stochează la fel - deci
   * adresele se compară case-insensitive fără să fie nevoie de un index
   * funcțional sau de `mode: 'insensitive'`.
   *
   * Fără asta, login-ul era sensibil la majuscule: tastaturile de Android scriu
   * automat prima literă cu majusculă, așa că un user care își tasta adresa pe
   * telefon trimitea „Ion@exemplu.ro" și primea „Email sau parolă incorectă",
   * fără să înțeleagă de ce. Partea de domeniu e case-insensitive prin
   * standard, iar toți furnizorii mari tratează și partea locală la fel.
   */
  findByEmail(email: string): Promise<User | null> {
    return this.prisma.user.findUnique({
      where: { email: email.trim().toLowerCase() },
    });
  }

  findById(id: string): Promise<User | null> {
    return this.prisma.user.findUnique({ where: { id } });
  }

  findByGoogleId(googleId: string): Promise<User | null> {
    return this.prisma.user.findUnique({ where: { googleId } });
  }

  findByReferralCode(code: string): Promise<User | null> {
    return this.prisma.user.findUnique({ where: { referralCode: code } });
  }

  /** Cod scurt, unic, ușor de dictat/tastat manual - reîncearcă la coliziune (foarte rar la 8 caractere). */
  private async generateReferralCode(): Promise<string> {
    for (;;) {
      const code = crypto
        .randomBytes(REFERRAL_CODE_LENGTH)
        .toString('hex')
        .toUpperCase()
        .slice(0, REFERRAL_CODE_LENGTH);
      const exists = await this.prisma.user.findUnique({
        where: { referralCode: code },
      });
      if (!exists) return code;
    }
  }

  async create(data: {
    email: string;
    password?: string;
    googleId?: string;
    isEmailVerified?: boolean;
    invitedById?: string;
  }): Promise<User> {
    const referralCode = await this.generateReferralCode();
    // Stocăm mereu cu litere mici, ca `findByEmail` (care normalizează la fel)
    // să găsească contul indiferent cum a fost tastată adresa la înregistrare.
    return this.prisma.user.create({
      data: { ...data, email: data.email.trim().toLowerCase(), referralCode },
    });
  }

  update(id: string, data: Partial<User>): Promise<User> {
    return this.prisma.user.update({ where: { id }, data });
  }
}
