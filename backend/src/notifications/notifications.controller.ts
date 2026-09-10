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
} from '@nestjs/common';
import type { Request } from 'express';
import { NotificationsService } from './notifications.service';
import { PushService } from './push.service';
import { RegisterDeviceTokenDto } from './dto/register-device-token.dto';
import { SetNotificationPreferencesDto } from './dto/set-notification-preferences.dto';
import type { NotificationType } from '@prisma/client';
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
  registerDeviceToken(
    @Req() req: Request,
    @Body() dto: RegisterDeviceTokenDto,
  ) {
    const { userId } = req.user as AuthenticatedUser;
    return this.pushService.registerToken(userId!, dto.token, dto.platform);
  }

  @Delete('device-token/:token')
  unregisterDeviceToken(@Param('token') token: string) {
    return this.pushService.unregisterToken(token);
  }

  /** Harta completă tip -> pornit/oprit, inclusiv tipurile fără rând în DB. */
  @Get('preferences')
  getPreferences(@Req() req: Request) {
    const { userId } = req.user as AuthenticatedUser;
    return this.notificationsService.getPreferences(userId!);
  }

  @Put('preferences')
  setPreferences(
    @Req() req: Request,
    @Body() dto: SetNotificationPreferencesDto,
  ) {
    const { userId } = req.user as AuthenticatedUser;
    // Construit explicit, nu prin Object.fromEntries: pe un map care intoarce
    // array-uri (nu tuple), fromEntries cade pe supraincarcarea care da `any`,
    // deci cast-ul de dupa nu verifica nimic - eslint il si semnala ca inutil.
    // Asa tipul e real si greselile de forma se vad la compilare.
    const preferences: Partial<Record<NotificationType, boolean>> = {};
    for (const p of dto.preferences) {
      preferences[p.type] = p.enabled;
    }
    return this.notificationsService.setPreferences(userId!, preferences);
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
