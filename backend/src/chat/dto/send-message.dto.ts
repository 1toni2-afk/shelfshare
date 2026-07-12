import { IsOptional, IsString, IsUUID, MaxLength } from 'class-validator';

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
}
