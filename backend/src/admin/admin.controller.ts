import {
  Controller,
  Delete,
  Get,
  Param,
  Post,
  Query,
  UseGuards,
} from '@nestjs/common';
import { AdminService } from './admin.service';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { AdminGuard } from './guards/admin.guard';

@UseGuards(JwtAuthGuard, AdminGuard)
@Controller('admin')
export class AdminController {
  constructor(private adminService: AdminService) {}

  @Get('stats')
  getStats() {
    return this.adminService.getStats();
  }

  @Get('users')
  getUsers(@Query('limit') limit?: string, @Query('offset') offset?: string) {
    return this.adminService.getUsers(
      limit ? parseInt(limit, 10) : undefined,
      offset ? parseInt(offset, 10) : undefined,
    );
  }

  @Post('users/:id/ban')
  banUser(@Param('id') id: string) {
    return this.adminService.banUser(id);
  }

  @Post('users/:id/unban')
  unbanUser(@Param('id') id: string) {
    return this.adminService.unbanUser(id);
  }

  @Delete('users/:id')
  deleteUser(@Param('id') id: string) {
    return this.adminService.deleteUser(id);
  }

  @Delete('books/:id')
  deleteBook(@Param('id') id: string) {
    return this.adminService.deleteBook(id);
  }

  @Delete('user-books/:id')
  deleteUserBook(@Param('id') id: string) {
    return this.adminService.deleteUserBook(id);
  }

  @Get('reports/inactive-listings')
  getInactiveListingsReport() {
    return this.adminService.getInactiveListingsReport();
  }

  @Get('reports/users')
  getUserReports() {
    return this.adminService.getUserReports();
  }

  @Get('feedback')
  getFeedback() {
    return this.adminService.getFeedback();
  }
}
