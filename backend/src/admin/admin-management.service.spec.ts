import { Test, TestingModule } from '@nestjs/testing';
import { ForbiddenException } from '@nestjs/common';
import { AdminRoleName } from '@prisma/client';
import { AdminManagementService } from './admin-management.service';
import { PrismaService } from '../prisma/prisma.service';

describe('AdminManagementService', () => {
  let service: AdminManagementService;
  let prisma: {
    user: Record<string, jest.Mock>;
    adminRole: Record<string, jest.Mock>;
  };

  beforeEach(async () => {
    prisma = {
      user: {
        findUnique: jest.fn(),
        update: jest.fn(),
        count: jest.fn(),
      },
      adminRole: {
        findUnique: jest.fn(),
      },
    };

    const module: TestingModule = await Test.createTestingModule({
      providers: [AdminManagementService, { provide: PrismaService, useValue: prisma }],
    }).compile();

    service = module.get(AdminManagementService);
  });

  const superAdmin = (id: string) => ({
    id,
    adminRoleId: 'role-super',
    adminRole: { id: 'role-super', name: AdminRoleName.SUPER_ADMIN, permissions: ['admins.edit'] },
  });

  describe('grantRole', () => {
    it('respinge cererea daca adminul incearca sa isi modifice propriul rol', async () => {
      await expect(service.grantRole('admin-1', 'admin-1', 'role-mod')).rejects.toThrow(
        ForbiddenException,
      );
    });

    it('respinge acordarea unei permisiuni pe care adminul care cere nu o detine', async () => {
      prisma.user.findUnique
        .mockResolvedValueOnce({
          id: 'admin-1',
          adminRole: { permissions: ['users.view'] },
        })
        .mockResolvedValueOnce({ id: 'user-2', adminRoleId: null, adminRole: null });
      prisma.adminRole.findUnique.mockResolvedValueOnce({
        id: 'role-mod',
        name: AdminRoleName.MODERATOR,
        permissions: ['users.view', 'users.ban'],
      });

      await expect(service.grantRole('admin-1', 'user-2', 'role-mod')).rejects.toThrow(
        ForbiddenException,
      );
    });

    it('permite acordarea unui rol ale carui permisiuni sunt un subset din cele ale adminului', async () => {
      prisma.user.findUnique
        .mockResolvedValueOnce({
          id: 'admin-1',
          adminRole: { permissions: ['users.view', 'users.ban'] },
        })
        .mockResolvedValueOnce({ id: 'user-2', adminRoleId: null, adminRole: null });
      prisma.adminRole.findUnique.mockResolvedValueOnce({
        id: 'role-mod',
        name: AdminRoleName.MODERATOR,
        permissions: ['users.view', 'users.ban'],
      });
      prisma.user.update.mockResolvedValue({ id: 'user-2', email: 'u2@test.dev' });

      await service.grantRole('admin-1', 'user-2', 'role-mod');

      expect(prisma.user.update).toHaveBeenCalledWith(
        expect.objectContaining({
          where: { id: 'user-2' },
          data: { adminRoleId: 'role-mod', isAdmin: true },
        }),
      );
    });

    it('blocheaza demiterea ultimului Super Admin printr-o schimbare de rol', async () => {
      prisma.user.findUnique
        .mockResolvedValueOnce({
          id: 'admin-1',
          adminRole: { permissions: ['admins.edit', 'users.view'] },
        })
        .mockResolvedValueOnce(superAdmin('target-1'));
      prisma.adminRole.findUnique.mockResolvedValueOnce({
        id: 'role-support',
        name: AdminRoleName.USER_SUPPORT,
        permissions: ['users.view'],
      });
      prisma.user.count.mockResolvedValueOnce(1);

      await expect(service.grantRole('admin-1', 'target-1', 'role-support')).rejects.toThrow(
        ForbiddenException,
      );
    });
  });

  describe('revokeAdmin', () => {
    it('respinge cererea daca adminul incearca sa isi elimine propriul acces', async () => {
      await expect(service.revokeAdmin('admin-1', 'admin-1')).rejects.toThrow(ForbiddenException);
    });

    it('blocheaza eliminarea ultimului Super Admin', async () => {
      prisma.user.findUnique.mockResolvedValueOnce(superAdmin('target-1'));
      prisma.user.count.mockResolvedValueOnce(1);

      await expect(service.revokeAdmin('admin-1', 'target-1')).rejects.toThrow(ForbiddenException);
    });

    it('permite eliminarea unui Super Admin daca mai exista altul', async () => {
      prisma.user.findUnique.mockResolvedValueOnce(superAdmin('target-1'));
      prisma.user.count.mockResolvedValueOnce(2);
      prisma.user.update.mockResolvedValue({ id: 'target-1', email: 't1@test.dev' });

      await service.revokeAdmin('admin-1', 'target-1');

      expect(prisma.user.update).toHaveBeenCalledWith(
        expect.objectContaining({
          where: { id: 'target-1' },
          data: { adminRoleId: null, isAdmin: false },
        }),
      );
    });
  });
});
