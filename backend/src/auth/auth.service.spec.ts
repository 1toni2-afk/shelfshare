import { Test, TestingModule } from '@nestjs/testing';
import { JwtService } from '@nestjs/jwt';
import { ConfigService } from '@nestjs/config';
import { ConflictException, UnauthorizedException } from '@nestjs/common';
import * as bcrypt from 'bcrypt';
import { AuthService } from './auth.service';
import { UsersService } from '../users/users.service';
import { MailService } from '../mail/mail.service';
import { CaptchaService } from '../common/captcha/captcha.service';
import { AttemptGuardService } from '../common/captcha/attempt-guard.service';
import { SecurityEventsService } from '../security-events/security-events.service';
import { RevokedTokenService } from '../common/security/revoked-token.service';
import { UserSessionsService } from '../common/security/user-sessions.service';
import { PrismaService } from '../prisma/prisma.service';

jest.mock('bcrypt');

const IP = '127.0.0.1';

describe('AuthService', () => {
  let service: AuthService;
  let users: jest.Mocked<UsersService>;
  let mail: jest.Mocked<MailService>;
  const prisma = {
    refreshSession: {
      create: jest.fn(),
      findUnique: jest.fn(),
      updateMany: jest.fn().mockResolvedValue({ count: 1 }),
      deleteMany: jest.fn(),
    },
  };
  const userSessions = { revokeAll: jest.fn() };

  const baseUser = {
    id: 'user-1',
    email: 'test@example.com',
    password: 'hashed-password',
    isEmailVerified: true,
    isAdmin: false,
    isBanned: false,
    refreshTokenHash: null,
    resetPasswordExpiry: null,
    emailVerifyExpiry: null,
    failedLoginAttempts: 0,
    lockedUntil: null,
    lastAuthEmailSentAt: null,
    authEmailWindowStart: null,
    authEmailSentCount: 0,
  };

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      providers: [
        AuthService,
        {
          provide: UsersService,
          useValue: {
            findByEmail: jest.fn(),
            findById: jest.fn(),
            findByGoogleId: jest.fn(),
            create: jest.fn(),
            update: jest.fn(),
          },
        },
        {
          provide: JwtService,
          useValue: {
            sign: jest.fn().mockReturnValue('signed-token'),
            decode: jest
              .fn()
              .mockReturnValue({ exp: Math.floor(Date.now() / 1000) + 3600 }),
          },
        },
        {
          provide: ConfigService,
          useValue: {
            get: jest.fn((_key: string, fallback?: unknown) => fallback),
          },
        },
        {
          provide: MailService,
          useValue: {
            sendVerificationEmail: jest.fn(),
            sendPasswordResetEmail: jest.fn(),
          },
        },
        {
          provide: CaptchaService,
          useValue: { generate: jest.fn(), verify: jest.fn() },
        },
        {
          provide: AttemptGuardService,
          useValue: { shouldChallenge: jest.fn().mockReturnValue(false) },
        },
        {
          provide: SecurityEventsService,
          useValue: { log: jest.fn() },
        },
        {
          provide: RevokedTokenService,
          useValue: {
            revoke: jest.fn(),
            isRevoked: jest.fn().mockReturnValue(false),
          },
        },
        { provide: PrismaService, useValue: prisma },
        { provide: UserSessionsService, useValue: userSessions },
      ],
    }).compile();

    service = module.get(AuthService);
    users = module.get(UsersService);
    mail = module.get(MailService);

    (bcrypt.hash as jest.Mock).mockResolvedValue('hashed-password');
    (bcrypt.compare as jest.Mock).mockResolvedValue(true);
  });

  afterEach(() => jest.clearAllMocks());

  describe('register', () => {
    it('respinge înregistrarea dacă emailul există deja', async () => {
      users.findByEmail.mockResolvedValue(baseUser as never);

      await expect(
        service.register({ email: baseUser.email, password: 'parola123' }, IP),
      ).rejects.toThrow(ConflictException);
      expect(users.create).not.toHaveBeenCalled();
    });

    it('creează contul și trimite email de verificare', async () => {
      users.findByEmail.mockResolvedValue(null);
      users.create.mockResolvedValue({
        ...baseUser,
        isEmailVerified: false,
      } as never);
      users.update.mockResolvedValue(baseUser as never);

      const result = await service.register(
        {
          email: baseUser.email,
          password: 'parola123',
        },
        IP,
      );

      expect(users.create).toHaveBeenCalledWith(
        expect.objectContaining({ email: baseUser.email }),
      );
      expect(mail.sendVerificationEmail).toHaveBeenCalledWith(
        baseUser.email,
        expect.any(String),
      );
      expect(result.message).toContain('Cont creat');
    });
  });

  describe('verifyEmail', () => {
    it('respinge daca userul nu exista', async () => {
      users.findByEmail.mockResolvedValue(null);

      await expect(
        service.verifyEmail('nope@example.com', '123456'),
      ).rejects.toThrow('Cod de verificare invalid');
    });

    it('respinge un cod care nu se potriveste', async () => {
      users.findByEmail.mockResolvedValue({
        ...baseUser,
        isEmailVerified: false,
        emailVerifyToken: '123456',
        emailVerifyExpiry: new Date(Date.now() + 1000 * 60 * 60),
      } as never);

      await expect(
        service.verifyEmail(baseUser.email, '000000'),
      ).rejects.toThrow('Cod de verificare invalid');
    });

    it('respinge un cod expirat', async () => {
      users.findByEmail.mockResolvedValue({
        ...baseUser,
        isEmailVerified: false,
        emailVerifyToken: '123456',
        emailVerifyExpiry: new Date(Date.now() - 1000),
      } as never);

      await expect(
        service.verifyEmail(baseUser.email, '123456'),
      ).rejects.toThrow('Cod de verificare expirat');
    });

    it('confirma email-ul cand codul e corect', async () => {
      users.findByEmail.mockResolvedValue({
        ...baseUser,
        isEmailVerified: false,
        emailVerifyToken: '123456',
        emailVerifyExpiry: new Date(Date.now() + 1000 * 60 * 60),
      } as never);
      users.update.mockResolvedValue(baseUser as never);

      const result = await service.verifyEmail(baseUser.email, '123456');

      expect(users.update).toHaveBeenCalledWith(
        baseUser.id,
        expect.objectContaining({
          isEmailVerified: true,
          emailVerifyToken: null,
          emailVerifyExpiry: null,
        }),
      );
      expect(result.message).toContain('succes');
    });
  });

  describe('resendVerificationCode', () => {
    it('nu dezvaluie daca emailul nu exista', async () => {
      users.findByEmail.mockResolvedValue(null);

      const result = await service.resendVerificationCode(
        'nope@example.com',
        IP,
      );

      expect(users.update).not.toHaveBeenCalled();
      expect(result.message).toBeDefined();
    });

    it('nu retrimite daca emailul e deja confirmat', async () => {
      users.findByEmail.mockResolvedValue({
        ...baseUser,
        isEmailVerified: true,
      } as never);

      await service.resendVerificationCode(baseUser.email, IP);

      expect(users.update).not.toHaveBeenCalled();
      expect(mail.sendVerificationEmail).not.toHaveBeenCalled();
    });

    it('regenereaza si retrimite codul pentru un cont neconfirmat', async () => {
      users.findByEmail.mockResolvedValue({
        ...baseUser,
        isEmailVerified: false,
      } as never);
      users.update.mockResolvedValue(baseUser as never);

      await service.resendVerificationCode(baseUser.email, IP);

      expect(users.update).toHaveBeenCalledWith(
        baseUser.id,
        expect.objectContaining({
          emailVerifyToken: expect.any(String) as unknown,
          emailVerifyExpiry: expect.any(Date) as unknown,
        }),
      );
      expect(mail.sendVerificationEmail).toHaveBeenCalledWith(
        baseUser.email,
        expect.any(String),
      );
    });
  });

  describe('login', () => {
    it('respinge login cu email inexistent', async () => {
      users.findByEmail.mockResolvedValue(null);

      await expect(
        service.login({ email: 'nope@example.com', password: 'parola123' }, IP),
      ).rejects.toThrow(UnauthorizedException);
    });

    it('respinge login cu parolă greșită', async () => {
      users.findByEmail.mockResolvedValue(baseUser as never);
      (bcrypt.compare as jest.Mock).mockResolvedValue(false);

      await expect(
        service.login({ email: baseUser.email, password: 'gresita' }, IP),
      ).rejects.toThrow(UnauthorizedException);
    });

    it('respinge login dacă emailul nu e verificat', async () => {
      users.findByEmail.mockResolvedValue({
        ...baseUser,
        isEmailVerified: false,
      } as never);

      await expect(
        service.login({ email: baseUser.email, password: 'parola123' }, IP),
      ).rejects.toThrow('Trebuie să îți confirmi email-ul');
    });

    it('emite tokens la login valid', async () => {
      users.findByEmail.mockResolvedValue(baseUser as never);
      users.update.mockResolvedValue(baseUser as never);

      const result = await service.login(
        {
          email: baseUser.email,
          password: 'parola123',
        },
        IP,
      );

      expect(result.accessToken).toBe('signed-token');
      expect(result.refreshToken).toBe('signed-token');
      expect(result.user.email).toBe(baseUser.email);
      expect(result.user.isAdmin).toBe(false);
      // O sesiune nouă per login; hash-ul vechi nu se mai scrie (bcrypt taie
      // JWT-ul la 72 de octeți, deci se potrivea cu orice token vechi).
      expect(prisma.refreshSession.create).toHaveBeenCalledWith({
        data: expect.objectContaining({ userId: baseUser.id }) as unknown,
      });
      expect(users.update).not.toHaveBeenCalledWith(
        baseUser.id,
        expect.objectContaining({
          refreshTokenHash: expect.anything() as unknown,
        }),
      );
    });

    it('respinge un cont banat, chiar cu parola corecta', async () => {
      users.findByEmail.mockResolvedValue({
        ...baseUser,
        isBanned: true,
      } as never);

      await expect(
        service.login({ email: baseUser.email, password: 'parola123' }, IP),
      ).rejects.toThrow('suspendat');
      expect(prisma.refreshSession.create).not.toHaveBeenCalled();
    });
  });

  describe('refresh', () => {
    it('respinge daca userul nu are refresh token salvat', async () => {
      users.findById.mockResolvedValue({
        ...baseUser,
        refreshTokenHash: null,
      } as never);

      await expect(service.refresh(baseUser.id, 'some-token')).rejects.toThrow(
        UnauthorizedException,
      );
    });

    it('respinge daca refresh token-ul nu se potriveste', async () => {
      users.findById.mockResolvedValue({
        ...baseUser,
        refreshTokenHash: 'hash',
      } as never);
      (bcrypt.compare as jest.Mock).mockResolvedValue(false);

      await expect(service.refresh(baseUser.id, 'wrong-token')).rejects.toThrow(
        UnauthorizedException,
      );
    });

    it('emite tokens noi daca refresh token-ul e valid', async () => {
      users.findById.mockResolvedValue({
        ...baseUser,
        refreshTokenHash: 'hash',
      } as never);
      users.update.mockResolvedValue(baseUser as never);

      const result = await service.refresh(baseUser.id, 'correct-token');

      expect(result.accessToken).toBe('signed-token');
      // Token-ul vechi (fără sid) e mutat pe loc într-o sesiune.
      expect(prisma.refreshSession.create).toHaveBeenCalled();
    });

    it('prelungeste sesiunea cand token-ul are sid', async () => {
      users.findById.mockResolvedValue(baseUser as never);
      prisma.refreshSession.findUnique.mockResolvedValue({
        id: 'sid-1',
        userId: baseUser.id,
        expiresAt: new Date(Date.now() + 60_000),
      });

      const result = await service.refresh(baseUser.id, 'token', 'sid-1');

      expect(result.refreshToken).toBe('signed-token');
      expect(prisma.refreshSession.updateMany).toHaveBeenCalledWith(
        expect.objectContaining({
          where: { id: 'sid-1', userId: baseUser.id },
        }),
      );
      expect(bcrypt.compare).not.toHaveBeenCalled();
    });

    it('respinge o sesiune stearsa (logout, ban, parola resetata)', async () => {
      users.findById.mockResolvedValue(baseUser as never);
      prisma.refreshSession.findUnique.mockResolvedValue(null);

      await expect(
        service.refresh(baseUser.id, 'token', 'sid-1'),
      ).rejects.toThrow(UnauthorizedException);
    });

    it('respinge sesiunea altui user', async () => {
      users.findById.mockResolvedValue(baseUser as never);
      prisma.refreshSession.findUnique.mockResolvedValue({
        id: 'sid-1',
        userId: 'altcineva',
        expiresAt: new Date(Date.now() + 60_000),
      });

      await expect(
        service.refresh(baseUser.id, 'token', 'sid-1'),
      ).rejects.toThrow(UnauthorizedException);
    });

    it('respinge refresh-ul unui user banat', async () => {
      users.findById.mockResolvedValue({
        ...baseUser,
        isBanned: true,
      } as never);

      await expect(
        service.refresh(baseUser.id, 'token', 'sid-1'),
      ).rejects.toThrow(UnauthorizedException);
    });
  });

  describe('logout', () => {
    it('inchide doar sesiunea dispozitivului curent', async () => {
      await service.logout(baseUser.id, 'jti-1', 123, 'sid-1');

      expect(prisma.refreshSession.deleteMany).toHaveBeenCalledWith({
        where: { id: 'sid-1', userId: baseUser.id },
      });
      expect(users.update).not.toHaveBeenCalled();
    });
  });

  describe('verifyResetCode', () => {
    it('respinge daca userul nu exista', async () => {
      users.findByEmail.mockResolvedValue(null);

      await expect(
        service.verifyResetCode('nope@example.com', '123456'),
      ).rejects.toThrow('Cod de resetare invalid');
    });

    it('respinge un cod care nu se potriveste', async () => {
      users.findByEmail.mockResolvedValue({
        ...baseUser,
        resetPasswordToken: '123456',
        resetPasswordExpiry: new Date(Date.now() + 1000 * 60 * 60),
      } as never);

      await expect(
        service.verifyResetCode(baseUser.email, '000000'),
      ).rejects.toThrow('Cod de resetare invalid');
    });

    it('anuleaza codul dupa prea multe incercari gresite pe acelasi cont', async () => {
      users.findByEmail.mockResolvedValue({
        ...baseUser,
        resetPasswordToken: '123456',
        resetPasswordExpiry: new Date(Date.now() + 1000 * 60 * 60),
      } as never);

      for (let i = 0; i < 4; i++) {
        await expect(
          service.verifyResetCode(baseUser.email, '000000'),
        ).rejects.toThrow('Cod de resetare invalid');
      }
      // A cincea: plafonul, pe oricare din cele două rute care primesc codul.
      await expect(
        service.resetPassword(baseUser.email, '000000', 'parolaNoua1', IP),
      ).rejects.toThrow('Prea multe');
      expect(users.update).toHaveBeenCalledWith(baseUser.id, {
        resetPasswordToken: null,
        resetPasswordExpiry: null,
      });
    });

    it('respinge un cod expirat', async () => {
      users.findByEmail.mockResolvedValue({
        ...baseUser,
        resetPasswordToken: '123456',
        resetPasswordExpiry: new Date(Date.now() - 1000),
      } as never);

      await expect(
        service.verifyResetCode(baseUser.email, '123456'),
      ).rejects.toThrow('Cod de resetare expirat');
    });

    it('confirma codul valid fara sa-l consume', async () => {
      users.findByEmail.mockResolvedValue({
        ...baseUser,
        resetPasswordToken: '123456',
        resetPasswordExpiry: new Date(Date.now() + 1000 * 60 * 60),
      } as never);

      const result = await service.verifyResetCode(baseUser.email, '123456');

      expect(users.update).not.toHaveBeenCalled();
      expect(result.message).toContain('valid');
    });
  });

  describe('resetPassword', () => {
    it('respinge cod invalid', async () => {
      users.findByEmail.mockResolvedValue(null);

      await expect(
        service.resetPassword(baseUser.email, '123456', 'parolaNoua1', IP),
      ).rejects.toThrow('Cod de resetare invalid');
    });

    it('respinge cod expirat', async () => {
      users.findByEmail.mockResolvedValue({
        ...baseUser,
        resetPasswordToken: '123456',
        resetPasswordExpiry: new Date(Date.now() - 1000),
      } as never);

      await expect(
        service.resetPassword(baseUser.email, '123456', 'parolaNoua1', IP),
      ).rejects.toThrow('Cod de resetare expirat');
    });

    it('schimbă parola și invalidează sesiunea la cod valid', async () => {
      users.findByEmail.mockResolvedValue({
        ...baseUser,
        resetPasswordToken: '123456',
        resetPasswordExpiry: new Date(Date.now() + 1000 * 60 * 60),
      } as never);
      users.update.mockResolvedValue(baseUser as never);

      const result = await service.resetPassword(
        baseUser.email,
        '123456',
        'parolaNoua1',
        IP,
      );

      expect(users.update).toHaveBeenCalledWith(
        baseUser.id,
        expect.objectContaining({ resetPasswordToken: null }),
      );
      // Toate sesiunile, token-urile de acces și socket-urile - nu doar hash-ul.
      expect(userSessions.revokeAll).toHaveBeenCalledWith(baseUser.id);
      expect(result.message).toContain('succes');
    });
  });

  describe('createLoginCode / exchangeLoginCode', () => {
    const tokens = { accessToken: 'access-1', refreshToken: 'refresh-1' };

    it('schimbă un cod valid pe token-uri o singură dată', () => {
      const code = service.createLoginCode(tokens);

      expect(service.exchangeLoginCode(code)).toEqual(tokens);
    });

    it('respinge o a doua încercare de schimb cu același cod (single-use)', () => {
      const code = service.createLoginCode(tokens);
      service.exchangeLoginCode(code);

      expect(() => service.exchangeLoginCode(code)).toThrow(
        'invalid sau expirat',
      );
    });

    it('respinge un cod inexistent', () => {
      expect(() => service.exchangeLoginCode('cod-care-nu-exista')).toThrow(
        'invalid sau expirat',
      );
    });

    it('respinge un cod expirat', () => {
      const nowSpy = jest.spyOn(Date, 'now');
      nowSpy.mockReturnValue(1_000_000);
      const code = service.createLoginCode(tokens);

      nowSpy.mockReturnValue(1_000_000 + 61_000); // +61s, peste expirarea de 60s

      expect(() => service.exchangeLoginCode(code)).toThrow(
        'invalid sau expirat',
      );
      nowSpy.mockRestore();
    });
  });
});
