import {
  Body,
  Controller,
  Delete,
  Get,
  Param,
  Post,
  Put,
  Req,
  UseGuards,
  UseInterceptors,
} from '@nestjs/common';
import type { Request } from 'express';
import { AdminManagementService } from './admin-management.service';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { AdminGuard } from './guards/admin.guard';
import { PermissionGuard } from './guards/permission.guard';
import { AdminAuditInterceptor } from './admin-audit.interceptor';
import { RequirePermission } from './decorators/require-permission.decorator';
import { GrantAdminRoleDto, UpdateAdminRoleDto } from './dto/grant-admin-role.dto';
import { UpsertCustomRoleDto } from './dto/upsert-custom-role.dto';
import type { AuthenticatedUser } from '../auth/types/authenticated-user';

@UseGuards(JwtAuthGuard, AdminGuard, PermissionGuard)
@UseInterceptors(AdminAuditInterceptor)
@Controller('admin')
export class AdminManagementController {
  constructor(private adminManagement: AdminManagementService) {}

  @Get('administrators')
  @RequirePermission('admins.view')
  listAdministrators() {
    return this.adminManagement.listAdministrators();
  }

  @Post('administrators')
  @RequirePermission('admins.create')
  grantRole(@Req() req: Request, @Body() dto: GrantAdminRoleDto) {
    const { userId } = req.user as AuthenticatedUser;
    return this.adminManagement.grantRole(userId!, dto.userId, dto.roleId);
  }

  @Put('administrators/:userId/role')
  @RequirePermission('admins.edit')
  updateRole(
    @Req() req: Request,
    @Param('userId') targetUserId: string,
    @Body() dto: UpdateAdminRoleDto,
  ) {
    const { userId } = req.user as AuthenticatedUser;
    return this.adminManagement.updateRole(userId!, targetUserId, dto.roleId);
  }

  @Delete('administrators/:userId')
  @RequirePermission('admins.delete')
  revokeAdmin(@Req() req: Request, @Param('userId') targetUserId: string) {
    const { userId } = req.user as AuthenticatedUser;
    return this.adminManagement.revokeAdmin(userId!, targetUserId);
  }

  @Get('roles')
  @RequirePermission('admins.view')
  listRoles() {
    return this.adminManagement.listRoles();
  }

  @Post('roles')
  @RequirePermission('admins.edit')
  createCustomRole(@Body() dto: UpsertCustomRoleDto) {
    return this.adminManagement.createCustomRole(dto);
  }

  @Put('roles/:id')
  @RequirePermission('admins.edit')
  updateCustomRole(@Param('id') id: string, @Body() dto: UpsertCustomRoleDto) {
    return this.adminManagement.updateCustomRole(id, dto);
  }
}
