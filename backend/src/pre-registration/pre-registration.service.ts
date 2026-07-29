import { BadRequestException, Injectable } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';

@Injectable()
export class PreRegistrationService {
  constructor(private prisma: PrismaService) {}

  /**
   * Adaugă un email la lista de pre-înscriere. Idempotent: dacă email-ul e
   * deja pre-înscris, întoarce success fără a arunca (userul care încearcă
   * să se re-înscrie e feedback ok, nu eroare). Dedup e case-insensitive
   * via `emailLower`.
   */
  async register(email: string, userId?: string): Promise<void> {
    const trimmed = email.trim();
    if (!trimmed || !trimmed.includes('@') || trimmed.length > 254) {
      throw new BadRequestException('Email invalid');
    }
    const emailLower = trimmed.toLowerCase();
    await this.prisma.preRegistration.upsert({
      where: { emailLower },
      update: { userId: userId ?? undefined },
      create: { email: trimmed, emailLower, userId },
    });
  }
}
