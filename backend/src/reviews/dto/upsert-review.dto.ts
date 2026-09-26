import { IsInt, IsOptional, IsString, Max, MaxLength, Min } from 'class-validator';
import { IsCatalogId } from '../../common/decorators/is-catalog-id.decorator';

export class UpsertReviewDto {
  /// Vezi IsCatalogId.
  @IsCatalogId()
  bookId: string;

  @IsInt()
  @Min(1)
  @Max(5)
  rating: number;

  @IsOptional()
  @IsString()
  @MaxLength(1000)
  text?: string;
}
