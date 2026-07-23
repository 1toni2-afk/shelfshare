import { Test, TestingModule } from '@nestjs/testing';
import { JwtService } from '@nestjs/jwt';
import { ConfigService } from '@nestjs/config';
import { ConflictException, UnauthorizedException } from '@nestjs/common';
import * as bcrypt from 'bcrypt';
import { AuthService } from './auth.service';
import { UsersService } from '../users/users.service';
import { MailService } from '../mail/mail.service';

jest.mock('bcrypt');

describe('AuthService', () => {
  let service: AuthService;
  let users: jest.Mocked<UsersService>;
  let mail: jest.Mocked<MailService>;

  const baseUser = {
    id: 'user-1',
    email: 'test@example.com',
    password: 'hashed-password',
    isEmailVerified: true,
    isAdmin: false,
    refreshTokenHash: null,
    resetPasswordExpiry: null,
    emailVerifyExpiry: null,
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
          useValue: { sign: jest.fn().mockReturnValue('signed-token') },
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
        service.register({ email: baseUser.email, password: 'parola123' }),
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

      const result = await service.register({
        email: baseUser.email,
        password: 'parola123',
      });

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

      const result = await service.resendVerificationCode('nope@example.com');

      expect(users.update).not.toHaveBeenCalled();
      expect(result.message).toBeDefined();
    });

    it('nu retrimite daca emailul e deja confirmat', async () => {
      users.findByEmail.mockResolvedValue({
        ...baseUser,
        isEmailVerified: true,
      } as never);

      await service.resendVerificationCode(baseUser.email);

      expect(users.update).not.toHaveBeenCalled();
      expect(mail.sendVerificationEmail).not.toHaveBeenCalled();
    });

    it('regenereaza si retrimite codul pentru un cont neconfirmat', async () => {
      users.findByEmail.mockResolvedValue({
        ...baseUser,
        isEmailVerified: false,
      } as never);
      users.update.mockResolvedValue(baseUser as never);

      await service.resendVerificationCode(baseUser.email);

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
        service.login({ email: 'nope@example.com', password: 'parola123' }),
      ).rejects.toThrow(UnauthorizedException);
    });

    it('respinge login cu parolă greșită', async () => {
      users.findByEmail.mockResolvedValue(baseUser as never);
      (bcrypt.compare as jest.Mock).mockResolvedValue(false);

      await expect(
        service.login({ email: baseUser.email, password: 'gresita' }),
      ).rejects.toThrow(UnauthorizedException);
    });

    it('respinge login dacă emailul nu e verificat', async () => {
      users.findByEmail.mockResolvedValue({
        ...baseUser,
        isEmailVerified: false,
      } as never);

      await expect(
        service.login({ email: baseUser.email, password: 'parola123' }),
      ).rejects.toThrow('Trebuie să îți confirmi email-ul');
    });

    it('emite tokens la login valid', async () => {
      users.findByEmail.mockResolvedValue(baseUser as never);
      users.update.mockResolvedValue(baseUser as never);

      const result = await service.login({
        email: baseUser.email,
        password: 'parola123',
      });

      expect(result.accessToken).toBe('signed-token');
      expect(result.refreshToken).toBe('signed-token');
      expect(result.user.email).toBe(baseUser.email);
      expect(result.user.isAdmin).toBe(false);
      expect(users.update).toHaveBeenCalledWith(
        baseUser.id,
        expect.objectContaining({
          refreshTokenHash: expect.any(String) as unknown,
        }),
      );
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
        service.resetPassword(baseUser.email, '123456', 'parolaNoua1'),
      ).rejects.toThrow('Cod de resetare invalid');
    });

    it('respinge cod expirat', async () => {
      users.findByEmail.mockResolvedValue({
        ...baseUser,
        resetPasswordToken: '123456',
        resetPasswordExpiry: new Date(Date.now() - 1000),
      } as never);

      await expect(
        service.resetPassword(baseUser.email, '123456', 'parolaNoua1'),
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
      );

      expect(users.update).toHaveBeenCalledWith(
        baseUser.id,
        expect.objectContaining({
          refreshTokenHash: null,
          resetPasswordToken: null,
        }),
      );
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
