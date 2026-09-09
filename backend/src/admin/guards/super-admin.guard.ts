import {
  CanActivate,
  ExecutionContext,
  ForbiddenException,
  Injectable,
} from '@nestjs/common';
import type { Request } from 'express';
import { PrismaService } from '../../prisma/prisma.service';
import { isSuperAdmin } from '../../common/utils/is-super-admin';
import type { AuthenticatedUser } from '../../auth/types/authenticated-user';

/**
 * Mai strict decât AdminGuard: doar rolul SUPER_ADMIN trece.
 *
 * Folosit pentru unelte de operare care nu sunt „moderare" (adăugarea în masă
 * pentru integrările cu anticariatele), unde nici măcar un moderator cu
 * permisiuni granulare n-are ce căuta.
 */
@Injectable()
export class SuperAdminGuard implements CanActivate {
  constructor(private prisma: PrismaService) {}

  async canActivate(context: ExecutionContext): Promise<boolean> {
    const req = context.switchToHttp().getRequest<Request>();
    const { userId } = req.user as AuthenticatedUser;

    if (!(await isSuperAdmin(this.prisma, userId!))) {
      throw new ForbiddenException('Acces permis doar super-adminilor');
    }

    return true;
  }
}
