import { IsInt, IsOptional, Max, Min } from 'class-validator';

export class SetReadingProgressDto {
  @IsInt()
  @Min(0)
  currentPage: number;

  /// Numărul total de pagini al ediției pe care o are userul, când diferă de
  /// cea din catalog (vezi ReadingProgress.totalPages). Absent = păstrăm ce
  /// era deja salvat.
  @IsOptional()
  @IsInt()
  @Min(1)
  @Max(30000)
  totalPages?: number;
}
