import {
  CanActivate,
  ExecutionContext,
  ForbiddenException,
  Injectable,
} from '@nestjs/common';
import type { Request } from 'express';
import { PrismaService } from '../../prisma/prisma.service';
import type { AuthenticatedUser } from '../../auth/types/authenticated-user';

@Injectable()
export class AdminGuard implements CanActivate {
  constructor(private prisma: PrismaService) {}

  async canActivate(context: ExecutionContext): Promise<boolean> {
    const req = context.switchToHttp().getRequest<Request>();
    const { userId } = req.user as AuthenticatedUser;

    const user = await this.prisma.user.findUnique({ where: { id: userId } });
    if (!user?.isAdmin) {
      throw new ForbiddenException('Acces permis doar administratorilor');
    }

    return true;
  }
}
