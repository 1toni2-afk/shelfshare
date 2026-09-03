import { IsEnum, IsOptional } from 'class-validator';
import { ReportStatus, ReportTargetType } from '@prisma/client';

/**
 * Filtrele cozii de moderare. Ambele opționale: fără ele, panoul arată tot,
 * exact ca înainte de a exista filtrarea.
 */
export class ListReportsDto {
  /** user / listing / review / conversation / group post / exchange */
  @IsOptional()
  @IsEnum(ReportTargetType, { message: 'Tip de țintă invalid' })
  targetType?: ReportTargetType;

  @IsOptional()
  @IsEnum(ReportStatus, { message: 'Status invalid' })
  status?: ReportStatus;
}
