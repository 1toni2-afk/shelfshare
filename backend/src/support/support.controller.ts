import { Body, Controller, Get, Post } from '@nestjs/common';
import { SupportService } from './support.service';
import { CreateSupportRequestDto } from './dto/create-support-request.dto';

/** Public - useri care nu se pot loga n-au niciun token de autentificare. */
@Controller('support')
export class SupportController {
  constructor(private supportService: SupportService) {}

  @Get('captcha')
  getCaptcha() {
    return this.supportService.generateCaptcha();
  }

  @Post()
  submit(@Body() dto: CreateSupportRequestDto) {
    return this.supportService.submit(dto);
  }
}
