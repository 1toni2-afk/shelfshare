import { IsEmail, IsString, MinLength } from 'class-validator';

export class RegisterDto {
  @IsEmail({}, { message: 'Adresa de email nu este validă' })
  email: string;

  @IsString()
  @MinLength(8, { message: 'Parola trebuie să aibă minim 8 caractere' })
  password: string;
}
