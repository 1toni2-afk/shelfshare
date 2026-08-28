import { Global, Module } from '@nestjs/common';
import { ActivityLogService } from './activity-log.service';

/**
 * Global: jurnalul e transversal (schimburi, oferte, chat, admin), iar a-l
 * importa în fiecare modul care scrie o linie ar fi doar zgomot.
 */
@Global()
@Module({
  providers: [ActivityLogService],
  exports: [ActivityLogService],
})
export class ActivityLogModule {}
