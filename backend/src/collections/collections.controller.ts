import {
  Body,
  Controller,
  Delete,
  Get,
  Param,
  Patch,
  Post,
  Req,
  UseGuards,
} from '@nestjs/common';
import type { Request } from 'express';
import { CollectionsService } from './collections.service';
import { CreateCollectionDto } from './dto/create-collection.dto';
import { UpdateCollectionDto } from './dto/update-collection.dto';
import { AddBookToCollectionDto } from './dto/add-book-to-collection.dto';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { OptionalJwtAuthGuard } from '../auth/guards/optional-jwt-auth.guard';
import type { AuthenticatedUser } from '../auth/types/authenticated-user';

@Controller('collections')
export class CollectionsController {
  constructor(private collectionsService: CollectionsService) {}

  @UseGuards(JwtAuthGuard)
  @Post()
  create(@Req() req: Request, @Body() dto: CreateCollectionDto) {
    const { userId } = req.user as AuthenticatedUser;
    return this.collectionsService.createCollection(userId!, dto);
  }

  @UseGuards(JwtAuthGuard)
  @Get('mine')
  getMine(@Req() req: Request) {
    const { userId } = req.user as AuthenticatedUser;
    return this.collectionsService.getMyCollections(userId!);
  }

  @Get('user/:userId')
  getForUser(@Param('userId') userId: string) {
    return this.collectionsService.getPublicCollectionsForUser(userId);
  }

  @UseGuards(OptionalJwtAuthGuard)
  @Get(':id')
  getOne(@Req() req: Request, @Param('id') id: string) {
    const user = req.user as AuthenticatedUser | undefined;
    return this.collectionsService.getCollection(id, user?.userId);
  }

  @UseGuards(JwtAuthGuard)
  @Patch(':id')
  update(@Req() req: Request, @Param('id') id: string, @Body() dto: UpdateCollectionDto) {
    const { userId } = req.user as AuthenticatedUser;
    return this.collectionsService.updateCollection(id, userId!, dto);
  }

  @UseGuards(JwtAuthGuard)
  @Delete(':id')
  remove(@Req() req: Request, @Param('id') id: string) {
    const { userId } = req.user as AuthenticatedUser;
    return this.collectionsService.deleteCollection(id, userId!);
  }

  @UseGuards(JwtAuthGuard)
  @Post(':id/items')
  addBook(@Req() req: Request, @Param('id') id: string, @Body() dto: AddBookToCollectionDto) {
    const { userId } = req.user as AuthenticatedUser;
    return this.collectionsService.addBook(id, userId!, dto.bookId);
  }

  @UseGuards(JwtAuthGuard)
  @Delete(':id/items/:bookId')
  removeBook(@Req() req: Request, @Param('id') id: string, @Param('bookId') bookId: string) {
    const { userId } = req.user as AuthenticatedUser;
    return this.collectionsService.removeBook(id, userId!, bookId);
  }
}
