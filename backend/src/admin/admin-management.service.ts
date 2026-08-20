import {
  BadRequestException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { AdminRoleName } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { ADMIN_PERMISSION_KEYS } from './constants/admin-permissions';
import { UpsertCustomRoleDto } from './dto/upsert-custom-role.dto';

@Injectable()
export class AdminManagementService {
  constructor(private prisma: PrismaService) {}

  async listAdministrators() {
    const users = await this.prisma.user.findMany({
      where: { adminRoleId: { not: null } },
      select: {
        id: true,
        email: true,
        name: true,
        username: true,
        adminRole: true,
      },
      orderBy: { email: 'asc' },
    });
    return users;
  }

  async listRoles() {
    const roles = await this.prisma.adminRole.findMany({ orderBy: { createdAt: 'asc' } });
    return { roles, permissionKeys: ADMIN_PERMISSION_KEYS };
  }

  async grantRole(actingAdminId: string, targetUserId: string, roleId: string) {
    this.assertNotSelf(actingAdminId, targetUserId);

    const [actingAdmin, targetUser, role] = await Promise.all([
      this.getAdminWithRole(actingAdminId),
      this.prisma.user.findUnique({ where: { id: targetUserId }, include: { adminRole: true } }),
      this.prisma.adminRole.findUnique({ where: { id: roleId } }),
    ]);

    if (!targetUser) throw new NotFoundException('Utilizator inexistent');
    if (!role) throw new NotFoundException('Rol inexistent');

    this.assertNoPrivilegeEscalation(actingAdmin.adminRole?.permissions ?? [], role.permissions);

    // O schimbare de rol care scoate ultimul Super Admin din rol e echivalentă
    // cu ștergerea lui - aceeași regulă de securitate se aplică.
    if (
      targetUser.adminRole?.name === AdminRoleName.SUPER_ADMIN &&
      role.name !== AdminRoleName.SUPER_ADMIN
    ) {
      await this.assertNotLastSuperAdmin();
    }

    return this.prisma.user.update({
      where: { id: targetUserId },
      data: { adminRoleId: role.id, isAdmin: true },
      select: { id: true, email: true, adminRole: true },
    });
  }

  async updateRole(actingAdminId: string, targetUserId: string, roleId: string) {
    // Aceeași operație ca grantRole (schimbă rolul unui admin existent) -
    // regulile de securitate sunt identice, deci reutilizăm direct.
    return this.grantRole(actingAdminId, targetUserId, roleId);
  }

  async revokeAdmin(actingAdminId: string, targetUserId: string) {
    this.assertNotSelf(actingAdminId, targetUserId);

    const targetUser = await this.prisma.user.findUnique({
      where: { id: targetUserId },
      include: { adminRole: true },
    });
    if (!targetUser) throw new NotFoundException('Utilizator inexistent');

    if (targetUser.adminRole?.name === AdminRoleName.SUPER_ADMIN) {
      await this.assertNotLastSuperAdmin();
    }

    return this.prisma.user.update({
      where: { id: targetUserId },
      data: { adminRoleId: null, isAdmin: false },
      select: { id: true, email: true },
    });
  }

  async createCustomRole(dto: UpsertCustomRoleDto) {
    return this.prisma.adminRole.create({
      data: {
        name: AdminRoleName.CUSTOM,
        label: dto.label,
        permissions: dto.permissions,
      },
    });
  }

  async updateCustomRole(roleId: string, dto: UpsertCustomRoleDto) {
    const role = await this.prisma.adminRole.findUnique({ where: { id: roleId } });
    if (!role) throw new NotFoundException('Rol inexistent');
    if (role.name !== AdminRoleName.CUSTOM) {
      throw new BadRequestException('Rolurile predefinite nu pot fi editate');
    }

    return this.prisma.adminRole.update({
      where: { id: roleId },
      data: { label: dto.label, permissions: dto.permissions },
    });
  }

  private async getAdminWithRole(userId: string) {
    const user = await this.prisma.user.findUnique({
      where: { id: userId },
      include: { adminRole: true },
    });
    if (!user) throw new NotFoundException('Utilizator inexistent');
    return user;
  }

  private assertNotSelf(actingAdminId: string, targetUserId: string) {
    if (actingAdminId === targetUserId) {
      throw new ForbiddenException(
        'Un administrator nu își poate modifica propriile permisiuni',
      );
    }
  }

  private assertNoPrivilegeEscalation(actingPermissions: string[], targetPermissions: string[]) {
    const missing = targetPermissions.filter((p) => !actingPermissions.includes(p));
    if (missing.length > 0) {
      throw new ForbiddenException(
        `Nu poți acorda permisiuni pe care nu le deții: ${missing.join(', ')}`,
      );
    }
  }

  private async assertNotLastSuperAdmin() {
    const superAdminCount = await this.prisma.user.count({
      where: { adminRole: { name: AdminRoleName.SUPER_ADMIN } },
    });
    if (superAdminCount <= 1) {
      throw new ForbiddenException('Ultimul Super Admin nu poate fi eliminat');
    }
  }
}
