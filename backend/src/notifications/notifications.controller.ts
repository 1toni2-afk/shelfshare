import { Body, Controller, Delete, Get, Param, Post, Req, UseGuards } from '@nestjs/common';
import type { Request } from 'express';
import { NotificationsService } from './notifications.service';
import { PushService } from './push.service';
import { RegisterDeviceTokenDto } from './dto/register-device-token.dto';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import type { AuthenticatedUser } from '../auth/types/authenticated-user';

@UseGuards(JwtAuthGuard)
@Controller('notifications')
export class NotificationsController {
  constructor(
    private notificationsService: NotificationsService,
    private pushService: PushService,
  ) {}

  /**
   * Frontend-ul cheamă asta la login și de fiecare dată când FCM emite un
   * token nou (rotație normală) - vezi push_notifications_service.dart.
   */
  @Post('device-token')
  registerDeviceToken(@Req() req: Request, @Body() dto: RegisterDeviceTokenDto) {
    const { userId } = req.user as AuthenticatedUser;
    return this.pushService.registerToken(userId!, dto.token, dto.platform);
  }

  @Delete('device-token/:token')
  unregisterDeviceToken(@Param('token') token: string) {
    return this.pushService.unregisterToken(token);
  }

  @Get()
  getMine(@Req() req: Request) {
    const { userId } = req.user as AuthenticatedUser;
    return this.notificationsService.getMine(userId!);
  }

  @Post(':id/read')
  markAsRead(@Req() req: Request, @Param('id') id: string) {
    const { userId } = req.user as AuthenticatedUser;
    return this.notificationsService.markAsRead(id, userId!);
  }

  @Post('read-all')
  markAllAsRead(@Req() req: Request) {
    const { userId } = req.user as AuthenticatedUser;
    return this.notificationsService.markAllAsRead(userId!);
  }
}
