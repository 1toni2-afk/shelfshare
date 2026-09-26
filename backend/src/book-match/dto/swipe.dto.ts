import {
  IsBoolean,
  IsIn,
  IsOptional,
  IsString,
  IsUUID,
  MaxLength,
} from 'class-validator';
import { IsCatalogId } from '../../common/decorators/is-catalog-id.decorator';
import type { BookMatchAction } from '../book-match.scoring';

export class SwipeDto {
  /// Vezi IsCatalogId: teancul de swipe vine din catalogul importat, unde
  /// id-urile poartă cheia sursei, nu un UUID.
  @IsCatalogId()
  bookId: string;

  @IsIn(['YES', 'NO', 'SKIP'])
  action: BookMatchAction;

  /// Generat de client (uuid). Nu impunem formatul UUID: e doar o cheie de
  /// grupare, iar un client care generează altceva nu strică nimic.
  @IsString()
  @MaxLength(64)
  sessionId: string;

  @IsOptional()
  @IsBoolean()
  isDiscovery?: boolean;
}
