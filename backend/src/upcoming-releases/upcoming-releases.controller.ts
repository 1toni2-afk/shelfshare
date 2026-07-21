import {
  Body,
  Controller,
  Delete,
  Get,
  Param,
  Patch,
  Post,
  UseGuards,
} from '@nestjs/common';
import { UpcomingReleasesService } from './upcoming-releases.service';
import { CreateUpcomingReleaseDto } from './dto/create-upcoming-release.dto';
import { UpdateUpcomingReleaseDto } from './dto/update-upcoming-release.dto';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { AdminGuard } from '../admin/guards/admin.guard';

@Controller('upcoming-releases')
export class UpcomingReleasesController {
  constructor(private upcomingReleasesService: UpcomingReleasesService) {}

  @Get()
  list() {
    return this.upcomingReleasesService.list();
  }

  @UseGuards(JwtAuthGuard, AdminGuard)
  @Post()
  create(@Body() dto: CreateUpcomingReleaseDto) {
    return this.upcomingReleasesService.create(dto);
  }

  @UseGuards(JwtAuthGuard, AdminGuard)
  @Patch(':id')
  update(@Param('id') id: string, @Body() dto: UpdateUpcomingReleaseDto) {
    return this.upcomingReleasesService.update(id, dto);
  }

  @UseGuards(JwtAuthGuard, AdminGuard)
  @Delete(':id')
  delete(@Param('id') id: string) {
    return this.upcomingReleasesService.delete(id);
  }
}
