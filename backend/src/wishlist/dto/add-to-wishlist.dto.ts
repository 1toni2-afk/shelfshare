import { IsOptional, IsUUID } from 'class-validator';
import { IsCatalogId } from '../../common/decorators/is-catalog-id.decorator';

export class AddToWishlistDto {
  /// Vezi IsCatalogId: id-ul de catalog NU e garantat UUID.
  @IsCatalogId()
  bookId: string;

  /// Anunțul de pe care s-a apăsat inima. Opțional: adăugările care nu pleacă
  /// de la un anunț anume (Book Match, wishlist după titlu) rămân la nivel de
  /// titlu, iar inima lor se aprinde pe toate exemplarele cărții.
  @IsOptional()
  @IsUUID()
  userBookId?: string;
}
