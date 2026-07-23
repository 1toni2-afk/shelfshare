import { IsDateString, IsOptional, IsString, MaxLength } from 'class-validator';

export class CreateEventDto {
  @IsString()
  @MaxLength(120)
  title: string;

  @IsOptional()
  @IsString()
  @MaxLength(500)
  description?: string;

  @IsDateString()
  eventAt: string;

  @IsOptional()
  @IsString()
  @MaxLength(200)
  location?: string;
}
