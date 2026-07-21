import {
  BadRequestException,
  ConflictException,
  Injectable,
  Logger,
  UnauthorizedException,
} from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { ConfigService } from '@nestjs/config';
import * as bcrypt from 'bcrypt';
import * as crypto from 'crypto';
import type { SignOptions } from 'jsonwebtoken';
import { UsersService } from '../users/users.service';
import { MailService } from '../mail/mail.service';
import { RegisterDto } from './dto/register.dto';
import { LoginDto } from './dto/login.dto';
import { User } from '@prisma/client';

const SALT_ROUNDS = 12;
const EMAIL_VERIFY_EXPIRY_HOURS = 24;
const RESET_PASSWORD_EXPIRY_HOURS = 1;
const LOGIN_CODE_EXPIRY_MS = 60_000;

interface PendingLoginTokens {
  accessToken: string;
  refreshToken: string;
  expiresAt: number;
}

@Injectable()
export class AuthService {
  private readonly logger = new Logger(AuthService.name);

  // Coduri de schimb pentru fluxul OAuth (Google) - single-use, expiră rapid.
  // Token-urile nu mai tranzitează niciodată URL-ul de redirect al browserului,
  // doar acest cod opac; frontend-ul le ia printr-un apel API separat.
  private readonly pendingLoginCodes = new Map<string, PendingLoginTokens>();

  constructor(
    private users: UsersService,
    private jwt: JwtService,
    private config: ConfigService,
    private mail: MailService,
  ) {}

  createLoginCode(tokens: { accessToken: string; refreshToken: string }) {
    const code = crypto.randomBytes(24).toString('hex');
    this.pendingLoginCodes.set(code, {
      ...tokens,
      expiresAt: Date.now() + LOGIN_CODE_EXPIRY_MS,
    });
    return code;
  }

  exchangeLoginCode(code: string) {
    const pending = this.pendingLoginCodes.get(code);
    this.pendingLoginCodes.delete(code); // single-use, indiferent de rezultat

    if (!pending || pending.expiresAt < Date.now()) {
      throw new BadRequestException('Cod de autentificare invalid sau expirat');
    }

    return {
      accessToken: pending.accessToken,
      refreshToken: pending.refreshToken,
    };
  }

  // ---------- Register ----------

  async register(dto: RegisterDto) {
    const existing = await this.users.findByEmail(dto.email);
    if (existing) {
      throw new ConflictException('Există deja un cont cu acest email');
    }

    const hashedPassword = await bcrypt.hash(dto.password, SALT_ROUNDS);
    const emailVerifyToken = crypto.randomBytes(32).toString('hex');
    const emailVerifyExpiry = new Date(
      Date.now() + EMAIL_VERIFY_EXPIRY_HOURS * 60 * 60 * 1000,
    );

    const user = await this.users.create({
      email: dto.email,
      password: hashedPassword,
    });

    await this.users.update(user.id, {
      emailVerifyToken,
      emailVerifyExpiry,
    });

    // Contul e deja creat în acest punct - dacă trimiterea emailului eșuează
    // (provider extern căzut/nesincronizat), nu vrem să întoarcem un 500 pe
    // /auth/register: userul tot există, doar că nu are (încă) linkul de
    // verificare. Logăm eroarea ca să fie vizibilă operațional.
    try {
      await this.mail.sendVerificationEmail(user.email, emailVerifyToken);
    } catch (error) {
      this.logger.error(
        `Nu am putut trimite emailul de verificare către ${user.email}`,
        error,
      );
    }

    return {
      message: 'Cont creat. Verifică-ți email-ul pentru a-ți activa contul.',
    };
  }

  // ---------- Verificare email ----------

  async verifyEmail(token: string) {
    const user = await this.users.findByEmailVerifyToken(token);

    if (!user || !user.emailVerifyExpiry) {
      throw new BadRequestException('Token de verificare invalid');
    }

    if (user.emailVerifyExpiry < new Date()) {
      throw new BadRequestException('Token de verificare expirat');
    }

    await this.users.update(user.id, {
      isEmailVerified: true,
      emailVerifyToken: null,
      emailVerifyExpiry: null,
    });

    return { message: 'Email confirmat cu succes' };
  }

  // ---------- Login ----------

