import { Injectable } from '@nestjs/common';

/**
 * In-memory sliding-window rate limiter for call sites the HTTP throttler
 * can't reach - namely WebSocket gateway handlers (see HttpThrottlerGuard,
 * which deliberately skips non-HTTP contexts). One Map entry per key that's
 * ever been used; fine at this app's scale (bounded by distinct users, not
 * requests), not worth a cleanup cron.
 */
@Injectable()
export class SlidingWindowLimiterService {
  private hits = new Map<string, number[]>();

  /** Returns true if the call is allowed, false if it should be rejected. */
  consume(key: string, limit: number, windowMs: number): boolean {
    const now = Date.now();
    const recent = (this.hits.get(key) ?? []).filter((t) => now - t < windowMs);

    if (recent.length >= limit) {
      this.hits.set(key, recent);
      return false;
    }

    recent.push(now);
    this.hits.set(key, recent);
    return true;
  }
}
