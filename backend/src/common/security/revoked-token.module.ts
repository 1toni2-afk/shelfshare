import { Module } from '@nestjs/common';
import { RevokedTokenService } from './revoked-token.service';

@Module({
  providers: [RevokedTokenService],
  exports: [RevokedTokenService],
})
export class RevokedTokenModule {}
