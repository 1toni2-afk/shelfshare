import {
  IsEnum,
  IsOptional,
  IsString,
  IsUUID,
  MaxLength,
} from 'class-validator';
import { ReportReason } from '@prisma/client';

export class ReportUserDto {
  @IsEnum(ReportReason, { message: 'Motiv invalid' })
  reason: ReportReason;

  @IsOptional()
  @IsString()
  @MaxLength(1000)
  details?: string;

  /** Setat când se raportează un anunț anume, nu doar userul în general. */
  @IsOptional()
  @IsUUID()
  userBookId?: string;
}
