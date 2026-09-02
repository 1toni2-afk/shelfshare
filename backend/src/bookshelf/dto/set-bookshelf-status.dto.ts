import { IsBoolean, IsEnum, IsOptional } from 'class-validator';
import { BookshelfStatus } from '@prisma/client';

export class SetBookshelfStatusDto {
  @IsEnum(BookshelfStatus, { message: 'Status invalid' })
  status: BookshelfStatus;

  /// Opțional: marchează/demarchează cartea ca deținută fizic (vezi
  /// BookshelfEntry.owned). Absent = nu atingem flagul existent.
  @IsOptional()
  @IsBoolean()
  owned?: boolean;
}
