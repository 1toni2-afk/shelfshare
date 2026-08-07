import { IsInt, IsOptional, IsString, MaxLength } from 'class-validator';
import { IsNormalizedEmail } from '../../common/decorators/normalized-email.decorator';

export class LoginDto {
  @IsNormalizedEmail()
  email: string;

  @IsString()
  @MaxLength(200)
  password: string;

  @IsOptional()
  @IsString()
  captchaToken?: string;

  @IsOptional()
  @IsInt()
  captchaAnswer?: number;
}
