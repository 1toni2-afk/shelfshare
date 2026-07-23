import { IsInt, IsOptional, Min } from 'class-validator';

export class SetReadingChallengeDto {
  @IsOptional()
  @IsInt()
  @Min(1)
  goal?: number | null;
}
