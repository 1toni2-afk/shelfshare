import { IsString, MinLength } from 'class-validator';

export class SearchBookDto {
  @IsString()
  @MinLength(2, { message: 'Introdu cel puțin 2 caractere pentru căutare' })
  q: string;
}
