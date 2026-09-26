import { Module } from '@nestjs/common';
import { PrismaModule } from '../prisma/prisma.module';
import { MailModule } from '../mail/mail.module';
import { WelcomeEmailService } from './welcome-email.service';

@Module({
  imports: [PrismaModule, MailModule],
  providers: [WelcomeEmailService],
})
export class WelcomeEmailModule {}
