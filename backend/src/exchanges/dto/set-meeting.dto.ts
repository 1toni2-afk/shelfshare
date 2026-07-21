import { IsDateString } from 'class-validator';

export class SetMeetingDto {
  @IsDateString()
  meetingAt: string;
}
