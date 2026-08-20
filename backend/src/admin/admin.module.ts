import { Module } from '@nestjs/common';
import { AdminController } from './admin.controller';
import { AdminService } from './admin.service';
import { AdminManagementController } from './admin-management.controller';
import { AdminManagementService } from './admin-management.service';
import { AdminGuard } from './guards/admin.guard';
import { PermissionGuard } from './guards/permission.guard';
import { AdminAuditInterceptor } from './admin-audit.interceptor';
import { FeedbackModule } from '../feedback/feedback.module';
import { SupportModule } from '../support/support.module';
import { SecurityEventsModule } from '../security-events/security-events.module';
import { ListingScoreModule } from '../books/listing-score.module';

@Module({
  imports: [FeedbackModule, SupportModule, SecurityEventsModule, ListingScoreModule],
  controllers: [AdminController, AdminManagementController],
  providers: [
    AdminService,
    AdminManagementService,
    AdminGuard,
    PermissionGuard,
    AdminAuditInterceptor,
  ],
  exports: [AdminGuard],
})
export class AdminModule {}
