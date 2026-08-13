import { IsOptional, IsString, MaxLength } from 'class-validator';

export class ShareContactDto {
  @IsOptional()
  @IsString()
  @MaxLength(30)
  phone?: string;
}
