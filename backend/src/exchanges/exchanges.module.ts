import { Module } from '@nestjs/common';
import { ExchangesController } from './exchanges.controller';
import { ExchangesService } from './exchanges.service';
import { NotificationsModule } from '../notifications/notifications.module';

@Module({
  imports: [NotificationsModule],
  controllers: [ExchangesController],
  providers: [ExchangesService],
})
export class ExchangesModule {}
