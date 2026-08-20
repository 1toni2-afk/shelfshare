import { Module } from '@nestjs/common';
import { AdminController } from './admin.controller';
import { AdminService } from './admin.service';
import { AdminGuard } from './guards/admin.guard';
import { AdminAuditInterceptor } from './admin-audit.interceptor';
import { FeedbackModule } from '../feedback/feedback.module';
import { SupportModule } from '../support/support.module';
import { SecurityEventsModule } from '../security-events/security-events.module';
import { ListingScoreModule } from '../books/listing-score.module';

@Module({
  imports: [FeedbackModule, SupportModule, SecurityEventsModule, ListingScoreModule],
  controllers: [AdminController],
  providers: [AdminService, AdminGuard, AdminAuditInterceptor],
  exports: [AdminGuard],
})
export class AdminModule {}
