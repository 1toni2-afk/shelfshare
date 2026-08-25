import {
  Body,
  Controller,
  Delete,
  Get,
  Param,
  Post,
  Req,
  UseGuards,
} from '@nestjs/common';
import type { Request } from 'express';
import { SavedSearchesService } from './saved-searches.service';
import { CreateSavedSearchDto } from './dto/create-saved-search.dto';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import type { AuthenticatedUser } from '../auth/types/authenticated-user';

@UseGuards(JwtAuthGuard)
@Controller('saved-searches')
export class SavedSearchesController {
  constructor(private savedSearchesService: SavedSearchesService) {}

  @Post()
  create(@Req() req: Request, @Body() dto: CreateSavedSearchDto) {
    const { userId } = req.user as AuthenticatedUser;
    return this.savedSearchesService.create(userId!, dto);
  }

  @Get()
  getMine(@Req() req: Request) {
    const { userId } = req.user as AuthenticatedUser;
    return this.savedSearchesService.getMine(userId!);
  }

  @Delete(':id')
  remove(@Req() req: Request, @Param('id') id: string) {
    const { userId } = req.user as AuthenticatedUser;
    return this.savedSearchesService.remove(userId!, id);
  }
}
