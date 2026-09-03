import { BadRequestException, Injectable, Logger } from '@nestjs/common';
import { Prisma, ReportReason, ReportTargetType } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import {
  AUTO_HIDEABLE_TARGETS,
  AUTO_HIDE_RULES,
  LEGACY_UNIVERSAL_REASONS,
  REPORT_REASONS_BY_TARGET,
} from './reports.constants';

/**
 * Un raport, așa cum îl trimite oricare dintre locurile care raportează
 * (safety / chat / grupuri / recenzii). Cheia străină tipată se dă separat de
 * (targetType, targetId), fiindcă `Report` le păstrează pe amândouă - vezi
 * comentariul de pe model în schema.prisma.
 */
export interface CreateReportInput {
  reporterId: string;
  /** Cine e ținut responsabil - autorul conținutului, sau userul raportat. */
  reportedUserId: string;
  targetType: ReportTargetType;
  targetId: string;
  reason: ReportReason;
  details?: string | null;
  /** Restul câmpurilor de pe Report (userBookId, reviewId, transcriptPath...). */
  extra?: Omit<
    Prisma.ReportUncheckedCreateInput,
    | 'id'
    | 'reporterId'
    | 'reportedUserId'
    | 'targetType'
    | 'targetId'
    | 'reason'
    | 'details'
  >;
}

/**
 * Singurul loc din aplicație care creează rapoarte.
 *
 * Înainte, fiecare funcție își scria singură rândul în `reports` cu cheia
 * străină proprie - deci regulile care trebuie să fie aceleași peste tot
 * (un raport per user per țintă, praguri de auto-ascundere, ce motive sunt
 * valide pentru ce tip de țintă) nu existau nicăieri sau ar fi trebuit
 * repetate în patru locuri.
 */
@Injectable()
export class ReportsService {
  private readonly logger = new Logger(ReportsService.name);

  constructor(private prisma: PrismaService) {}

  async create(input: CreateReportInput) {
    if (input.reporterId === input.reportedUserId) {
      throw new BadRequestException('Nu te poți raporta pe tine însuți');
    }

    const allowed = REPORT_REASONS_BY_TARGET[input.targetType];
    if (
      !allowed.includes(input.reason) &&
      !LEGACY_UNIVERSAL_REASONS.includes(input.reason)
    ) {
      throw new BadRequestException(
        'Motivul ales nu se potrivește cu ce raportezi',
      );
    }

    let report: { id: string };
    try {
      report = await this.prisma.report.create({
        data: {
          ...input.extra,
          reporterId: input.reporterId,
          reportedUserId: input.reportedUserId,
          targetType: input.targetType,
          targetId: input.targetId,
          reason: input.reason,
          details: input.details ?? undefined,
        },
      });
    } catch (error) {
      // P2002 = indexul unic (reporterId, targetType, targetId). Al doilea
      // raport pe aceeași țintă nu e o eroare de sistem, e regula: îi spunem
      // userului că l-am primit deja, nu îi arătăm un 500.
      if (
        error instanceof Prisma.PrismaClientKnownRequestError &&
        error.code === 'P2002'
      ) {
        throw new BadRequestException(
          'Ai raportat deja asta - moderatorii se ocupă de el',
        );
      }
      throw error;
    }

    await this.applyAutoHide(input.targetType, input.targetId);
    return report;
  }

  /**
   * Ascunde ținta dacă a strâns destule rapoarte DISTINCTE într-una din
   * ferestrele din AUTO_HIDE_RULES.
   *
   * „Distincte" vine gratis din indexul unic pe (reporterId, targetType,
   * targetId): un singur user nu poate umfla numărătoarea singur, deci
   * pragul înseamnă efectiv „N oameni diferiți".
   *
   * Eșecul nu propagă: raportul e deja salvat și ajunge la moderatori
   * oricum, iar ascunderea automată e un ajutor, nu contractul funcției.
   */
  private async applyAutoHide(targetType: ReportTargetType, targetId: string) {
    if (!AUTO_HIDEABLE_TARGETS.includes(targetType)) return;

    try {
      const longestWindowHours = Math.max(
        ...AUTO_HIDE_RULES.map((rule) => rule.windowHours),
      );
      const since = new Date(Date.now() - longestWindowHours * 60 * 60 * 1000);

      // O singură citire pentru ambele praguri: luăm datele rapoartelor din
      // fereastra cea mai lungă și numărăm în memorie pe fiecare fereastră.
      const recent = await this.prisma.report.findMany({
        where: { targetType, targetId, createdAt: { gte: since } },
        select: { createdAt: true },
      });

      const now = Date.now();
      const triggered = AUTO_HIDE_RULES.find((rule) => {
        const cutoff = now - rule.windowHours * 60 * 60 * 1000;
        const count = recent.filter(
          (report) => report.createdAt.getTime() >= cutoff,
        ).length;
        return count >= rule.reports;
      });
      if (!triggered) return;

      const hidden = await this.hideTarget(targetType, targetId);
      if (hidden) {
        this.logger.warn(
          `Auto-hide: ${targetType} ${targetId} ascuns după ${triggered.reports} rapoarte în ${triggered.windowHours}h`,
        );
      }
    } catch (error) {
      this.logger.error(
        `Auto-hide a eșuat pentru ${targetType} ${targetId}: ${error}`,
      );
    }
  }

  /**
   * Marchează ținta ca ascunsă, dacă nu era deja. `updateMany` cu
   * `hiddenAt: null` în filtru face operația idempotentă: al patrulea raport
   * nu rescrie momentul ascunderii pus de al treilea.
   */
  private async hideTarget(
    targetType: ReportTargetType,
    targetId: string,
  ): Promise<boolean> {
    const now = new Date();
    const where = { id: targetId, hiddenAt: null };
    const data = { hiddenAt: now };

    switch (targetType) {
      case 'LISTING': {
        const result = await this.prisma.userBook.updateMany({ where, data });
        return result.count > 0;
      }
      case 'REVIEW': {
        const result = await this.prisma.review.updateMany({ where, data });
        return result.count > 0;
      }
      case 'GROUP_POST': {
        const result = await this.prisma.groupPost.updateMany({ where, data });
        return result.count > 0;
      }
      default:
        return false;
    }
  }

  /**
   * Repune conținutul ascuns automat - acțiunea de moderator pentru „raportul
   * nu stă în picioare". Ascunderea automată e o măsură provizorie, deci
   * trebuie să existe și drumul invers.
   */
  async unhideTarget(targetType: ReportTargetType, targetId: string) {
    const where = { id: targetId };
    const data = { hiddenAt: null };

    switch (targetType) {
      case 'LISTING':
        await this.prisma.userBook.updateMany({ where, data });
        break;
      case 'REVIEW':
        await this.prisma.review.updateMany({ where, data });
        break;
      case 'GROUP_POST':
        await this.prisma.groupPost.updateMany({ where, data });
        break;
      default:
        break;
    }
    return { message: 'Conținut repus' };
  }
}
