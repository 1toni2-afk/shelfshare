import { IsInt, Min } from 'class-validator';

export class SetReadingProgressDto {
  @IsInt()
  @Min(0)
  currentPage: number;
}
