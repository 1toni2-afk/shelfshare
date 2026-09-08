import { IsOptional, IsString, MaxLength, MinLength } from 'class-validator';

export class CreateBookRequestDto {
  @IsString()
  @MinLength(2)
  @MaxLength(200)
  title: string;

  @IsOptional()
  @IsString()
  @MaxLength(200)
  author?: string;

  /// Rar completat (dacă omul ar fi avut ISBN-ul, căutarea l-ar fi găsit), dar
  /// când există e cea mai bună cheie de căutare pe care o putem da mai
  /// departe magazinelor - de aceea rămâne în formular.
  @IsOptional()
  @IsString()
  @MaxLength(20)
  isbn?: string;

  @IsOptional()
  @IsString()
  @MaxLength(500)
  note?: string;
}
