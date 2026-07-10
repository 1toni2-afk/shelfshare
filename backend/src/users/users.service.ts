import { Injectable } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { User } from '@prisma/client';

@Injectable()
export class UsersService {
  constructor(private prisma: PrismaService) {}

  findByEmail(email: string): Promise<User | null> {
    return this.prisma.user.findUnique({ where: { email } });
  }

  findById(id: string): Promise<User | null> {
    return this.prisma.user.findUnique({ where: { id } });
  }

  findByGoogleId(googleId: string): Promise<User | null> {
    return this.prisma.user.findUnique({ where: { googleId } });
  }

  findByEmailVerifyToken(token: string): Promise<User | null> {
    return this.prisma.user.findUnique({
      where: { emailVerifyToken: token },
    });
  }

  findByResetPasswordToken(token: string): Promise<User | null> {
    return this.prisma.user.findUnique({
      where: { resetPasswordToken: token },
    });
  }

  create(data: {
    email: string;
    password?: string;
    googleId?: string;
    isEmailVerified?: boolean;
  }): Promise<User> {
    return this.prisma.user.create({ data });
  }

  update(id: string, data: Partial<User>): Promise<User> {
    return this.prisma.user.update({ where: { id }, data });
  }
}
