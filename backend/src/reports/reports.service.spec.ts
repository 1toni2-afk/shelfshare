import { Test, TestingModule } from '@nestjs/testing';
import { BadRequestException } from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { ReportsService } from './reports.service';
import { PrismaService } from '../prisma/prisma.service';

describe('ReportsService', () => {
  let service: ReportsService;
  let prisma: {
    report: Record<string, jest.Mock>;
    userBook: Record<string, jest.Mock>;
    review: Record<string, jest.Mock>;
    groupPost: Record<string, jest.Mock>;
  };

  /** Un raport valid pe o recenzie - motivul e din lista de conținut. */
  const reviewReport = {
    reporterId: 'user-a',
    reportedUserId: 'user-b',
    targetType: 'REVIEW' as const,
    targetId: 'review-1',
    reason: 'SPAM' as const,
  };

  /** N rapoarte, toate în ultimele `agoHours` ore. */
  const reportsAgo = (count: number, agoHours: number) =>
    Array.from({ length: count }, () => ({
      createdAt: new Date(Date.now() - agoHours * 60 * 60 * 1000),
    }));

  beforeEach(async () => {
    prisma = {
      report: {
        create: jest.fn().mockResolvedValue({ id: 'report-1' }),
        findMany: jest.fn().mockResolvedValue([]),
      },
      userBook: { updateMany: jest.fn().mockResolvedValue({ count: 1 }) },
      review: { updateMany: jest.fn().mockResolvedValue({ count: 1 }) },
      groupPost: { updateMany: jest.fn().mockResolvedValue({ count: 1 }) },
    };

    const module: TestingModule = await Test.createTestingModule({
      providers: [ReportsService, { provide: PrismaService, useValue: prisma }],
    }).compile();

    service = module.get(ReportsService);
  });

  describe('motive valide per tip de țintă', () => {
    it('acceptă un motiv de conținut pe o recenzie', async () => {
      await service.create({ ...reviewReport, reason: 'ABUSIVE_LANGUAGE' });

      expect(prisma.report.create).toHaveBeenCalled();
    });

    it('refuză „profil fals" pe o recenzie - motivul e din lista de user', async () => {
      await expect(
        service.create({ ...reviewReport, reason: 'FAKE_PROFILE' }),
      ).rejects.toThrow(BadRequestException);

      expect(prisma.report.create).not.toHaveBeenCalled();
    });

    it('refuză „conținut fals" pe un user - motivul e din lista de conținut', async () => {
      await expect(
        service.create({
          reporterId: 'user-a',
          reportedUserId: 'user-b',
          targetType: 'USER',
          targetId: 'user-b',
          reason: 'FALSE_CONTENT',
        }),
      ).rejects.toThrow(BadRequestException);
    });

    it('acceptă un motiv vechi pe orice țintă, pentru aplicațiile neactualizate', async () => {
      // „Înșelătorie" era oferit pe orice țintă înainte de listele per tip;
      // un telefon care încă rulează versiunea veche nu trebuie să primească
      // 400 exact pe fluxul de siguranță.
      await service.create({ ...reviewReport, reason: 'SCAM' });

      expect(prisma.report.create).toHaveBeenCalled();
    });

    it('refuză autoraportarea', async () => {
      await expect(
        service.create({ ...reviewReport, reportedUserId: 'user-a' }),
      ).rejects.toThrow(BadRequestException);
    });
  });

  describe('un raport per user per țintă', () => {
    it('traduce coliziunea pe indexul unic într-un mesaj, nu într-un 500', async () => {
      prisma.report.create.mockRejectedValue(
        new Prisma.PrismaClientKnownRequestError('duplicate', {
          code: 'P2002',
          clientVersion: 'test',
        }),
      );

      await expect(service.create(reviewReport)).rejects.toThrow(
        BadRequestException,
      );
    });

    it('lasă orice altă eroare de bază de date să urce neatinsă', async () => {
      prisma.report.create.mockRejectedValue(new Error('conexiune pierdută'));

      await expect(service.create(reviewReport)).rejects.toThrow(
        'conexiune pierdută',
      );
    });
  });

  describe('auto-hide pe praguri', () => {
    it('ascunde recenzia la 3 rapoarte în 24h', async () => {
      prisma.report.findMany.mockResolvedValue(reportsAgo(3, 2));

      await service.create(reviewReport);

      expect(prisma.review.updateMany).toHaveBeenCalledWith({
        where: { id: 'review-1', hiddenAt: null },
        data: { hiddenAt: expect.any(Date) },
      });
    });

    it('nu ascunde la 2 rapoarte în 24h', async () => {
      prisma.report.findMany.mockResolvedValue(reportsAgo(2, 2));

      await service.create(reviewReport);

      expect(prisma.review.updateMany).not.toHaveBeenCalled();
    });

    it('ascunde la 10 rapoarte într-o săptămână, chiar dacă niciunul nu e din ultimele 24h', async () => {
      prisma.report.findMany.mockResolvedValue(reportsAgo(10, 72));

      await service.create(reviewReport);

      expect(prisma.review.updateMany).toHaveBeenCalled();
    });

    it('nu ascunde la 9 rapoarte într-o săptămână', async () => {
      prisma.report.findMany.mockResolvedValue(reportsAgo(9, 72));

      await service.create(reviewReport);

      expect(prisma.review.updateMany).not.toHaveBeenCalled();
    });

    it('nu ascunde niciodată un user - pentru conturi există suspendarea', async () => {
      prisma.report.findMany.mockResolvedValue(reportsAgo(20, 1));

      await service.create({
        reporterId: 'user-a',
        reportedUserId: 'user-b',
        targetType: 'USER',
        targetId: 'user-b',
        reason: 'HARASSMENT',
      });

      expect(prisma.report.findMany).not.toHaveBeenCalled();
      expect(prisma.userBook.updateMany).not.toHaveBeenCalled();
    });

    it('nu pierde raportul dacă ascunderea automată eșuează', async () => {
      prisma.report.findMany.mockRejectedValue(new Error('baza a picat'));

      const report = await service.create(reviewReport);

      expect(report).toEqual({ id: 'report-1' });
    });
  });

  it('repune conținutul ascuns', async () => {
    await service.unhideTarget('LISTING', 'ub-1');

    expect(prisma.userBook.updateMany).toHaveBeenCalledWith({
      where: { id: 'ub-1' },
      data: { hiddenAt: null },
    });
  });
});
