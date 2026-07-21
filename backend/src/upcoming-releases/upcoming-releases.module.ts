import { Module } from '@nestjs/common';
import { UpcomingReleasesController } from './upcoming-releases.controller';
import { UpcomingReleasesService } from './upcoming-releases.service';

@Module({
  controllers: [UpcomingReleasesController],
  providers: [UpcomingReleasesService],
})
export class UpcomingReleasesModule {}
