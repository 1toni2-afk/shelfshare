import { IsIn, IsOptional, IsString, MaxLength } from 'class-validator';

export const CANCEL_REASONS = [
  'no_show',
  'book_mismatch',
  'changed_mind',
  'other',
] as const;

export class CancelExchangeDto {
  // Opțional - cererile PENDING (retrase înainte de acceptare) nu trec prin
  // formularul "What happened?", doar cele ACCEPTED (schimb în desfășurare).
  @IsOptional()
  @IsIn(CANCEL_REASONS)
  reason?: (typeof CANCEL_REASONS)[number];

  @IsOptional()
  @IsString()
  @MaxLength(500)
  details?: string;
}
