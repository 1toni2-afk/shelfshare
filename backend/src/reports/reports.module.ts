import { Global, Module } from '@nestjs/common';
import { ReportsService } from './reports.service';

/**
 * `@Global`: se raportează din patru module fără nicio legătură între ele
 * (safety, chat, grupuri, recenzii) și, în plus, din panoul de admin. Un
 * import explicit peste tot ar fi doar zgomot, iar serviciul n-are stare.
 */
@Global()
@Module({
  providers: [ReportsService],
  exports: [ReportsService],
})
export class ReportsModule {}
