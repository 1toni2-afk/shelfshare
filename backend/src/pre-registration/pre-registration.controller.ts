import {
  Body,
  Controller,
  HttpCode,
  HttpStatus,
  Post,
  Req,
  UseGuards,
} from '@nestjs/common';
import { IsEmail, IsOptional, MaxLength } from 'class-validator';
import type { Request } from 'express';
import { OptionalJwtAuthGuard } from '../auth/guards/optional-jwt-auth.guard';
import type { AuthenticatedUser } from '../auth/types/authenticated-user';
import { PreRegistrationService } from './pre-registration.service';

class PreRegistrationDto {
  @IsEmail({}, { message: 'Email invalid' })
  @MaxLength(254)
  email!: string;

  @IsOptional()
  @MaxLength(60)
  source?: string;
}

/// Ruta e publică (pentru vizitatori care nu au încă cont) dar acceptă
/// opțional token JWT - dacă e prezent, legăm pre-înscrierea de userId, ca
/// să știm cine s-a pre-înscris deja din aplicație.
@Controller('pre-registration')
export class PreRegistrationController {
  constructor(private service: PreRegistrationService) {}

  @UseGuards(OptionalJwtAuthGuard)
  @Post()
  @HttpCode(HttpStatus.OK)
  async register(@Req() req: Request, @Body() dto: PreRegistrationDto) {
    const user = req.user as AuthenticatedUser | undefined;
    await this.service.register(dto.email, user?.userId);
    return { message: 'Te-am adăugat pe lista de pre-înscriere.' };
  }
}
