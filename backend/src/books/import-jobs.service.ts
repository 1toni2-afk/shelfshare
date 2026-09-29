import {
  HttpException,
  Injectable,
  Logger,
  NotFoundException,
} from '@nestjs/common';
import { randomUUID } from 'crypto';

/** Cât stă un import terminat în memorie, ca pagina să-și poată citi rezultatul. */
const FINISHED_JOB_TTL_MS = 30 * 60 * 1000;

export type ImportJobStatus = 'running' | 'done' | 'failed';

interface ImportJob {
  id: string;
  userId: string;
  status: ImportJobStatus;
  processed: number;
  total: number;
  result: unknown;
  error: string | null;
  finishedAt: number | null;
}

/**
 * Importurile de CSV rulate în fundal, cu progres citibil.
 *
 * Importul sincron ținea cererea HTTP deschisă cât dura tot fișierul. Un
 * export Goodreads de câteva sute de rânduri durează zeci de secunde, iar
 * clientul (60s) și Cloudflare (100s) tăiau cererea înainte de răspuns: omul
 * vedea „fișierul nu e un CSV valid" deși importul mergea mai departe pe
 * server. Acum POST-ul întoarce imediat un id, iar pagina întreabă periodic
 * cât s-a făcut - de aici și bara „120 / 296".
 *
 * În memorie, nu în baza de date: backendul rulează într-un singur proces, iar
 * un import pierdut la un restart se reia pur și simplu - rândurile deja
 * importate sunt idempotente (upsert pe raft, sku la anunțuri).
 */
@Injectable()
export class ImportJobsService {
  private readonly logger = new Logger(ImportJobsService.name);
  private readonly jobs = new Map<string, ImportJob>();

  start(
    userId: string,
    run: (onProgress: (processed: number, total: number) => void) => Promise<unknown>,
  ): { jobId: string } {
    this.sweep();
    const job: ImportJob = {
      id: randomUUID(),
      userId,
      status: 'running',
      processed: 0,
      total: 0,
      result: null,
      error: null,
      finishedAt: null,
    };
    this.jobs.set(job.id, job);

    void run((processed, total) => {
      job.processed = processed;
      job.total = total;
    })
      .then((result) => {
        job.result = result;
        job.status = 'done';
      })
      .catch((error: unknown) => {
        // Mesajele de validare (CSV gol, prea multe rânduri) sunt pentru user;
        // orice altceva rămâne în log.
        const message = error instanceof HttpException ? error.message : null;
        if (!message) this.logger.error(`Import eșuat: ${String(error)}`);
        job.error = message;
        job.status = 'failed';
      })
      .finally(() => {
        job.finishedAt = Date.now();
      });

    return { jobId: job.id };
  }

  /** Doar proprietarul își vede importul - un id ghicit al altcuiva dă 404. */
  get(userId: string, jobId: string) {
    const job = this.jobs.get(jobId);
    if (!job || job.userId !== userId) {
      throw new NotFoundException('Importul nu a fost găsit');
    }
    return {
      id: job.id,
      status: job.status,
      processed: job.processed,
      total: job.total,
      result: job.status === 'done' ? job.result : null,
      error: job.error,
    };
  }

  private sweep() {
    const now = Date.now();
    for (const [id, job] of this.jobs) {
      if (job.finishedAt != null && now - job.finishedAt > FINISHED_JOB_TTL_MS) {
        this.jobs.delete(id);
      }
    }
  }
}
