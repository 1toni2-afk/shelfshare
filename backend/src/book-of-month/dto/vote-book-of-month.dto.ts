import { IsCatalogId } from '../../common/decorators/is-catalog-id.decorator';

export class VoteBookOfMonthDto {
  /// Vezi IsCatalogId.
  @IsCatalogId()
  bookId: string;
}
