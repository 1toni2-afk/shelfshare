import { IsOptional, IsString, MaxLength } from 'class-validator';

export class DoneExchangeDto {
  @IsOptional()
  @IsString()
  @MaxLength(500)
  comment?: string;
}
