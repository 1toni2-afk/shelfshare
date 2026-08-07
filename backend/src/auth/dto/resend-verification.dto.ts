import { IsInt, IsOptional, IsString } from 'class-validator';
import { IsNormalizedEmail } from '../../common/decorators/normalized-email.decorator';

export class ResendVerificationDto {
  @IsNormalizedEmail()
  email: string;

  @IsOptional()
  @IsString()
  captchaToken?: string;

  @IsOptional()
  @IsInt()
  captchaAnswer?: number;
}
