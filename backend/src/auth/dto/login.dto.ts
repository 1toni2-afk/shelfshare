import { IsString } from 'class-validator';
import { IsNormalizedEmail } from '../../common/decorators/normalized-email.decorator';

export class LoginDto {
  @IsNormalizedEmail()
  email: string;

  @IsString()
  password: string;
}
