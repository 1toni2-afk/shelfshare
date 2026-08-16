import { Test, TestingModule } from '@nestjs/testing';
import { UsersService } from './users.service';
import { PrismaService } from '../prisma/prisma.service';

describe('UsersService - normalizarea emailului', () => {
  let service: UsersService;
  let prisma: { user: Record<string, jest.Mock> };

  beforeEach(async () => {
    prisma = {
      user: {
        findUnique: jest.fn().mockResolvedValue(null),
        create: jest.fn().mockResolvedValue({ id: 'u1' }),
      },
    };

    const module: TestingModule = await Test.createTestingModule({
      providers: [UsersService, { provide: PrismaService, useValue: prisma }],
    }).compile();

    service = module.get(UsersService);
  });

  describe('findByEmail', () => {
    // Tastaturile de Android scriu prima literă cu majusculă, deci fără
    // normalizare login-ul eșua pentru useri care își tastau adresa pe telefon.
    it('caută cu litere mici, chiar dacă adresa vine cu majuscule', async () => {
      await service.findByEmail('Ion.Popescu@Exemplu.RO');

      expect(prisma.user.findUnique).toHaveBeenCalledWith({
        where: { email: 'ion.popescu@exemplu.ro' },
      });
    });

    it('taie spațiile de la capete', async () => {
      await service.findByEmail('  ion@exemplu.ro  ');

      expect(prisma.user.findUnique).toHaveBeenCalledWith({
        where: { email: 'ion@exemplu.ro' },
      });
    });
  });

  describe('create', () => {
    it('stochează adresa cu litere mici', async () => {
      await service.create({ email: 'NOU@Exemplu.RO', password: 'hash' });

      expect(prisma.user.create).toHaveBeenCalledWith({
        data: expect.objectContaining({ email: 'nou@exemplu.ro' }),
      });
    });
  });
});
