import { IsIn, IsString, MaxLength, MinLength } from 'class-validator';

export class RegisterDeviceTokenDto {
  @IsString()
  @MinLength(10)
  @MaxLength(500)
  token: string;

  @IsIn(['android', 'ios', 'web'])
  platform: string;
}
