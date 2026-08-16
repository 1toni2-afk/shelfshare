import { Injectable } from '@nestjs/common';

const WINDOW_MS = 15 * 60 * 1000;
const CAPTCHA_THRESHOLD = 3;

/**
 * Tracks repeated attempts per (ip, scope, identifier) in-memory and flags
 * when a caller should be step-up challenged with a captcha - i.e. "CAPTCHA
 * after several attempts" without requiring one on every normal, human
 * request. Single-process in-memory store is fine here: one backend
 * instance, and worst case on restart is a few callers get a fresh window.
 */
@Injectable()
export class AttemptGuardService {
  private attempts = new Map<string, { count: number; resetAt: number }>();

  /**
   * Records an attempt and returns whether a captcha should now be required.
   *
   * `identifier` (typically the email being logged into/registered/reset) is
   * folded into the key when present. Without it, several phones behind the
   * same NAT/IP - a common case for this app, tested by multiple people on
   * one home network - shared a single counter and all got challenged after
   * only 3-4 *combined* login attempts across completely different accounts.
   * Keying by ip+email keeps the intended protection (repeated attempts
   * against the same account from the same IP) without punishing unrelated
   * users who simply share a network.
   */
  shouldChallenge(scope: string, ip: string, identifier?: string): boolean {
    const key = identifier ? `${scope}:${ip}:${identifier.toLowerCase()}` : `${scope}:${ip}`;
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
