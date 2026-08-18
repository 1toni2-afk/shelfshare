import { IsNumber, IsOptional, Max, Min } from 'class-validator';

/// null = elimină overrideul, revine la scorul calculat din ListingScoreEvent.
export class SetListingScoreOverrideDto {
  @IsOptional()
  @IsNumber()
  @Min(0)
  @Max(1000)
  score?: number | null;
}
