import { IsEmail } from 'class-validator';

export class ResendVerificationDto {
  @IsEmail({}, { message: 'Adresa de email nu este validă' })
  email: string;
}
