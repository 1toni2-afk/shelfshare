import { IsBoolean, IsOptional, IsString, MaxLength } from 'class-validator';

export class CreateCollectionDto {
  @IsString()
  @MaxLength(80)
  name: string;

  @IsOptional()
  @IsString()
  @MaxLength(300)
  description?: string;

  @IsOptional()
  @IsBoolean()
  isPublic?: boolean;
}
