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

  revoke(jti: string, exp: number) {
    this.revoked.set(jti, exp);
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
