import { IsISO8601, IsString, MaxLength, MinLength } from 'class-validator';

export class SetMeetingDto {
  @IsISO8601()
  meetingTime: string;

  @IsString()
  @MinLength(1)
  @MaxLength(200)
  meetingLocation: string;
}
