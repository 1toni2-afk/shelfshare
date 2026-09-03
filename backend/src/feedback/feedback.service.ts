import { Injectable, Logger } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { StorageService } from '../storage/storage.service';
import { ActivityLogService } from '../activity-log/activity-log.service';
import { MailService } from '../mail/mail.service';

@Injectable()
export class FeedbackService {
  private readonly logger = new Logger(FeedbackService.name);

  constructor(
    private prisma: PrismaService,
    private storage: StorageService,
    private activityLog: ActivityLogService,
    private mail: MailService,
  ) {}

  async create(userId: string, message: string, photoBuffer?: Buffer) {
    let photoUrl: string | undefined;
    if (photoBuffer) {
      const path = await this.storage.uploadImage(photoBuffer, 'feedback');
      photoUrl = this.storage.getPublicUrl(path);
    }
    const feedback = await this.prisma.feedback.create({
      data: { userId, message, photoUrl },
      include: { user: { select: { name: true, email: true } } },
    });

    // Pe email, nu doar în panou: altfel un feedback stă necitit până intră
    // cineva la /admin. Eșecul trimiterii NU pică cererea - feedback-ul e
    // deja salvat, iar userul n-are ce face cu o eroare de SMTP.
    void this.mail
      .sendFeedbackNotification({
        feedbackId: feedback.id,
        name: feedback.user?.name,
        email: feedback.user?.email,
        message,
        photoUrl,
      })
      .catch((error) =>
        this.logger.warn(
          `Feedback ${feedback.id} salvat, dar emailul n-a plecat: ${error}`,
        ),
      );

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
