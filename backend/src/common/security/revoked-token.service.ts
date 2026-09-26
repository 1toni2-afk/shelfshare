import { Injectable } from '@nestjs/common';

/**
 * In-memory access-token revocation list, keyed by JWT `jti`. Access tokens
 * are short-lived (15 min default) and stateless by design - this is the
 * one exception, needed so logout actually invalidates the token instead of
 * leaving it usable until natural expiry. Single backend instance, so
 * in-memory is safe; a restart just means anything revoked-but-not-yet-
 * expired becomes valid again for its remaining (short) lifetime.
 */
@Injectable()
export class RevokedTokenService {
  private revoked = new Map<string, number>(); // jti -> exp (seconds since epoch)

  // userId -> seconds since epoch. Every access token issued to that user
  // BEFORE this moment is invalid (ban, password reset) - otherwise a banned
  // user, or whoever stole a session, kept working for the rest of the
  // token's 15 minutes, and kept an open chat socket indefinitely.
  private userCutoffs = new Map<string, number>();

  revoke(jti: string, exp: number) {
    this.revoked.set(jti, exp);
  }

  revokeAllForUser(userId: string) {
    this.userCutoffs.set(userId, Math.floor(Date.now() / 1000));
  }

  /**
   * `iat < cutoff`, strictly: a token issued in the same second as the cutoff
   * is the fresh login that FOLLOWS a password reset, and must keep working.
   */
  isRevokedForUser(
    userId: string | undefined,
    iat: number | undefined,
  ): boolean {
    if (!userId || iat == null) return false;
    const cutoff = this.userCutoffs.get(userId);
    return cutoff != null && iat < cutoff;
  }

  isRevoked(jti: string | undefined): boolean {
    if (!jti) return false;
    const exp = this.revoked.get(jti);
    if (exp == null) return false;

    if (exp * 1000 < Date.now()) {
      this.revoked.delete(jti);
      return false;
    }
    return true;
  }
}
