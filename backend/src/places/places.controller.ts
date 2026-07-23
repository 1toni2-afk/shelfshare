import { Controller, Get, Query, UseGuards } from '@nestjs/common';
import { PlacesService } from './places.service';
import { SearchPlacesDto } from './dto/search-places.dto';
import { SearchNearbyPlacesDto } from './dto/search-nearby-places.dto';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';

@UseGuards(JwtAuthGuard)
@Controller('places')
export class PlacesController {
  constructor(private placesService: PlacesService) {}

  @Get('search')
  search(@Query() query: SearchPlacesDto) {
    return this.placesService.search(query.q);
  }

  @Get('meeting-points')
  meetingPoints(@Query() query: SearchNearbyPlacesDto) {
    return this.placesService.findMeetingPoints(query.lat, query.lng);
  }
}
