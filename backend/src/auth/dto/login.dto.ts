import { IsEmail, IsString } from 'class-validator';

export class LoginDto {
  @IsEmail({}, { message: 'Adresa de email nu este validă' })
  email: string;

  @IsString()
  password: string;
}
