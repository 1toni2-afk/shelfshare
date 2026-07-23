import { ExecutionContext, Injectable } from '@nestjs/common';
import { AuthGuard } from '@nestjs/passport';
import { PrismaService } from '../../prisma/prisma.service';

const ACTIVITY_THROTTLE_MS = 5 * 60 * 1000;

@Injectable()
export class JwtAuthGuard extends AuthGuard('jwt') {
  // Static (per proces, nu per request) - o singură instanță de throttle
  // pentru tot backend-ul, ca "Last Active"/streak-ul să nu scrie în DB la
  // fiecare cerere autentificată (ar fi zeci pe minut per user activ).
  private static lastTouched = new Map<string, number>();

  constructor(private prisma: PrismaService) {
    super();
  }

  handleRequest(err: unknown, user: unknown, info: unknown, context: ExecutionContext) {
    const userId = (user as { userId?: string } | null)?.userId;
    if (userId) {
      this.touchActivity(userId);
    }
    return super.handleRequest(err, user, info, context);
  }

  private touchActivity(userId: string) {
    const now = Date.now();
    const last = JwtAuthGuard.lastTouched.get(userId) ?? 0;
    if (now - last < ACTIVITY_THROTTLE_MS) return;
    JwtAuthGuard.lastTouched.set(userId, now);
    this.updateActivityAndStreak(userId).catch(() => {});
  }

  /**
   * Reading Streak - zile CALENDARISTICE consecutive cu activitate, nu o
   * fereastră glisantă de 24h (altfel te-ar penaliza dacă intri la 23:00 și
   * apoi la 08:00 a doua zi, deși ai fost activ în 2 zile diferite).
   */
  private async updateActivityAndStreak(userId: string) {
    const user = await this.prisma.user.findUnique({
      where: { id: userId },
      select: { lastStreakDate: true, currentStreakDays: true, longestStreakDays: true },
    });
    if (!user) return;

    const today = startOfDay(new Date());
    const lastDay = user.lastStreakDate ? startOfDay(user.lastStreakDate) : null;
    const dayDiff = lastDay ? Math.round((today.getTime() - lastDay.getTime()) / 86_400_000) : null;

    let currentStreakDays = user.currentStreakDays;
    if (dayDiff === null || dayDiff > 1) {
      currentStreakDays = 1;
    } else if (dayDiff === 1) {
      currentStreakDays = user.currentStreakDays + 1;
    } // dayDiff === 0: deja activ azi, streak-ul nu se schimbă

    const longestStreakDays = Math.max(user.longestStreakDays, currentStreakDays);

    await this.prisma.user.update({
      where: { id: userId },
      data: {
        lastActiveAt: new Date(),
        ...(dayDiff !== 0 ? { currentStreakDays, longestStreakDays, lastStreakDate: today } : {}),
      },
    });
  }
}

function startOfDay(date: Date): Date {
  return new Date(Date.UTC(date.getUTCFullYear(), date.getUTCMonth(), date.getUTCDate()));
}
