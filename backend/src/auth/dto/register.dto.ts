import { IsInt, IsOptional, IsString, MinLength } from 'class-validator';
import { IsNormalizedEmail } from '../../common/decorators/normalized-email.decorator';

export class RegisterDto {
  @IsNormalizedEmail()
  email: string;

  @IsString()
  @MinLength(8, { message: 'Parola trebuie să aibă minim 8 caractere' })
  password: string;

  @IsOptional()
  @IsString()
  referralCode?: string;

  // Cerute doar dacă serverul semnalează requiresCaptcha (vezi AttemptGuardService) -
  // clientul obișnuit nu le trimite la prima încercare.
  @IsOptional()
  @IsString()
  captchaToken?: string;

  @IsOptional()
  @IsInt()
  captchaAnswer?: number;
}
