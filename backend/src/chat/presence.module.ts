import { Module } from '@nestjs/common';
import { PresenceService } from './presence.service';

/**
 * Modul propriu doar pentru `PresenceService`, ca „cine e online acum" să
 * poată fi citit și din afara chatului (vezi contorul din panoul de admin)
 * fără ca AdminModule să importe tot ChatModule - ceea ce ar închide un ciclu
 * prin NotificationsModule/SafetyModule.
 *
 * Nest refolosește aceeași instanță de modul pentru toți importatorii, deci
 * harta de conexiuni rămâne una singură, cea alimentată de ChatGateway.
 */
@Module({
  providers: [PresenceService],
  exports: [PresenceService],
})
export class PresenceModule {}
