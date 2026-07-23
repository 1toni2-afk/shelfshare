import { IsEmail, IsString, Length, MinLength } from 'class-validator';

export class ResetPasswordDto {
  @IsEmail({}, { message: 'Adresa de email nu este validă' })
  email: string;

  @Length(6, 6, { message: 'Codul trebuie să aibă 6 cifre' })
  code: string;

  @IsString()
  @MinLength(8, { message: 'Parola trebuie să aibă minim 8 caractere' })
  newPassword: string;
}
