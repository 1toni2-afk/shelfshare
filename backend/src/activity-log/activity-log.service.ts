import { Injectable, Logger } from '@nestjs/common';
import { appendFile, mkdir } from 'fs/promises';
import { existsSync } from 'fs';
import { join } from 'path';
import { PrismaService } from '../prisma/prisma.service';

/**
 * Jurnalul global al aplicației, pe fișiere text (nu în baza de date): un
 * fișier pe zi, în foldere an/lună, ca să poți deschide direct ziua care te
 * interesează fără să cauți prin milioane de rânduri.
 *
 *   logs/activity/2026/08/2026-08-28.log   - interacțiuni user-user și user-admin
 *   logs/chat/2026/08/2026-08-28.log       - mesajele (separate: sunt de zeci de
 *                                            ori mai multe și ar îneca restul)
 *
 * Formatul unei linii:
 *   [14:03:22] Ana Pop (ab12cd34) → Ion Vasile (ef56ab78) EXCHANGE_ACCEPTED {"book":"Ion"}
 *
 * Scrierile sunt fire-and-forget și serializate într-o coadă: o eroare de I/O
 * nu are voie să pice cererea userului, iar două cereri simultane nu au voie
 * să-și amestece liniile.
 */
export type ActivityStream = 'activity' | 'chat';

export interface ActivityEntry {
  /** Verb scurt, majuscule: EXCHANGE_ACCEPTED, OFFER_REJECTED, USER_BANNED... */
  action: string;
  /** Cine a făcut acțiunea. */
  actorId?: string | null;
  /** Celălalt user implicat (destinatarul acțiunii), dacă există. */
  targetId?: string | null;
  /** Context suplimentar, serializat compact ca JSON la finalul liniei. */
  details?: Record<string, unknown>;
}

const LABEL_CACHE_TTL_MS = 10 * 60 * 1000;
const LABEL_CACHE_MAX = 500;

@Injectable()
export class ActivityLogService {
  private readonly logger = new Logger(ActivityLogService.name);
  // `||`, nu `??`: în .env variabila poate exista dar goală, iar un root gol
  // ar scrie în rădăcina discului.
  private readonly root =
    process.env.ACTIVITY_LOG_DIR || join(process.cwd(), 'logs');
  /// Fusul în care se decide „ce zi e" - altfel, pe un server pe UTC,
  /// interacțiunile de seara ar ajunge în fișierul zilei următoare.
  private readonly timeZone = process.env.ACTIVITY_LOG_TZ || 'Europe/Bucharest';
  private readonly enabled = process.env.ACTIVITY_LOG_DISABLED !== 'true';
  /// Conținutul mesajelor NU se scrie implicit - jurnalul e pentru „cine, cu
  /// cine, când", nu o arhivă de conversații. Se poate porni explicit pentru
  /// moderare.
  private readonly logChatContent =
    process.env.ACTIVITY_LOG_CHAT_CONTENT === 'true';

  /** Coadă de scriere: garantează linii întregi, în ordine, fără intercalări. */
  private queue: Promise<void> = Promise.resolve();
  private readonly labels = new Map<string, { label: string; at: number }>();

  constructor(private prisma: PrismaService) {}

  /** Interacțiune „normală" (schimburi, oferte, follow, rapoarte, admin). */
  record(entry: ActivityEntry) {
    this.enqueue('activity', entry);
  }

  /**
   * Mesaje - fișier separat, ca volumul lor să nu îngroape restul. Conținutul
   * e înlocuit implicit cu lungimea lui (vezi ACTIVITY_LOG_CHAT_CONTENT).
   */
  recordChat(entry: ActivityEntry & { content?: string | null }) {
    const { content, ...rest } = entry;
    this.enqueue('chat', {
      ...rest,
      details: {
        ...rest.details,
        ...(content == null
          ? {}
          : this.logChatContent
            ? { text: content }
            : { length: content.length }),
      },
    });
  }

  private enqueue(stream: ActivityStream, entry: ActivityEntry) {
    if (!this.enabled) return;
    this.queue = this.queue
      .then(() => this.write(stream, entry))
      .catch((error) =>
        this.logger.warn(`Nu am putut scrie în jurnal: ${String(error)}`),
      );
  }

  private async write(stream: ActivityStream, entry: ActivityEntry) {
    const now = new Date();
    const { year, month, day, time } = this.parts(now);
    const dir = join(this.root, stream, year, month);
    const file = join(dir, `${year}-${month}-${day}.log`);

    const isNewFile = !existsSync(file);
    if (isNewFile) {
      await mkdir(dir, { recursive: true });
    }

    const [actor, target] = await Promise.all([
      this.label(entry.actorId),
      this.label(entry.targetId),
    ]);
    const details =
      entry.details && Object.keys(entry.details).length > 0
        ? ` ${JSON.stringify(entry.details)}`
        : '';
    const line = `[${time}] ${actor}${target ? ` → ${target}` : ''} ${entry.action}${details}\n`;

    // Antet cu data la începutul fiecărui fișier - fișierul poartă data în
    // nume, dar antetul o face evidentă și când citești mai multe zile
    // concatenate (`cat 2026/08/*.log`).
    await appendFile(
      file,
      isNewFile ? `# ${year}-${month}-${day} (${stream})\n${line}` : line,
      'utf8',
    );
  }

  /** Data/ora descompuse în fusul configurat (Intl, nu getUTC*). */
  private parts(date: Date) {
    const formatted = new Intl.DateTimeFormat('sv-SE', {
      timeZone: this.timeZone,
      year: 'numeric',
      month: '2-digit',
      day: '2-digit',
      hour: '2-digit',
      minute: '2-digit',
      second: '2-digit',
      hour12: false,
    }).format(date);
    // „sv-SE" dă exact `2026-08-28 14:03:22`.
    const [ymd, time] = formatted.split(' ');
    const [year, month, day] = ymd.split('-');
    return { year, month, day, time };
  }

  /**
   * `Nume (ab12cd34)` - id-ul scurtat ține linia lizibilă, dar rămâne
   * suficient ca să regăsești userul. Numele se cache-uiește: un jurnal nu
   * merită un SELECT per linie.
   */
  private async label(userId?: string | null): Promise<string> {
    if (!userId) return '';
    const short = userId.slice(0, 8);
    const cached = this.labels.get(userId);
    if (cached && Date.now() - cached.at < LABEL_CACHE_TTL_MS) {
      return `${cached.label} (${short})`;
    }
    let label = 'necunoscut';
    try {
      const user = await this.prisma.user.findUnique({
        where: { id: userId },
        select: { name: true, username: true, email: true },
      });
      label = user?.name || user?.username || user?.email || 'necunoscut';
    } catch {
      // Un jurnal nu are voie să arunce; rămâne eticheta implicită.
    }
    if (this.labels.size >= LABEL_CACHE_MAX) this.labels.clear();
    this.labels.set(userId, { label, at: Date.now() });
    return `${label} (${short})`;
  }

  /** Golește coada - folosit de teste ca să aștepte scrierile în curs. */
  async flush() {
    await this.queue;
  }
}
