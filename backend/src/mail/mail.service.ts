import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { Resend } from 'resend';

const SUPPORT_NOTIFICATION_EMAIL_DEFAULT = 'www.toniyi1@gmail.com';

/** Conținut liber introdus de un user neautentificat - trebuie scăpat înainte de a ajunge în HTML. */
function escapeHtml(value: string): string {
  return value
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#39;');
}

@Injectable()
export class MailService {
  private readonly logger = new Logger(MailService.name);
  private readonly resend: Resend;
  private readonly fromEmail: string;

  constructor(private config: ConfigService) {
    this.resend = new Resend(this.config.get<string>('RESEND_API_KEY'));
    this.fromEmail = this.config.get<string>(
      'MAIL_FROM',
      'onboarding@resend.dev',
    );
  }

  async sendVerificationEmail(to: string, code: string) {
    const formattedCode = `${code.slice(0, 3)}-${code.slice(3)}`;

    const { error } = await this.resend.emails.send({
      from: this.fromEmail,
      to,
      subject: 'Codul tău de confirmare - ShelfShare',
      html: `
        <p>Bun venit pe ShelfShare!</p>
        <p>Introdu acest cod în aplicație ca să îți confirmi adresa de email:</p>
        <p style="font-size: 32px; font-weight: bold; letter-spacing: 4px;">${formattedCode}</p>
        <p>Codul expiră în 24 de ore.</p>
      `,
    });

    if (error) {
      this.logger.error(`Eroare trimitere email verificare către ${to}`, error);
      throw new Error('Nu am putut trimite email-ul de verificare');
    }
  }

  async sendPasswordResetEmail(to: string, code: string) {
    const formattedCode = `${code.slice(0, 3)}-${code.slice(3)}`;

    const { error } = await this.resend.emails.send({
      from: this.fromEmail,
      to,
      subject: 'Codul tău de resetare - ShelfShare',
      html: `
        <p>Am primit o cerere de resetare a parolei pentru contul tău.</p>
        <p>Introdu acest cod în aplicație ca să îți setezi o parolă nouă:</p>
        <p style="font-size: 32px; font-weight: bold; letter-spacing: 4px;">${formattedCode}</p>
        <p>Codul expiră în 1 oră. Dacă nu ai cerut tu resetarea, ignoră acest email.</p>
      `,
    });

    if (error) {
      this.logger.error(`Eroare trimitere email reset către ${to}`, error);
      throw new Error('Nu am putut trimite email-ul de resetare');
    }
  }

  async sendSupportRequestNotification(data: {
    code: string;
    name: string;
    email: string;
    phone?: string | null;
    message: string;
  }) {
    const to = this.config.get<string>(
      'SUPPORT_NOTIFICATION_EMAIL',
      SUPPORT_NOTIFICATION_EMAIL_DEFAULT,
    );

    const { error } = await this.resend.emails.send({
      from: this.fromEmail,
      to,
      subject: `AJUTOR SUPPORT SHELFSHARE - ${data.code}`,
      html: `
        <p><strong>Nume:</strong> ${escapeHtml(data.name)}</p>
        <p><strong>Email:</strong> ${escapeHtml(data.email)}</p>
        <p><strong>Telefon:</strong> ${data.phone ? escapeHtml(data.phone) : '-'}</p>
        <p><strong>Mesaj:</strong></p>
        <p>${escapeHtml(data.message).replace(/\n/g, '<br>')}</p>
      `,
    });

    if (error) {
      this.logger.error(`Eroare trimitere notificare support (${data.code})`, error);
      throw new Error('Nu am putut trimite notificarea de support');
    }
  }
}
