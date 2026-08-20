import {
  CanActivate,
  ExecutionContext,
  ForbiddenException,
  Injectable,
} from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import type { Request } from 'express';
import { PrismaService } from '../../prisma/prisma.service';
import type { AuthenticatedUser } from '../../auth/types/authenticated-user';
import { PERMISSION_KEY } from '../decorators/require-permission.decorator';
import type { AdminPermissionKey } from '../constants/admin-permissions';

/**
 * Verifică o permisiune granulară pe lângă AdminGuard. Rutele fără
 * @RequirePermission trec liber (rămân "orice admin poate", ca înainte de
 * Milestone 19) - doar rutele noi/actualizate cer explicit o permisiune.
 */
@Injectable()
export class PermissionGuard implements CanActivate {
  constructor(
    private prisma: PrismaService,
    private reflector: Reflector,
  ) {}

  async canActivate(context: ExecutionContext): Promise<boolean> {
    const required = this.reflector.get<AdminPermissionKey | undefined>(
      PERMISSION_KEY,
      context.getHandler(),
    );
    if (!required) {
      return true;
    }

    const req = context.switchToHttp().getRequest<Request>();
    const { userId } = req.user as AuthenticatedUser;

    const user = await this.prisma.user.findUnique({
      where: { id: userId },
      include: { adminRole: true },
    });

    if (!user?.adminRole?.permissions.includes(required)) {
      throw new ForbiddenException(`Necesită permisiunea: ${required}`);
    }

    return true;
  }
}
