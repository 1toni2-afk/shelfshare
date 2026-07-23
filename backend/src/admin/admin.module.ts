import { Module } from '@nestjs/common';
import { AdminController } from './admin.controller';
import { AdminService } from './admin.service';
import { AdminGuard } from './guards/admin.guard';
import { FeedbackModule } from '../feedback/feedback.module';
import { SupportModule } from '../support/support.module';

@Module({
  imports: [FeedbackModule, SupportModule],
  controllers: [AdminController],
  providers: [AdminService, AdminGuard],
})
export class AdminModule {}
