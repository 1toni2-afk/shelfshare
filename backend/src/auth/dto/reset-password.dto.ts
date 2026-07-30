import { IsString, Length, MinLength } from 'class-validator';
import { IsNormalizedEmail } from '../../common/decorators/normalized-email.decorator';

export class ResetPasswordDto {
  @IsNormalizedEmail()
  email: string;

  @Length(6, 6, { message: 'Codul trebuie să aibă 6 cifre' })
  code: string;

  @IsString()
  @MinLength(8, { message: 'Parola trebuie să aibă minim 8 caractere' })
  newPassword: string;
}
