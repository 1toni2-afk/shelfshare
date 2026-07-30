import { Length } from 'class-validator';
import { IsNormalizedEmail } from '../../common/decorators/normalized-email.decorator';

export class VerifyEmailDto {
  @IsNormalizedEmail()
  email: string;

  @Length(6, 6, { message: 'Codul trebuie să aibă 6 cifre' })
  code: string;
}
