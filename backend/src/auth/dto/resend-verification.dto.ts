import { IsNormalizedEmail } from '../../common/decorators/normalized-email.decorator';
export class ResendVerificationDto {
  @IsNormalizedEmail()
  email: string;
}
