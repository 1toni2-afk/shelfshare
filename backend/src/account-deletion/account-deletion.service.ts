import {
  BadRequestException,
  Injectable,
  Logger,
  NotFoundException,
} from '@nestjs/common';
import { Cron, CronExpression } from '@nestjs/schedule';
import { PrismaService } from '../prisma/prisma.service';

/// Fereastra de „cooling off": userul poate anula oricând în acest interval
/// (afișăm un banner la fiecare login). Cerință Google Play: minim 30 zile
/// pentru „request removal", dar pentru ștergere efectivă orientările spun
/// „reasonable time" - alegem 15 zile ca să încapă între abandonul emoțional
/// (o zi-două) și limita practică peste care userii uită complet de cont.
export const DELETION_GRACE_PERIOD_DAYS = 15;

/// Doar pentru testare locală/self-hosted - NICIODATĂ pentru producție cu
/// useri reali. Ocolește complet fereastra de 15 zile (cerută de Google
/// Play/GDPR - vezi comentariul de mai sus) și șterge contul definitiv pe
/// loc, din același request pe care userul îl face apăsând „Șterge contul"
/// din Settings. Implicit OFF (vezi `.env.example`); se activează explicit
/// din variabila de mediu `INSTANT_ACCOUNT_DELETION=true` pe mașina ta -
/// oprește-o la loc după ce ai terminat testarea onboardingului, altfel
/// orice user real care cere ștergerea își pierde definitiv datele instant,
/// fără nicio fereastră de anulare.
const INSTANT_DELETION_FOR_TESTING =
  process.env.INSTANT_ACCOUNT_DELETION === 'true';

@Injectable()
export class AccountDeletionService {
  private readonly logger = new Logger(AccountDeletionService.name);

  constructor(private prisma: PrismaService) {}

  async requestDeletion(
    userId: string,
  ): Promise<{ scheduledFor: Date; immediate: boolean }> {
    const user = await this.prisma.user.findUnique({ where: { id: userId } });
    if (!user) {
      throw new NotFoundException('Utilizator negăsit');
    }
    if (user.deletionScheduledAt) {
      throw new BadRequestException(
        'Ștergerea contului este deja programată. Anuleaz-o mai întâi dacă vrei să reprogramezi.',
      );
    }

    if (INSTANT_DELETION_FOR_TESTING) {
      await this.prisma.user.delete({ where: { id: userId } });
      // Doar ID-ul, nu și emailul: contul tocmai a fost șters, dar un email
      // scris în log îi supraviețuiește cât ține retenția log-urilor - exact
      // datele pe care ștergerea trebuia să le facă să dispară. ID-ul e
      // suficient pentru a corela cu SecurityEvent la o investigație.
      this.logger.warn(
        `[INSTANT_ACCOUNT_DELETION=true] Cont șters pe loc (fără grace period): ${userId}`,
      );
      return { scheduledFor: new Date(), immediate: true };
    }

    const scheduledFor = new Date(
      Date.now() + DELETION_GRACE_PERIOD_DAYS * 24 * 60 * 60 * 1000,
    );
    await this.prisma.user.update({
      where: { id: userId },
      data: { deletionScheduledAt: scheduledFor },
    });

    this.logger.log(
      `Ștergere programată pentru user ${userId} la ${scheduledFor.toISOString()}`,
    );
    return { scheduledFor, immediate: false };
  }

  /**
   * GDPR "dreptul de acces/portabilitate" - exportă datele proprii ale
   * userului ca JSON. Folosim `select` explicit (nu `include` de pe User)
   * ca să nu riscăm să scurgem vreodată parola/hash-urile/token-urile prin
   * adăugarea neatentă a unui câmp nou pe model.
   */
  async exportMyData(userId: string) {
    const user = await this.prisma.user.findUnique({
      where: { id: userId },
      select: {
        id: true,
        email: true,
        name: true,
        username: true,
        city: true,
        bio: true,
        profileImage: true,
        isEmailVerified: true,
        rating: true,
        booksExchangedCount: true,
        booksSharedCount: true,
        booksReceivedCount: true,
        avgCommunicationRating: true,
        avgPunctualityRating: true,
        avgConditionRating: true,
        xp: true,
        currentStreakDays: true,
        longestStreakDays: true,
        isPremium: true,
        supporterSince: true,
        birthdayDay: true,
        birthdayMonth: true,
        languages: true,
        referralCode: true,
        createdAt: true,
        updatedAt: true,

        userBooks: { include: { book: true } },
        sentExchangeRequests: true,
        receivedExchangeRequests: true,
        offersMade: true,
        offersReceived: true,
        messagesSent: true,
        wishlistItems: { include: { book: true } },
        bookshelfEntries: { include: { book: true } },
        auctionBids: true,
        auctionsWon: true,
        collections: { include: { items: true } },
        groupMemberships: true,
        groupPosts: true,
        feedback: true,
        securityEvents: { orderBy: { createdAt: 'desc' }, take: 200 },
      },
    });

    if (!user) {
      throw new NotFoundException('Utilizator negăsit');
    }

    return { exportedAt: new Date().toISOString(), data: user };
  }

  async cancelDeletion(userId: string): Promise<void> {
    const user = await this.prisma.user.findUnique({ where: { id: userId } });
    if (!user) {
      throw new NotFoundException('Utilizator negăsit');
    }
    if (!user.deletionScheduledAt) {
      // Idempotent - nu aruncă, ca UI-ul să poată apela fără să știe starea
      // curentă (ex. dacă banner-ul a rămas afișat după refresh).
      return;
    }

    await this.prisma.user.update({
      where: { id: userId },
      data: { deletionScheduledAt: null },
    });
    this.logger.log(`Ștergere anulată pentru user ${userId}`);
  }

  /// Rulează zilnic la 03:00 (server time) - șterge conturile a căror
  /// fereastră a expirat. Cascade din schema.prisma se ocupă de datele
  /// relaționate (user_books, exchange_requests, messages, etc.). Rulează
  /// individual per user ca o eroare pe unul singur să nu blocheze restul.
  @Cron(CronExpression.EVERY_DAY_AT_3AM)
  async purgeExpiredAccounts(): Promise<void> {
    const now = new Date();
    const expired = await this.prisma.user.findMany({
      where: { deletionScheduledAt: { lte: now } },
      select: { id: true },
    });

    if (expired.length === 0) {
      return;
    }

    this.logger.log(`Șterg ${expired.length} conturi expirate`);
    for (const user of expired) {
      try {
        await this.prisma.user.delete({ where: { id: user.id } });
        // Fără email în log - vezi comentariul din scheduleDeletion.
        this.logger.log(`Cont șters: ${user.id}`);
      } catch (error) {
        this.logger.error(`Nu am putut șterge contul ${user.id}`, error);
      }
    }
  }
}
