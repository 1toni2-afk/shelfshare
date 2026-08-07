import { Module } from '@nestjs/common';
import { SupportController } from './support.controller';
import { SupportService } from './support.service';
import { MailModule } from '../mail/mail.module';
import { CaptchaModule } from '../common/captcha/captcha.module';

@Module({
  imports: [MailModule, CaptchaModule],
  controllers: [SupportController],
  providers: [SupportService],
  exports: [SupportService],
})
export class SupportModule {}
