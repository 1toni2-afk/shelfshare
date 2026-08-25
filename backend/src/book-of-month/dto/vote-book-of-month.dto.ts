import { IsString, IsUUID } from 'class-validator';

export class VoteBookOfMonthDto {
  @IsString()
  @IsUUID()
  bookId: string;
}
