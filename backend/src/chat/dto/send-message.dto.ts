import {
  IsDateString,
  IsLatitude,
  IsLongitude,
  IsOptional,
  IsString,
  IsUUID,
  MaxLength,
} from 'class-validator';

export class SendMessageDto {
  @IsUUID()
  conversationId: string;

  @IsOptional()
  @IsString()
  @MaxLength(2000)
  content?: string;

  @IsOptional()
  @IsString()
  location?: string;

  @IsOptional()
  @IsLatitude()
  locationLat?: number;

  @IsOptional()
  @IsLongitude()
  locationLng?: number;

  @IsOptional()
  @IsDateString()
  meetingAt?: string;
}
