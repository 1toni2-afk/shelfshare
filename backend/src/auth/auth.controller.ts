import {
  Body,
  Controller,
  Get,
  HttpCode,
  HttpStatus,
  Logger,
  Post,
  Req,
  Res,
  UseGuards,
} from '@nestjs/common';
import { Throttle } from '@nestjs/throttler';
import type { Request, Response } from 'express';
import { AuthService } from './auth.service';
import { CaptchaService } from '../common/captcha/captcha.service';
import { RegisterDto } from './dto/register.dto';
import { LoginDto } from './dto/login.dto';
import { VerifyEmailDto } from './dto/verify-email.dto';
import { ResendVerificationDto } from './dto/resend-verification.dto';
import { ForgotPasswordDto } from './dto/forgot-password.dto';
import { VerifyResetCodeDto } from './dto/verify-reset-code.dto';
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
    private captchaService: CaptchaService,
  ) {}

  /** Folosit doar când serverul semnalează requiresCaptcha (vezi AuthService.requireCaptchaIfSuspicious). */
  @Get('captcha')
  getCaptcha() {
    return this.captchaService.generate();
  }

  @Throttle({ default: { limit: 10, ttl: 3_600_000 } })
  @Post('register')
  register(@Req() req: Request, @Body() dto: RegisterDto) {
    return this.authService.register(dto, req.ip ?? '');
  }

  // 6-digit codes (1e6 space) - keep guess attempts per IP low enough that
  // brute-forcing one within its validity window is impractical.
  @Throttle({ default: { limit: 20, ttl: 3_600_000 } })
  @Post('verify-email')
  @HttpCode(HttpStatus.OK)
  verifyEmail(@Body() dto: VerifyEmailDto) {
    return this.authService.verifyEmail(dto.email, dto.code);
  }

  @Throttle({ default: { limit: 5, ttl: 3_600_000 } })
  @Post('resend-verification')
  @HttpCode(HttpStatus.OK)
  resendVerification(@Req() req: Request, @Body() dto: ResendVerificationDto) {
    return this.authService.resendVerificationCode(
      dto.email,
      req.ip ?? '',
      dto,
    );
  }

  @Throttle({ default: { limit: 10, ttl: 60_000 } })
  @Post('login')
  @HttpCode(HttpStatus.OK)
  login(@Req() req: Request, @Body() dto: LoginDto) {
    return this.authService.login(dto, req.ip ?? '');
  }

  @Throttle({ default: { limit: 5, ttl: 3_600_000 } })
  @Post('forgot-password')
  @HttpCode(HttpStatus.OK)
  forgotPassword(@Req() req: Request, @Body() dto: ForgotPasswordDto) {
    return this.authService.forgotPassword(dto.email, req.ip ?? '', dto);
  }

  @Throttle({ default: { limit: 20, ttl: 3_600_000 } })
  @Post('verify-reset-code')
  @HttpCode(HttpStatus.OK)
  verifyResetCode(@Body() dto: VerifyResetCodeDto) {
    return this.authService.verifyResetCode(dto.email, dto.code);
  }

  @Throttle({ default: { limit: 10, ttl: 3_600_000 } })
  @Post('reset-password')
  @HttpCode(HttpStatus.OK)
  resetPassword(@Req() req: Request, @Body() dto: ResetPasswordDto) {
    return this.authService.resetPassword(
      dto.email,
      dto.code,
      dto.newPassword,
      req.ip ?? '',
    );
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
    const { userId, jti, exp } = req.user as AuthenticatedUser;
    return this.authService.logout(userId!, jti, exp);
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
