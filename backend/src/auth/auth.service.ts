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
import { CaptchaService } from '../common/captcha/captcha.service';
import { AttemptGuardService } from '../common/captcha/attempt-guard.service';
import { isDisposableEmailDomain } from '../common/utils/disposable-email-domains';
import { SecurityEventsService } from '../security-events/security-events.service';
import { RevokedTokenService } from '../common/security/revoked-token.service';
import { RegisterDto } from './dto/register.dto';
import { LoginDto } from './dto/login.dto';
import { User } from '@prisma/client';

const SALT_ROUNDS = 12;
const EMAIL_VERIFY_EXPIRY_HOURS = 24;
const RESET_PASSWORD_EXPIRY_HOURS = 1;
const LOGIN_CODE_EXPIRY_MS = 60_000;

// Email abuse protection (Milestone 17) - shared by verification + reset
// emails, since both hit the same inbox-spam / cost-abuse surface.
const EMAIL_SEND_COOLDOWN_MS = 45_000;
const EMAIL_SEND_WINDOW_MS = 24 * 60 * 60 * 1000;
const EMAIL_SEND_DAILY_LIMIT = 10;

// Account lockout (Milestone 17) after repeated failed logins.
const MAX_FAILED_LOGIN_ATTEMPTS = 8;
const LOGIN_LOCKOUT_MS = 15 * 60 * 1000;

/** Cod de confirmare pe 6 cifre - mai simplu de introdus manual decât un link, imun la cache-ul browserului. */
function generateVerificationCode(): string {
  return crypto.randomInt(0, 1_000_000).toString().padStart(6, '0');
}

