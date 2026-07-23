import { BadRequestException, Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import * as crypto from 'crypto';
import { PrismaService } from '../prisma/prisma.service';
import { MailService } from '../mail/mail.service';
import { CreateSupportRequestDto } from './dto/create-support-request.dto';

const CAPTCHA_TTL_MS = 10 * 60 * 1000;

interface CaptchaPayload {
  a: number;
  b: number;
  exp: number;
}

@Injectable()
export class SupportService {
  private readonly logger = new Logger(SupportService.name);

  constructor(
    private prisma: PrismaService,
    private config: ConfigService,
    private mail: MailService,
  ) {}

  /**
   * Captcha simplu (o adunare), fără serviciu extern - tokenul e opac,
   * semnat HMAC și poartă întrebarea+expirarea, deci nu are nevoie de
   * stocare pe server (verificarea e stateless, la submit).
   */
  generateCaptcha() {
    const a = 1 + Math.floor(Math.random() * 9);
    const b = 1 + Math.floor(Math.random() * 9);
    const exp = Date.now() + CAPTCHA_TTL_MS;
    return { question: `Cât fac ${a} + ${b}?`, token: this.signCaptcha({ a, b, exp }) };
  }

  async submit(dto: CreateSupportRequestDto) {
    if (!this.verifyCaptcha(dto.captchaToken, dto.captchaAnswer)) {
      throw new BadRequestException('Răspunsul la captcha e greșit sau a expirat');
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
      this.logger.error(`Nu am putut trimite notificarea de support (${code})`, error);
    }

    return { message: 'Mesajul a fost trimis. Îți răspundem cât mai curând.' };
  }

  getAll() {
    return this.prisma.supportRequest.findMany({
      orderBy: { createdAt: 'desc' },
      take: 200,
    });
  }

  private captchaSecret(): string {
    return this.config.get<string>('CAPTCHA_SECRET', 'shelfshare-captcha-dev-secret');
  }

  private signCaptcha(payload: CaptchaPayload): string {
    const data = Buffer.from(JSON.stringify(payload)).toString('base64url');
    const sig = crypto
      .createHmac('sha256', this.captchaSecret())
      .update(data)
      .digest('base64url');
    return `${data}.${sig}`;
  }

  private verifyCaptcha(token: string, answer: number): boolean {
    const [data, sig] = token?.split('.') ?? [];
    if (!data || !sig) return false;

    const expectedSig = crypto
      .createHmac('sha256', this.captchaSecret())
      .update(data)
      .digest('base64url');
    const sigBuf = Buffer.from(sig);
    const expectedBuf = Buffer.from(expectedSig);
    if (sigBuf.length !== expectedBuf.length || !crypto.timingSafeEqual(sigBuf, expectedBuf)) {
      return false;
    }

    let payload: CaptchaPayload;
    try {
      payload = JSON.parse(Buffer.from(data, 'base64url').toString()) as CaptchaPayload;
    } catch {
      return false;
    }

    if (Date.now() > payload.exp) return false;
    return payload.a + payload.b === answer;
  }
}
