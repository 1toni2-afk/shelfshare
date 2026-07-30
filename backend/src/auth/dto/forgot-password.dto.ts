import { IsNormalizedEmail } from '../../common/decorators/normalized-email.decorator';
export class ForgotPasswordDto {
  @IsNormalizedEmail()
  email: string;
}
