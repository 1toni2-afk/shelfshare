import { Global, Module } from '@nestjs/common';
import { RealtimeService } from './realtime.service';

/**
 * Global: RealtimeService devine injectabil oriunde fără import explicit, ca
 * orice serviciu care are nevoie să trimită un eveniment live (notificări,
 * mesaje) să nu fie nevoit să importe ChatModule și să creeze cicluri.
 */
@Global()
@Module({
  providers: [RealtimeService],
  exports: [RealtimeService],
})
export class RealtimeModule {}
