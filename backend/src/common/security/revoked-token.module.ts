import { Module } from '@nestjs/common';
import { RevokedTokenService } from './revoked-token.service';
import { UserSessionsService } from './user-sessions.service';

@Module({
  providers: [RevokedTokenService, UserSessionsService],
  exports: [RevokedTokenService, UserSessionsService],
})
export class RevokedTokenModule {}
