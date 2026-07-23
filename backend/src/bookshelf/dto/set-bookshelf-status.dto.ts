import { IsEnum } from 'class-validator';
import { BookshelfStatus } from '@prisma/client';

export class SetBookshelfStatusDto {
  @IsEnum(BookshelfStatus, { message: 'Status invalid' })
  status: BookshelfStatus;
}
