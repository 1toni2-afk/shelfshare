import { Module } from '@nestjs/common';
import { FeedbackController } from './feedback.controller';
import { FeedbackService } from './feedback.service';
import { StorageModule } from '../storage/storage.module';
import { MailModule } from '../mail/mail.module';

@Module({
  imports: [StorageModule, MailModule],
  controllers: [FeedbackController],
  providers: [FeedbackService],
  exports: [FeedbackService],
})
export class FeedbackModule {}
