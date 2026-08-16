import { Module } from '@nestjs/common';
import { ListingScoreService } from './listing-score.service';

/// Modul minimal, fără dependențe proprii, ca să poată fi importat și de
/// BooksModule și de WishlistModule fără să creeze un ciclu (BooksModule
/// importă deja WishlistModule).
@Module({
  providers: [ListingScoreService],
  exports: [ListingScoreService],
})
export class ListingScoreModule {}