  async login(dto: LoginDto) {
    const user = await this.users.findByEmail(dto.email);

    if (!user || !user.password) {
      throw new UnauthorizedException('Email sau parolă incorectă');
    }

    const passwordMatches = await bcrypt.compare(dto.password, user.password);
    if (!passwordMatches) {
      throw new UnauthorizedException('Email sau parolă incorectă');
    }

    if (!user.isEmailVerified) {
      throw new UnauthorizedException(
        'Trebuie să îți confirmi email-ul înainte de a te autentifica',
      );
    }

    return this.issueTokens(user);
  }

  // ---------- Google OAuth ----------

  async loginWithGoogle(googleUser: { googleId: string; email: string }) {
    let user = await this.users.findByGoogleId(googleUser.googleId);

    if (!user) {
      // poate există deja un cont cu acest email, creat prin email+parolă -> îl legăm
      user = await this.users.findByEmail(googleUser.email);

      if (user) {
        user = await this.users.update(user.id, {
          googleId: googleUser.googleId,
          isEmailVerified: true, // Google a verificat deja email-ul
        });
      } else {
        user = await this.users.create({
          email: googleUser.email,
          googleId: googleUser.googleId,
          isEmailVerified: true,
        });
      }
    }

    return this.issueTokens(user);
  }

  // ---------- Refresh token ----------

  async refresh(userId: string, refreshToken: string) {
    const user = await this.users.findById(userId);

    if (!user || !user.refreshTokenHash) {
      throw new UnauthorizedException('Sesiune invalidă');
    }

    const matches = await bcrypt.compare(refreshToken, user.refreshTokenHash);
    if (!matches) {
      throw new UnauthorizedException('Sesiune invalidă');
    }

    return this.issueTokens(user);
  }

  async logout(userId: string) {
    await this.users.update(userId, { refreshTokenHash: null });
    return { message: 'Deconectat' };
  }

  // ---------- Forgot / reset password ----------

  async forgotPassword(email: string) {
    const user = await this.users.findByEmail(email);

    // Nu dezvăluim dacă email-ul există sau nu, ca să nu permitem enumerarea conturilor
    if (!user || !user.password) {
      return {
        message:
          'Dacă adresa există în sistem, vei primi un email cu instrucțiuni',
      };
    }

    const resetPasswordToken = crypto.randomBytes(32).toString('hex');
    const resetPasswordExpiry = new Date(
      Date.now() + RESET_PASSWORD_EXPIRY_HOURS * 60 * 60 * 1000,
    );

    await this.users.update(user.id, {
      resetPasswordToken,
      resetPasswordExpiry,
    });

    try {
      await this.mail.sendPasswordResetEmail(user.email, resetPasswordToken);
    } catch (error) {
      this.logger.error(
        `Nu am putut trimite emailul de resetare parolă către ${user.email}`,
        error,
      );
    }

    return {
      message:
        'Dacă adresa există în sistem, vei primi un email cu instrucțiuni',
    };
  }

  async resetPassword(token: string, newPassword: string) {
    const user = await this.users.findByResetPasswordToken(token);

    if (!user || !user.resetPasswordExpiry) {
      throw new BadRequestException('Token de resetare invalid');
    }

    if (user.resetPasswordExpiry < new Date()) {
      throw new BadRequestException('Token de resetare expirat');
    }

    const hashedPassword = await bcrypt.hash(newPassword, SALT_ROUNDS);

    await this.users.update(user.id, {
      password: hashedPassword,
      resetPasswordToken: null,
      resetPasswordExpiry: null,
      refreshTokenHash: null, // invalidăm orice sesiune activă
    });

    return { message: 'Parolă schimbată cu succes' };
  }

  // ---------- Helpers ----------

  private async issueTokens(user: User) {
    const payload = { sub: user.id, email: user.email };

    const accessToken = this.jwt.sign(payload, {
      secret: this.config.get<string>('JWT_ACCESS_SECRET'),
      expiresIn: this.config.get<string>(
        'JWT_ACCESS_EXPIRY',
        '15m',
      ) as SignOptions['expiresIn'],
    });

    const refreshToken = this.jwt.sign(payload, {
      secret: this.config.get<string>('JWT_REFRESH_SECRET'),
      expiresIn: this.config.get<string>(
        'JWT_REFRESH_EXPIRY',
        '30d',
      ) as SignOptions['expiresIn'],
    });

    const refreshTokenHash = await bcrypt.hash(refreshToken, SALT_ROUNDS);
    await this.users.update(user.id, { refreshTokenHash });

    return {
      accessToken,
      refreshToken,
      user: {
        id: user.id,
        email: user.email,
        isEmailVerified: user.isEmailVerified,
        isAdmin: user.isAdmin,
      },
    };
  }
}
