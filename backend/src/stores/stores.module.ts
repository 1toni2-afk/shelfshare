import { Module } from '@nestjs/common';
import { StoresController } from './stores.controller';
import { StoresService } from './stores.service';
import { SecurityEventsModule } from '../security-events/security-events.module';

@Module({
  // AdminAuditInterceptor (folosit de StoresController) are nevoie de
  // SecurityEventsService; ActivityLogService e global.
  imports: [SecurityEventsModule],
  controllers: [StoresController],
  providers: [StoresService],
  // BooksService verifică prin StoresService că ținta importului chiar e un
  // magazin activ - vezi importListingsCsv.
  exports: [StoresService],
})
export class StoresModule {}
