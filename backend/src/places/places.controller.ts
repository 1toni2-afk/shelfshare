import { Controller, Get, Query, UseGuards } from '@nestjs/common';
import { PlacesService } from './places.service';
import { SearchPlacesDto } from './dto/search-places.dto';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';

@UseGuards(JwtAuthGuard)
@Controller('places')
export class PlacesController {
  constructor(private placesService: PlacesService) {}

  @Get('search')
  search(@Query() query: SearchPlacesDto) {
    return this.placesService.search(query.q);
  }
}
