import {
  IsEmail,
  IsInt,
  IsOptional,
  IsString,
  MaxLength,
  MinLength,
} from 'class-validator';

export class CreateSupportRequestDto {
  @IsString()
  @MinLength(2)
  @MaxLength(200)
  name: string;

  @IsEmail({}, { message: 'Adresa de email nu este validă' })
  email: string;

  @IsOptional()
  @IsString()
  @MaxLength(30)
  phone?: string;

  @IsString()
  @MinLength(5)
  @MaxLength(2000)
  message: string;

  @IsString()
  captchaToken: string;

  @IsInt()
  captchaAnswer: number;
}
