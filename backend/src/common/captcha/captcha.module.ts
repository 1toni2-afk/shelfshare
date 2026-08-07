import { Module } from '@nestjs/common';
import { CaptchaService } from './captcha.service';
import { AttemptGuardService } from './attempt-guard.service';

@Module({
  providers: [CaptchaService, AttemptGuardService],
  exports: [CaptchaService, AttemptGuardService],
})
export class CaptchaModule {}
