import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { Resend } from 'resend';

@Injectable()
export class MailService {
  private readonly logger = new Logger(MailService.name);
  private readonly resend: Resend;
  private readonly fromEmail: string;
  private readonly frontendUrl: string;

  constructor(private config: ConfigService) {
    this.resend = new Resend(this.config.get<string>('RESEND_API_KEY'));
    this.fromEmail = this.config.get<string>(
      'MAIL_FROM',
      'onboarding@resend.dev',
    );
    this.frontendUrl = this.config.get<string>(
      'FRONTEND_URL',
      'http://localhost:8080',
    );
  }

  async sendVerificationEmail(to: string, token: string) {
    const link = `${this.frontendUrl}/verify-email?token=${token}`;

    const { error } = await this.resend.emails.send({
      from: this.fromEmail,
      to,
      subject: 'Confirmă-ți adresa de email - ShelfShare',
      html: `
        <p>Bun venit pe ShelfShare!</p>
        <p>Apasă pe linkul de mai jos ca să îți confirmi adresa de email:</p>
        <p><a href="${link}">${link}</a></p>
        <p>Linkul expiră în 24 de ore.</p>
      `,
    });

    if (error) {
      this.logger.error(`Eroare trimitere email verificare către ${to}`, error);
      throw new Error('Nu am putut trimite email-ul de verificare');
    }
  }

  async sendPasswordResetEmail(to: string, token: string) {
    const link = `${this.frontendUrl}/reset-password?token=${token}`;

    const { error } = await this.resend.emails.send({
      from: this.fromEmail,
      to,
      subject: 'Resetare parolă - ShelfShare',
      html: `
        <p>Am primit o cerere de resetare a parolei pentru contul tău.</p>
        <p>Apasă pe linkul de mai jos ca să îți setezi o parolă nouă:</p>
        <p><a href="${link}">${link}</a></p>
        <p>Linkul expiră în 1 oră. Dacă nu ai cerut tu resetarea, ignoră acest email.</p>
      `,
    });

    if (error) {
      this.logger.error(`Eroare trimitere email reset către ${to}`, error);
      throw new Error('Nu am putut trimite email-ul de resetare');
    }
  }
}
