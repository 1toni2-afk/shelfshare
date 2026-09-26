import { Module } from '@nestjs/common';
import { CatalogMatchService } from './catalog-match.service';

/**
 * Separat de BooksModule din același motiv ca BookDescriptionModule: raftul
 * (BookshelfModule) are nevoie de potrivire, dar nu de tot ce trage BooksModule.
 */
@Module({
  providers: [CatalogMatchService],
  exports: [CatalogMatchService],
})
export class CatalogMatchModule {}
