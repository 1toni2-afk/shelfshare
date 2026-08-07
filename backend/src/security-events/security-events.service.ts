import { Injectable, Logger } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { Prisma } from '@prisma/client';

export type SecurityEventType =
  | 'LOGIN_SUCCESS'
  | 'LOGIN_FAILED'
  | 'ACCOUNT_LOCKED'
  | 'PASSWORD_RESET'
  | 'PASSWORD_CHANGED'
  | 'ADMIN_ACTION';

/**
 * Fire-and-forget audit trail for security-relevant events. Never allowed
 * to break the request it's logging for - a failed write here just gets
 * logged operationally instead of surfacing as a 500 to the caller.
 */
@Injectable()
export class SecurityEventsService {
  private readonly logger = new Logger(SecurityEventsService.name);

  constructor(private prisma: PrismaService) {}

  async log(
    type: SecurityEventType,
    userId: string | null,
    ip: string | null,
    metadata?: Record<string, unknown>,
  ) {
    try {
      await this.prisma.securityEvent.create({
        data: {
          type,
          userId,
          ip,
          metadata: metadata as Prisma.InputJsonValue | undefined,
        },
      });
    } catch (error) {
      this.logger.warn(
        `Nu am putut înregistra evenimentul de securitate "${type}": ${error}`,
      );
    }
  }
}
