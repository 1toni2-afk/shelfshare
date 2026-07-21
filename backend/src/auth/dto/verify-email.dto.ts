import { IsEmail, Length } from 'class-validator';

export class VerifyEmailDto {
  @IsEmail({}, { message: 'Adresa de email nu este validă' })
  email: string;

  @Length(6, 6, { message: 'Codul trebuie să aibă 6 cifre' })
  code: string;
}
