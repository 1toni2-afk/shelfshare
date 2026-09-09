import {
  Body,
  Controller,
  Delete,
  Get,
  Param,
  Post,
  Put,
  UseGuards,
  UseInterceptors,
} from '@nestjs/common';
import { StoresService } from './stores.service';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { SuperAdminGuard } from '../admin/guards/super-admin.guard';
import { AdminAuditInterceptor } from '../admin/admin-audit.interceptor';
import { CreateStoreDto, UpdateStoreDto } from './dto/upsert-store.dto';

/**
 * Administrarea conturilor de magazin - doar super-admini.
 *
 * Nu e o permisiune granulară din panoul de roluri: a face un cont „magazin"
 * îi dă dreptul să listeze la vânzare fără pozele cerute tuturor (vezi
 * importStock), deci e o decizie comercială, nu una de moderare.
 */
@UseGuards(JwtAuthGuard, SuperAdminGuard)
@UseInterceptors(AdminAuditInterceptor)
@Controller('admin/stores')
export class StoresController {
  constructor(private stores: StoresService) {}

  @Get()
  list() {
    return this.stores.list();
  }

  @Post()
  create(@Body() dto: CreateStoreDto) {
    return this.stores.create(dto);
  }

  @Put(':userId')
  update(@Param('userId') userId: string, @Body() dto: UpdateStoreDto) {
    return this.stores.update(userId, dto);
  }

  @Delete(':userId')
  remove(@Param('userId') userId: string) {
    return this.stores.remove(userId);
  }
}
