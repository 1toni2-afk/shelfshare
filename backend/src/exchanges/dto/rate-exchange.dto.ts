import {
  IsInt,
  IsOptional,
  IsString,
  Max,
  MaxLength,
  Min,
} from 'class-validator';

export class RateExchangeDto {
  @IsInt()
  @Min(1)
  @Max(5)
  value: number;

  @IsOptional()
  @IsString()
  @MaxLength(500)
  comment?: string;

  // Rating pe dimensiuni - toate opționale, ca formularul să nu devină
  // obligatoriu pe toate axele deodată (condition mai ales, care nu se
  // aplică mereu - vezi comentariul de pe schema.prisma).
  @IsOptional()
  @IsInt()
  @Min(1)
  @Max(5)
  communication?: number;

  @IsOptional()
  @IsInt()
  @Min(1)
  @Max(5)
  punctuality?: number;

  @IsOptional()
  @IsInt()
  @Min(1)
  @Max(5)
  condition?: number;
}
