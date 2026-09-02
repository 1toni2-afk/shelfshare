import {
  ArrayMaxSize,
  IsArray,
  IsBoolean,
  IsEnum,
  IsInt,
  IsISBN,
  IsOptional,
  IsString,
  IsUUID,
  Max,
  MaxLength,
  Min,
} from 'class-validator';
import { BookCondition } from '@prisma/client';

/**
 * O carte nu poate porni "la vânzare" chiar la creare - fotografiile se
 * urcă printr-un apel separat, DUPĂ ce anunțul există deja, deci n-ar putea
 * niciodată trece verificarea "cel puțin o poză" din updateUserBook. Fluxul
 * corect: se creează anunțul (mereu isForSale: false), se urcă pozele, apoi
 * clientul trece explicit la vânzare prin PATCH /books/:id (updateUserBook).
 */
export class AddBookDto {
  /// Cartea din catalog pe care o listăm, când o știm deja - cazul „Listeaz-o"
  /// de pe o carte din raftul personal. Fără el, o carte fără ISBN ar fi
  /// duplicată în catalog (vezi findOrCreateBook), iar raftul ar arăta și
  /// intrarea veche, și listarea nouă, ca două cărți diferite.
  @IsOptional()
  @IsUUID()
  bookId?: string;

  @IsOptional()
  @IsISBN(undefined, { message: 'ISBN invalid' })
  isbn?: string;

  @IsOptional()
  @IsString()
  @MaxLength(300)
  title?: string;

  @IsOptional()
  @IsString()
  @MaxLength(200)
  author?: string;

  @IsEnum(BookCondition, { message: 'Stare invalidă' })
  condition: BookCondition;

  @IsOptional()
  @IsString()
  @MaxLength(10)
  language?: string;

  @IsOptional()
  @IsString()
  @MaxLength(100)
  edition?: string;

  @IsOptional()
  @IsBoolean()
  isHardcover?: boolean;

  // ---------- Metadate opționale pentru operă (Milestone 10) ----------
  // Astea populează entitatea Book (partajată) doar dacă o creăm nouă -
  // pentru cărți deja existente în catalog, câmpurile din DTO sunt ignorate,
  // ca să nu suprascriem date populate de alți useri sau de lookup extern.

  @IsOptional()
  @IsString()
  @MaxLength(100)
  genre?: string;

  // Feature backlog #7 - deliberat ACCEPTATE chiar și când cartea e găsită
  // extern (spre deosebire de genre/publisher, ignorate în acel caz): nicio
  // sursă externă (Open Library/Google Books) nu întoarce serie structurată,
  // deci nu există risc de suprascriere a unei valori mai bune venite din
  // lookup - vezi findOrCreateBook.
  @IsOptional()
  @IsString()
  @MaxLength(150)
  series?: string;

  @IsOptional()
  @IsInt()
  @Min(1)
  @Max(1000)
  seriesNumber?: number;

  @IsOptional()
  @IsString()
  @MaxLength(200)
  publisher?: string;

  @IsOptional()
  @IsInt()
  @Min(0)
  @Max(2100)
  publishedYear?: number;

  @IsOptional()
  @IsInt()
  @Min(1)
  @Max(2100)
  editionYear?: number;

  @IsOptional()
  @IsInt()
  @Min(1)
  @Max(30000)
  pageCount?: number;

  // ---------- Câmpuri per exemplar (Milestone 10) ----------

  @IsOptional()
  @IsString()
  @MaxLength(256, { message: 'Descrierea nu poate depăși 256 de caractere' })
  description?: string;

  @IsOptional()
  @IsArray()
  @ArrayMaxSize(5, { message: 'Poți adăuga maxim 5 taguri' })
  @IsString({ each: true })
  tags?: string[];

  @IsOptional()
  @IsString()
  @MaxLength(100)
  city?: string;

  /// URL-ul pozei principale ales de user în ecranul „Adaugă carte" (Batch 8).
  /// Poate fi o copertă externă (Open Library/Google Books) sau coperta
  /// oficială a cărții. Pozele urcate ulterior de user pot suprascrie
  /// această alegere prin PATCH /books/:id.
  @IsOptional()
  @IsString()
  @MaxLength(500)
  mainPhotoUrl?: string;
}
