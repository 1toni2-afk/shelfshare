import { IsString, MinLength } from 'class-validator';

export class ResetPasswordDto {
  @IsString()
  token: string;

  @IsString()
  @MinLength(8, { message: 'Parola trebuie să aibă minim 8 caractere' })
  newPassword: string;
}
