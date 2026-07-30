import {
  ArrayMaxSize,
  IsArray,
  IsIn,
  IsOptional,
  IsString,
  MaxLength,
} from 'class-validator';

/** Ritmul de citire, ca text scurt - doar informativ pe profil. */
export const READING_PACES = ['1', '2-3', '4+'] as const;

export class ReadingSurveyDto {
  /**
   * Genurile NU sunt validate contra listei din book-genres.ts: `books.genre`
   * e text liber (vine și din surse externe), iar dacă mâine adăugăm un gen nou
   * în UI n-ar trebui să fie nevoie de o migrație de validare. Limităm doar
   * numărul și lungimea, cât să nu se poată îndesa date arbitrare.
   */
  @IsOptional()
  @IsArray()
  @ArrayMaxSize(20)
  @IsString({ each: true })
  @MaxLength(60, { each: true })
  favoriteGenres?: string[];

  @IsOptional()
  @IsArray()
  @ArrayMaxSize(20)
  @IsString({ each: true })
  @MaxLength(120, { each: true })
  favoriteAuthors?: string[];

  @IsOptional()
  @IsIn(READING_PACES, { message: 'Ritm de citire invalid' })
  readingPace?: string;
}
