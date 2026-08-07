import { Injectable } from '@nestjs/common';

const WINDOW_MS = 15 * 60 * 1000;
const CAPTCHA_THRESHOLD = 3;

/**
 * Tracks repeated attempts per (ip, scope) in-memory and flags when a
 * caller should be step-up challenged with a captcha - i.e. "CAPTCHA after
 * several attempts" without requiring one on every normal, human request.
 * Single-process in-memory store is fine here: one backend instance, and
 * worst case on restart is a few callers get a fresh window.
 */
@Injectable()
export class AttemptGuardService {
  private attempts = new Map<string, { count: number; resetAt: number }>();

  /** Records an attempt and returns whether a captcha should now be required. */
  shouldChallenge(scope: string, ip: string): boolean {
    const key = `${scope}:${ip}`;
    const now = Date.now();
    const entry = this.attempts.get(key);

    if (!entry || entry.resetAt < now) {
      this.attempts.set(key, { count: 1, resetAt: now + WINDOW_MS });
      return false;
    }

    entry.count += 1;
    return entry.count > CAPTCHA_THRESHOLD;
  }
}
