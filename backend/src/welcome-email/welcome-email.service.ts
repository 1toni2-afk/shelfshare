import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { Cron } from '@nestjs/schedule';
import { PrismaService } from '../prisma/prisma.service';
import { MailService } from '../mail/mail.service';

/** După câte zile de la înregistrare pleacă emailul de bun venit. */
const WELCOME_EMAIL_AFTER_DAYS = 3;

/**
 * Vârsta maximă a unui cont care mai poate primi emailul. A doua plasă de
 * siguranță peste backfill-ul din migrare: dacă cronul stă oprit o lună (sau
 * cineva golește coloana din greșeală), nu vrem ca la repornire să plece
 * „mulțumim că te-ai înregistrat" către conturi vechi de jumătate de an.
 * Fereastra e destul de largă cât să acopere o pană de câteva zile.
 */
const WELCOME_EMAIL_MAX_AGE_DAYS = 14;

/** Câte emailuri trimitem într-o rulare - limită de politețe față de Resend. */
const BATCH_SIZE = 200;

const DAY_MS = 24 * 60 * 60 * 1000;

/**
 * Emailul de bun venit, la 3 zile după crearea contului: mulțumire, ce se
 * poate face în aplicație și un link către formularul de feedback.
 *
 * De ce la 3 zile și nu la înregistrare: la minutul 0 userul e deja în
 * aplicație și primește oricum emailul de confirmare - un al doilea email
 * atunci e zgomot. După trei zile fie a rămas (și atunci sfaturile chiar
 * ajută), fie a plecat (și atunci e singura ocazie să-l aducem înapoi).
 *
 * Marcajul stă pe user (`welcomeEmailSentAt`), nu într-o coadă: cronul poate
 * rula de câte ori vrea, un cont primește emailul o singură dată.
 */
@Injectable()
export class WelcomeEmailService {
  private readonly logger = new Logger(WelcomeEmailService.name);

  constructor(
    private prisma: PrismaService,
    private mail: MailService,
    private config: ConfigService,
  ) {}

  /**
   * Zilnic la 10:00 (ora serverului) - o oră la care un email chiar se
   * citește, spre deosebire de rulările de noapte ale celorlalte croane.
   */
  @Cron('0 10 * * *')
  async sendDueWelcomeEmails(): Promise<void> {
    const now = Date.now();
    const due = await this.prisma.user.findMany({
      where: {
        welcomeEmailSentAt: null,
        createdAt: {
          lte: new Date(now - WELCOME_EMAIL_AFTER_DAYS * DAY_MS),
          gte: new Date(now - WELCOME_EMAIL_MAX_AGE_DAYS * DAY_MS),
        },
        // Cine și-a cerut ștergerea contului nu mai are ce face cu sfaturi
        // despre aplicație.
        deletionScheduledAt: null,
      },
      select: { id: true, email: true, name: true },
      orderBy: { createdAt: 'asc' },
      take: BATCH_SIZE,
    });

    if (due.length === 0) return;

    const appUrl = this.config.get<string>(
      'FRONTEND_URL',
      'https://shelfshare.ro',
    );
    this.logger.log(`Trimit ${due.length} emailuri de bun venit`);

    for (const user of due) {
      try {
        await this.mail.sendWelcomeTipsEmail({
          to: user.email,
          name: user.name,
          appUrl,
        });
        // Marcăm DOAR după ce Resend a acceptat emailul: dacă trimiterea pică,
        // contul rămâne în coadă pentru rularea de mâine, cât timp e încă în
        // fereastra de WELCOME_EMAIL_MAX_AGE_DAYS.
        await this.prisma.user.update({
          where: { id: user.id },
          data: { welcomeEmailSentAt: new Date() },
        });
      } catch (error) {
        // Fără adresa de email în log (vezi AccountDeletionService): id-ul e
        // suficient ca să reconstitui cazul.
        this.logger.warn(
          `Emailul de bun venit n-a plecat către userul ${user.id}: ${error}`,
        );
      }
    }
  }
}
