import {
  Body,
  Controller,
  Get,
  HttpCode,
  HttpStatus,
  Logger,
  Post,
  Query,
  Req,
  Res,
  UseGuards,
} from '@nestjs/common';
import type { Request, Response } from 'express';
import { AuthService } from './auth.service';
import { RegisterDto } from './dto/register.dto';
import { LoginDto } from './dto/login.dto';
import { ForgotPasswordDto } from './dto/forgot-password.dto';
import { ResetPasswordDto } from './dto/reset-password.dto';
import { ExchangeLoginCodeDto } from './dto/exchange-login-code.dto';
import { JwtRefreshGuard } from './guards/jwt-refresh.guard';
import { GoogleAuthGuard } from './guards/google-auth.guard';
import { JwtAuthGuard } from './guards/jwt-auth.guard';
import { ConfigService } from '@nestjs/config';
import type { AuthenticatedUser } from './types/authenticated-user';

@Controller('auth')
export class AuthController {
  private readonly logger = new Logger(AuthController.name);

  constructor(
    private authService: AuthService,
    private config: ConfigService,
  ) {}

  @Post('register')
  register(@Body() dto: RegisterDto) {
    return this.authService.register(dto);
  }

  @Get('verify-email')
  verifyEmail(@Query('token') token: string) {
    return this.authService.verifyEmail(token);
  }

  @Post('login')
  @HttpCode(HttpStatus.OK)
  login(@Body() dto: LoginDto) {
    return this.authService.login(dto);
  }

  @Post('forgot-password')
  @HttpCode(HttpStatus.OK)
  forgotPassword(@Body() dto: ForgotPasswordDto) {
    return this.authService.forgotPassword(dto.email);
  }

  @Post('reset-password')
  @HttpCode(HttpStatus.OK)
  resetPassword(@Body() dto: ResetPasswordDto) {
    return this.authService.resetPassword(dto.token, dto.newPassword);
  }

  @UseGuards(JwtRefreshGuard)
  @Post('refresh')
  @HttpCode(HttpStatus.OK)
  refresh(@Req() req: Request) {
    const { userId, refreshToken } = req.user as AuthenticatedUser;
    return this.authService.refresh(userId!, refreshToken!);
  }

  @UseGuards(JwtAuthGuard)
  @Post('logout')
  @HttpCode(HttpStatus.OK)
  logout(@Req() req: Request) {
    const { userId } = req.user as AuthenticatedUser;
    return this.authService.logout(userId!);
  }

  // ---------- Google OAuth ----------

  @UseGuards(GoogleAuthGuard)
  @Get('google')
  googleLogin() {
    // Passport redirecționează automat către Google - nu ajunge cod aici
  }

  @UseGuards(GoogleAuthGuard)
  @Get('google/callback')
  async googleCallback(@Req() req: Request, @Res() res: Response) {
    const frontendUrl = this.config.get<string>(
      'FRONTEND_URL',
      'http://localhost:5959',
    );

    try {
      const { googleId, email } = req.user as AuthenticatedUser;
      const tokens = await this.authService.loginWithGoogle({
        googleId: googleId!,
        email,
      });

      // Token-urile nu ajung niciodată în URL-ul redirectului (ar rămâne în
      // istoricul browserului și în loguri) - trimitem doar un cod opac,
      // single-use, pe care frontend-ul îl schimbă printr-un apel API separat.
      const code = this.authService.createLoginCode(tokens);
      const redirectUrl = new URL('/auth/google/callback', frontendUrl);
      redirectUrl.searchParams.set('code', code);
      res.redirect(redirectUrl.toString());
    } catch (error) {
      this.logger.error(`Autentificare Google eșuată: ${error}`);
      const errorUrl = new URL('/login', frontendUrl);
      errorUrl.searchParams.set('error', 'google_auth_failed');
      res.redirect(errorUrl.toString());
    }
  }

  @Post('google/exchange')
  @HttpCode(HttpStatus.OK)
  exchangeGoogleCode(@Body() dto: ExchangeLoginCodeDto) {
    return this.authService.exchangeLoginCode(dto.code);
  }
}
