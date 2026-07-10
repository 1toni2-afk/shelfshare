import { IsEmail } from 'class-validator';

export class ForgotPasswordDto {
  @IsEmail({}, { message: 'Adresa de email nu este validă' })
  email: string;
}
