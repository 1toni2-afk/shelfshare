import { IsString, MinLength } from 'class-validator';

export class ExchangeLoginCodeDto {
  @IsString()
  @MinLength(1)
  code: string;
}
