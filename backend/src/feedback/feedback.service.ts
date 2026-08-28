import { Injectable } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { StorageService } from '../storage/storage.service';
import { ActivityLogService } from '../activity-log/activity-log.service';

@Injectable()
export class FeedbackService {
  constructor(
    private prisma: PrismaService,
    private storage: StorageService,
    private activityLog: ActivityLogService,
  ) {}

  async create(userId: string, message: string, photoBuffer?: Buffer) {
    let photoUrl: string | undefined;
    if (photoBuffer) {
      const path = await this.storage.uploadImage(photoBuffer, 'feedback');
      photoUrl = this.storage.getPublicUrl(path);
    }
    const feedback = await this.prisma.feedback.create({
      data: { userId, message, photoUrl },
    });

    // Feedback-ul se citește de admini - e o interacțiune user-admin.
    this.activityLog.record({
      action: 'FEEDBACK_SENT',
      actorId: userId,
      details: { feedbackId: feedback.id, lungime: message.length },
    });

    return feedback;
  }

  getAll() {
    return this.prisma.feedback.findMany({
      include: { user: { select: { id: true, email: true, name: true } } },
      orderBy: { createdAt: 'desc' },
      take: 200,
    });
  }
}
