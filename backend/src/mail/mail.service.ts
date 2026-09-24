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

  /**
   * Emailul de bun venit, trimis la 3 zile după înregistrare (vezi
   * WelcomeEmailService). NU e un email tranzacțional: userul nu așteaptă
   * nimic de la el, deci trebuie să merite deschis - de-aia conține ce poate
   * face concret în aplicație, nu un „mulțumim" singur.
   *
   * `name` vine din profil și poate lipsi (cont creat fără nume) - în cazul
   * ăsta salutăm neutru, nu cu un „Salut, null". Chiar dacă e numele propriu
   * al userului, trece prin escapeHtml: ajunge într-un document HTML.
   */
  async sendWelcomeTipsEmail(data: {
    to: string;
    name?: string | null;
    appUrl: string;
  }) {
    const greeting = data.name?.trim()
      ? `Salut, ${escapeHtml(data.name.trim())}!`
      : 'Salut!';
    // `appUrl` vine din configurație (FRONTEND_URL), nu dintr-un input de
    // user, dar tot îl escapăm: ajunge într-un atribut href.
    const app = escapeHtml(data.appUrl.replace(/\/+$/, ''));

    const { error } = await this.resend.emails.send({
      from: this.fromEmail,
      to: data.to,
      subject: 'Trei zile pe ShelfShare - ce poți face mai departe',
      html: `
        <div style="font-family: -apple-system, Segoe UI, Roboto, sans-serif; font-size: 15px; line-height: 1.6; color: #1c1917;">
          <p>${greeting}</p>
          <p>Îți mulțumim că ți-ai făcut cont pe ShelfShare. Au trecut trei zile,
             așa că îți lăsăm pe scurt ce poți face aici:</p>
          <ul>
            <li><b>Adaugă-ți cărțile</b> - scanezi ISBN-ul sau cauți titlul, iar
                cartea intră pe raftul tău. <a href="${app}/import">Import din Goodreads sau StoryGraph</a>
                dacă îți ții deja lista acolo.</li>
            <li><b>Caută cărți în apropierea ta</b> - pe
                <a href="${app}/browse">Descoperă</a> sau pe
                <a href="${app}/map">hartă</a>, filtrate pe oraș și distanță.</li>
            <li><b>Schimbă, cumpără sau dăruiește</b> - trimiți o cerere de schimb,
                vă înțelegeți în <a href="${app}/chat">chat</a>, apoi confirmați
                amândoi. Cartea trece efectiv pe raftul noului proprietar.</li>
            <li><b>Book Match</b> - <a href="${app}/book-match">dai swipe</a> pe
                coperte și îți construiești gusturile; recomandările se aliniază
                după ele.</li>
            <li><b>Wishlist</b> - <a href="${app}/wishlist">pui titlurile căutate</a>
                și primești o notificare când apar la cineva.</li>
          </ul>
          <p><b>Un minut pentru noi?</b> Spune-ne ce ți-a plăcut, ce te-a încurcat
             sau ce lipsește - citim tot, iar formularul e scurt:</p>
          <p>
            <a href="${app}/feedback"
               style="display: inline-block; padding: 10px 18px; border-radius: 8px; background: #b45309; color: #ffffff; text-decoration: none; font-weight: 600;">
              Trimite-ne părerea ta
            </a>
          </p>
          <p style="color: #78716c; font-size: 13px;">
            Emailul ăsta se trimite o singură dată, la trei zile după înregistrare.
            Notificările pe email le poți regla oricând din Setări.
          </p>
        </div>
      `,
    });

    if (error) {
      this.logger.error(`Eroare trimitere email bun venit către ${data.to}`, error);
      throw new Error('Nu am putut trimite email-ul de bun venit');
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

  /**
   * Feedback trimis din aplicație (formularul din Setări). Rămâne salvat în
   * DB și vizibil în panoul de admin - emailul e doar ca să nu depindă de
   * cineva care intră în panou ca să vadă că a apărut ceva nou.
   *
   * Poza (dacă a fost trimisă) merge ca link, nu ca atașament: e deja urcată
   * în storage și publică, iar un atașament ar dubla degeaba 8MB pe email.
   */
  async sendFeedbackNotification(data: {
    feedbackId: string;
    name?: string | null;
    email?: string | null;
    message: string;
    photoUrl?: string | null;
  }) {
    const to = this.config.get<string>(
      'SUPPORT_NOTIFICATION_EMAIL',
      SUPPORT_NOTIFICATION_EMAIL_DEFAULT,
    );

    const { error } = await this.resend.emails.send({
      from: this.fromEmail,
      to,
      subject: 'FEEDBACK SHELFSHARE',
      html: `
        <p><strong>De la:</strong> ${escapeHtml(data.name || 'utilizator fără nume')}</p>
        <p><strong>Email:</strong> ${data.email ? escapeHtml(data.email) : '-'}</p>
        <p><strong>Mesaj:</strong></p>
        <p>${escapeHtml(data.message).replace(/\n/g, '<br>')}</p>
        ${
          data.photoUrl
            ? `<p><strong>Poză:</strong> <a href="${escapeHtml(data.photoUrl)}">${escapeHtml(data.photoUrl)}</a></p>`
            : ''
        }
        <p style="color:#888;font-size:12px;">Feedback #${escapeHtml(data.feedbackId)}</p>
      `,
    });

    if (error) {
      this.logger.error(
        `Eroare trimitere notificare feedback (${data.feedbackId})`,
        error,
      );
      throw new Error('Nu am putut trimite notificarea de feedback');
    }
  }

  /**
   * Notificare de moderare pentru o conversație raportată din chat.
   * Transcriptul complet e deja salvat în storage (vezi
   * ConversationsService#reportConversation) - aici trimitem doar linkul plus
   * ultimele mesaje, ca să se poată tria raportul fără a deschide fișierul.
   */
  async sendChatReportNotification(data: {
    reportId: string;
    reporter: string;
    reported: string;
    reason: string;
    details?: string | null;
    messageCount: number;
    transcriptUrl: string;
    excerpt: string;
  }) {
    const to = this.config.get<string>(
      'SUPPORT_NOTIFICATION_EMAIL',
      SUPPORT_NOTIFICATION_EMAIL_DEFAULT,
    );

    const { error } = await this.resend.emails.send({
      from: this.fromEmail,
      to,
      subject: `CHAT RAPORTAT SHELFSHARE - ${data.reason}`,
      html: `
        <p><strong>Raport:</strong> ${escapeHtml(data.reportId)}</p>
        <p><strong>Reclamant:</strong> ${escapeHtml(data.reporter)}</p>
        <p><strong>Reclamat:</strong> ${escapeHtml(data.reported)}</p>
        <p><strong>Motiv:</strong> ${escapeHtml(data.reason)}</p>
        <p><strong>Detalii:</strong> ${data.details ? escapeHtml(data.details) : '-'}</p>
        <p><strong>Mesaje în transcript:</strong> ${data.messageCount}</p>
        <p><strong>Transcript complet:</strong> <a href="${escapeHtml(data.transcriptUrl)}">${escapeHtml(data.transcriptUrl)}</a></p>
        <p><strong>Ultimele mesaje:</strong></p>
        <pre style="background:#f4f4f4;padding:12px;white-space:pre-wrap;">${escapeHtml(data.excerpt)}</pre>
      `,
    });

    if (error) {
      this.logger.error(
        `Eroare trimitere notificare chat raportat (${data.reportId})`,
        error,
      );
      throw new Error('Nu am putut trimite notificarea de raportare');
    }
  }
}
