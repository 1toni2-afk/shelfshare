import {
  CallHandler,
  ExecutionContext,
  Injectable,
  NestInterceptor,
} from '@nestjs/common';
import type { Request } from 'express';
import { tap } from 'rxjs/operators';
import { SecurityEventsService } from '../security-events/security-events.service';
import type { AuthenticatedUser } from '../auth/types/authenticated-user';

/**
 * Generic audit trail for every mutating admin action (ban, delete, toggle
 * premium/supporter, etc.) - logged after success, at the controller level,
 * so new admin endpoints get an audit trail automatically instead of
 * requiring an explicit logging call in every service method.
 */
@Injectable()
export class AdminAuditInterceptor implements NestInterceptor {
  constructor(private securityEvents: SecurityEventsService) {}

  intercept(context: ExecutionContext, next: CallHandler) {
    const req = context.switchToHttp().getRequest<Request>();

    if (req.method === 'GET') {
      return next.handle();
    }

    const { userId } = (req.user as AuthenticatedUser | undefined) ?? {};

    return next.handle().pipe(
      tap(() => {
        void this.securityEvents.log(
          'ADMIN_ACTION',
          userId ?? null,
          req.ip ?? null,
          {
            method: req.method,
            path: req.originalUrl ?? req.url,
            params: req.params,
          },
        );
      }),
    );
  }
}
