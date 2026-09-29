import { BookshelfStatus } from '@prisma/client';
import { IsBoolean, IsEnum, IsOptional } from 'class-validator';

/**
 * Modificare parțială a unei cărți din My Shelf. Câmpurile sunt independente
 * - „Deținută" și statusul de lectură nu se exclud - iar un câmp absent nu se
 * atinge. `status: null` scoate cartea de pe raftul de lectură (Citite / De
 * citit / Citesc acum) fără s-o scoată din „Deținute".
 */
export class UpdateShelfEntryDto {
  @IsOptional()
  @IsEnum(BookshelfStatus, { message: 'Status invalid' })
  status?: BookshelfStatus | null;

  @IsOptional()
  @IsBoolean()
  owned?: boolean;
}
