import { IsString } from 'class-validator';

export class AddBookToCollectionDto {
  @IsString()
  bookId: string;
}
