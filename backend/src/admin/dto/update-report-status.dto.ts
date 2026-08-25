import { IsEnum, IsOptional, IsString, MaxLength } from 'class-validator';
import { ReportStatus } from '@prisma/client';

export class UpdateReportStatusDto {
  @IsEnum(ReportStatus, { message: 'Status invalid' })
  status: ReportStatus;

  @IsOptional()
  @IsString()
  @MaxLength(1000)
  resolutionNote?: string;
}