/** Comparație în timp constant pentru codurile de verificare/resetare. */
function codesMatch(stored: string, submitted: string): boolean {
  const storedBuf = Buffer.from(stored);
  const submittedBuf = Buffer.from(submitted);
  if (storedBuf.length !== submittedBuf.length) {
    crypto.timingSafeEqual(storedBuf, storedBuf); // păstrează timpul constant
    return false;
  }
  return crypto.timingSafeEqual(storedBuf, submittedBuf);
}

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
    private captcha: CaptchaService,
    private attemptGuard: AttemptGuardService,
    private securityEvents: SecurityEventsService,
    private revokedTokens: RevokedTokenService,
  ) {}

  /**
   * Step-up captcha: normal single/double attempts never see this, only
   * an (IP, email) pair repeatedly hitting the same auth endpoint
   * (register/login/forgot-password) within 15 minutes. Keyed by email too,
   * not just IP, so several people on the same network logging into
   * different accounts don't share one counter. Older app builds that don't
   * yet send captchaToken/captchaAnswer simply get blocked past the
   * threshold instead of degrading - acceptable since legitimate users
   * essentially never retry these flows 4+ times in a quarter hour.
   */
  private requireCaptchaIfSuspicious(
    scope: string,
    ip: string,
    dto: {
      captchaToken?: string;
      captchaAnswer?: number;
    },
    identifier?: string,
  ) {
    if (!this.attemptGuard.shouldChallenge(scope, ip, identifier)) return;
    if (!this.captcha.verify(dto.captchaToken, dto.captchaAnswer)) {
      throw new BadRequestException({
        statusCode: 400,
        requiresCaptcha: true,
        captcha: this.captcha.generate(),
        message: 'Prea multe încercări - rezolvă captcha pentru a continua',
      });
    }
  }

  /** Cooldown + daily cap comun pentru emailurile de verificare/resetare. */
  private canSendAuthEmail(user: {
    lastAuthEmailSentAt: Date | null;
    authEmailWindowStart: Date | null;
    authEmailSentCount: number;
  }): boolean {
    const now = Date.now();
    if (
      user.lastAuthEmailSentAt &&
      now - user.lastAuthEmailSentAt.getTime() < EMAIL_SEND_COOLDOWN_MS
    ) {
      return false;
    }
    const withinWindow =
      user.authEmailWindowStart &&
      now - user.authEmailWindowStart.getTime() < EMAIL_SEND_WINDOW_MS;
    if (withinWindow && user.authEmailSentCount >= EMAIL_SEND_DAILY_LIMIT) {
      return false;
    }
    return true;
  }

  private async recordAuthEmailSend(
    userId: string,
    user: { authEmailWindowStart: Date | null; authEmailSentCount: number },
  ) {
    const now = new Date();
    const windowStillOpen =
      user.authEmailWindowStart &&
      now.getTime() - user.authEmailWindowStart.getTime() <
        EMAIL_SEND_WINDOW_MS;

    await this.users.update(userId, {
      lastAuthEmailSentAt: now,
      authEmailWindowStart: windowStillOpen ? user.authEmailWindowStart! : now,
      authEmailSentCount: windowStillOpen ? user.authEmailSentCount + 1 : 1,
    });
  }

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

  async register(dto: RegisterDto, ip: string) {
    this.requireCaptchaIfSuspicious('register', ip, dto, dto.email);

    if (isDisposableEmailDomain(dto.email)) {
      throw new BadRequestException(
        'Nu acceptăm adrese de email temporare/de unică folosință',
      );
    }

    const existing = await this.users.findByEmail(dto.email);
    if (existing) {
      throw new ConflictException('Există deja un cont cu acest email');
    }

    const hashedPassword = await bcrypt.hash(dto.password, SALT_ROUNDS);
    const emailVerifyToken = generateVerificationCode();
    const emailVerifyExpiry = new Date(
      Date.now() + EMAIL_VERIFY_EXPIRY_HOURS * 60 * 60 * 1000,
    );

    // Cod invalid/necunoscut -> ignorat silențios, nu blocăm înregistrarea
    // pentru o greșeală de tastare la un câmp opțional.
    let invitedById: string | undefined;
    if (dto.referralCode) {
      const referrer = await this.users.findByReferralCode(
        dto.referralCode.trim().toUpperCase(),
      );
      invitedById = referrer?.id;
    }

    const user = await this.users.create({
      email: dto.email,
      password: hashedPassword,
      invitedById,
    });

    await this.users.update(user.id, {
      emailVerifyToken,
      emailVerifyExpiry,
    });

    // Contul e deja creat în acest punct - dacă trimiterea emailului eșuează
    // (provider extern căzut/nesincronizat), nu vrem să întoarcem un 500 pe
    // /auth/register: userul tot există, doar că nu are (încă) codul de
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

  /**
   * Verificare prin cod pe 6 cifre (nu link) - căutăm după email, nu după
   * cod, deci codul nu trebuie să fie unic global (spre deosebire de
   * token-urile lungi de tip link, un cod pe 6 cifre chiar s-ar putea repeta
   * între doi useri diferiți la un volum mai mare).
   */
  async verifyEmail(email: string, code: string) {
    const user = await this.users.findByEmail(email);

    if (!user || !user.emailVerifyToken || !user.emailVerifyExpiry) {
      throw new BadRequestException('Cod de verificare invalid');
    }

    if (!codesMatch(user.emailVerifyToken, code)) {
      throw new BadRequestException('Cod de verificare invalid');
    }

    if (user.emailVerifyExpiry < new Date()) {
      throw new BadRequestException('Cod de verificare expirat');
    }

    await this.users.update(user.id, {
      isEmailVerified: true,
      emailVerifyToken: null,
      emailVerifyExpiry: null,
    });

    return { message: 'Email confirmat cu succes' };
  }

  /**
   * Regenerează și retrimite codul - nu dezvăluim dacă emailul există, e deja
   * verificat, sau doar a fost limitat de cooldown/plafonul zilnic (altfel
   * diferența de comportament ar deveni ea însăși un oracle de enumerare).
   */
  async resendVerificationCode(
    email: string,
    ip: string,
    captcha?: { captchaToken?: string; captchaAnswer?: number },
  ) {
    this.requireCaptchaIfSuspicious('resend-verification', ip, captcha ?? {}, email);

    const user = await this.users.findByEmail(email);
    const genericResult = {
      message: 'Dacă adresa există și nu e deja confirmată, am retrimis codul.',
    };

    if (!user || user.isEmailVerified) {
      return genericResult;
    }
    if (!this.canSendAuthEmail(user)) {
      return genericResult;
    }

    const emailVerifyToken = generateVerificationCode();
    const emailVerifyExpiry = new Date(
      Date.now() + EMAIL_VERIFY_EXPIRY_HOURS * 60 * 60 * 1000,
    );

    await this.users.update(user.id, { emailVerifyToken, emailVerifyExpiry });
    await this.recordAuthEmailSend(user.id, user);

    try {
      await this.mail.sendVerificationEmail(user.email, emailVerifyToken);
    } catch (error) {
      this.logger.error(
        `Nu am putut retrimite emailul de verificare către ${user.email}`,
        error,
      );
    }

    return genericResult;
  }

  // ---------- Login ----------

  async login(dto: LoginDto, ip: string) {
    this.requireCaptchaIfSuspicious('login', ip, dto, dto.email);

    const user = await this.users.findByEmail(dto.email);

    if (!user || !user.password) {
      throw new UnauthorizedException('Email sau parolă incorectă');
    }

    if (user.lockedUntil && user.lockedUntil.getTime() > Date.now()) {
      throw new UnauthorizedException(
        'Cont blocat temporar din cauza prea multor încercări eșuate. Încearcă din nou mai târziu.',
      );
    }

    const passwordMatches = await bcrypt.compare(dto.password, user.password);
    if (!passwordMatches) {
      await this.registerFailedLogin(user.id, user.failedLoginAttempts, ip);
      throw new UnauthorizedException('Email sau parolă incorectă');
    }

    if (!user.isEmailVerified) {
      throw new UnauthorizedException(
        'Trebuie să îți confirmi email-ul înainte de a te autentifica',
      );
    }

    if (user.failedLoginAttempts > 0 || user.lockedUntil) {
      await this.users.update(user.id, {
        failedLoginAttempts: 0,
        lockedUntil: null,
      });
    }

    await this.securityEvents.log('LOGIN_SUCCESS', user.id, ip);
    return this.issueTokens(user);
  }

  private async registerFailedLogin(
    userId: string,
    currentAttempts: number,
    ip: string,
  ) {
    const attempts = currentAttempts + 1;
    const lockedUntil =
      attempts >= MAX_FAILED_LOGIN_ATTEMPTS
        ? new Date(Date.now() + LOGIN_LOCKOUT_MS)
        : null;

    await this.users.update(userId, {
      failedLoginAttempts: lockedUntil ? 0 : attempts,
      lockedUntil,
    });

    await this.securityEvents.log('LOGIN_FAILED', userId, ip, { attempts });
    if (lockedUntil) {
      await this.securityEvents.log('ACCOUNT_LOCKED', userId, ip, {
        lockedUntil: lockedUntil.toISOString(),
      });
    }
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

  async logout(userId: string, jti?: string, exp?: number) {
    if (jti && exp) {
      this.revokedTokens.revoke(jti, exp);
    }
    await this.users.update(userId, { refreshTokenHash: null });
    return { message: 'Deconectat' };
  }

  // ---------- Forgot / reset password ----------

  async forgotPassword(
    email: string,
    ip: string,
    captcha?: { captchaToken?: string; captchaAnswer?: number },
  ) {
    this.requireCaptchaIfSuspicious('forgot-password', ip, captcha ?? {}, email);

    const user = await this.users.findByEmail(email);
    const genericResult = {
      message:
        'Dacă adresa există în sistem, vei primi un email cu instrucțiuni',
    };

    // Nu dezvăluim dacă email-ul există sau nu, ca să nu permitem enumerarea conturilor
    if (!user || !user.password) {
      return genericResult;
    }
    if (!this.canSendAuthEmail(user)) {
      return genericResult;
    }

    // Cod pe 6 cifre introdus manual în aplicație - nu mai e un link, ca să
    // evităm complet problemele de routing/cache ale linkurilor deschise
    // din emailul clientului (aceeași problemă rezolvată la verificarea de
    // email prin trecerea la cod, vezi generateVerificationCode).
    const resetPasswordToken = generateVerificationCode();
    const resetPasswordExpiry = new Date(
      Date.now() + RESET_PASSWORD_EXPIRY_HOURS * 60 * 60 * 1000,
    );

    await this.users.update(user.id, {
      resetPasswordToken,
      resetPasswordExpiry,
    });
    await this.recordAuthEmailSend(user.id, user);

    try {
      await this.mail.sendPasswordResetEmail(user.email, resetPasswordToken);
    } catch (error) {
      this.logger.error(
        `Nu am putut trimite emailul de resetare parolă către ${user.email}`,
        error,
      );
    }

    return genericResult;
  }

  /** Validează codul fără să-l consume - userul mai are nevoie de el la resetPassword(). */
  async verifyResetCode(email: string, code: string) {
    const user = await this.users.findByEmail(email);

    if (!user || !user.resetPasswordToken || !user.resetPasswordExpiry) {
      throw new BadRequestException('Cod de resetare invalid');
    }

    if (!codesMatch(user.resetPasswordToken, code)) {
      throw new BadRequestException('Cod de resetare invalid');
    }

    if (user.resetPasswordExpiry < new Date()) {
      throw new BadRequestException('Cod de resetare expirat');
    }

    return { message: 'Cod valid' };
  }

  async resetPassword(
    email: string,
    code: string,
    newPassword: string,
    ip: string,
  ) {
    const user = await this.users.findByEmail(email);

    if (!user || !user.resetPasswordToken || !user.resetPasswordExpiry) {
      throw new BadRequestException('Cod de resetare invalid');
    }

    if (!codesMatch(user.resetPasswordToken, code)) {
      throw new BadRequestException('Cod de resetare invalid');
    }

    if (user.resetPasswordExpiry < new Date()) {
      throw new BadRequestException('Cod de resetare expirat');
    }

    const hashedPassword = await bcrypt.hash(newPassword, SALT_ROUNDS);

    await this.users.update(user.id, {
      password: hashedPassword,
      resetPasswordToken: null,
      resetPasswordExpiry: null,
      refreshTokenHash: null, // invalidăm orice sesiune activă
      failedLoginAttempts: 0,
      lockedUntil: null,
    });

    await this.securityEvents.log('PASSWORD_RESET', user.id, ip);
    return { message: 'Parolă schimbată cu succes' };
  }

  // ---------- Helpers ----------

  private async issueTokens(user: User) {
    const payload = { sub: user.id, email: user.email };
    // jti unic pe access token, ca logout() să poată revoca exact acest
    // token (vezi RevokedTokenService) - fără el, un token furat rămâne
    // valid până expiră singur, indiferent de logout.
    const accessPayload = { ...payload, jti: crypto.randomUUID() };

    const accessToken = this.jwt.sign(accessPayload, {
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
        isPremium: user.isPremium,
      },
    };
  }
}
