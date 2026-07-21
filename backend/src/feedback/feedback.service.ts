import { Injectable } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';

@Injectable()
export class FeedbackService {
  constructor(private prisma: PrismaService) {}

  create(userId: string, message: string) {
    return this.prisma.feedback.create({ data: { userId, message } });
  }

  getAll() {
    return this.prisma.feedback.findMany({
      include: { user: { select: { id: true, email: true, name: true } } },
      orderBy: { createdAt: 'desc' },
      take: 200,
    });
  }
}
