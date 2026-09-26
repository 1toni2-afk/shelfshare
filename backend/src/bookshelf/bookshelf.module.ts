import { Module } from '@nestjs/common';
import { BookshelfController } from './bookshelf.controller';
import { BookshelfService } from './bookshelf.service';
import { BookDescriptionModule } from '../books/book-description.module';
import { FollowModule } from '../follow/follow.module';
import { CatalogMatchModule } from '../books/catalog-match.module';

@Module({
  imports: [BookDescriptionModule, FollowModule, CatalogMatchModule],
  controllers: [BookshelfController],
  providers: [BookshelfService],
  exports: [BookshelfService],
})
export class BookshelfModule {}
