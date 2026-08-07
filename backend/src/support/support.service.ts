import { BadRequestException, Injectable, Logger } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { MailService } from '../mail/mail.service';
import { CaptchaService } from '../common/captcha/captcha.service';
import { CreateSupportRequestDto } from './dto/create-support-request.dto';

@Injectable()
export class SupportService {
  private readonly logger = new Logger(SupportService.name);

  constructor(
    private prisma: PrismaService,
    private mail: MailService,
    private captcha: CaptchaService,
  ) {}

  generateCaptcha() {
    return this.captcha.generate();
  }

  async submit(dto: CreateSupportRequestDto) {
    if (!this.captcha.verify(dto.captchaToken, dto.captchaAnswer)) {
      throw new BadRequestException(
        'Răspunsul la captcha e greșit sau a expirat',
      );
    }

    const created = await this.prisma.supportRequest.create({
      data: {
        name: dto.name,
        email: dto.email,
        phone: dto.phone,
        message: dto.message,
      },
    });

    // Cod scurt din id, ca să poți regăsi ușor cererea (ex. în panoul de admin)
    // pornind doar de la subiectul emailului.
    const code = created.id.slice(0, 8).toUpperCase();
    try {
      await this.mail.sendSupportRequestNotification({
        code,
        name: dto.name,
        email: dto.email,
        phone: dto.phone,
        message: dto.message,
      });
    } catch (error) {
      this.logger.error(
        `Nu am putut trimite notificarea de support (${code})`,
        error,
      );
    }

    return { message: 'Mesajul a fost trimis. Îți răspundem cât mai curând.' };
  }

  getAll() {
    return this.prisma.supportRequest.findMany({
      orderBy: { createdAt: 'desc' },
      take: 200,
    });
  }
}
