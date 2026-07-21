import { Module } from '@nestjs/common';
import { HttpModule } from '@nestjs/axios';
import { PlacesController } from './places.controller';
import { PlacesService } from './places.service';

@Module({
  imports: [HttpModule.register({ timeout: 8000 })],
  controllers: [PlacesController],
  providers: [PlacesService],
})
export class PlacesModule {}
