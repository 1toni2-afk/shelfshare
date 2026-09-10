import {
  ArrayMaxSize,
  ArrayNotEmpty,
  IsArray,
  IsString,
} from 'class-validator';

/// Ștergerea în masă din „Cărțile mele". Plafonul ține requestul scurt: mai
/// mult de atât înseamnă oricum „golește tot", ceea ce se face din mai multe
/// pase.
export class BatchDeleteBooksDto {
  @IsArray()
  @ArrayNotEmpty()
  @ArrayMaxSize(200)
  @IsString({ each: true })
  userBookIds!: string[];
}
