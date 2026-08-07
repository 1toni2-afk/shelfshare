import { Injectable } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import * as crypto from 'crypto';

const CAPTCHA_TTL_MS = 10 * 60 * 1000;

interface CaptchaPayload {
  a: number;
  b: number;
  exp: number;
}

/**
 * Simple HMAC-signed math captcha, no external service or server-side
 * storage - the token carries the question + expiry, signed so it can't be
 * tampered with, and is verified statelessly at submit time. Shared between
 * support requests and the auth step-up flow (see attempt-guard.service.ts).
 */
@Injectable()
export class CaptchaService {
  constructor(private config: ConfigService) {}

  generate() {
    const a = 1 + Math.floor(Math.random() * 9);
    const b = 1 + Math.floor(Math.random() * 9);
    const exp = Date.now() + CAPTCHA_TTL_MS;
    return {
      question: `Cât fac ${a} + ${b}?`,
      token: this.sign({ a, b, exp }),
    };
  }

  verify(token: string | undefined, answer: number | undefined): boolean {
    if (!token || answer == null) return false;
    const [data, sig] = token.split('.');
    if (!data || !sig) return false;

    const expectedSig = crypto
      .createHmac('sha256', this.secret())
      .update(data)
      .digest('base64url');
    const sigBuf = Buffer.from(sig);
    const expectedBuf = Buffer.from(expectedSig);
    if (
      sigBuf.length !== expectedBuf.length ||
      !crypto.timingSafeEqual(sigBuf, expectedBuf)
    ) {
      return false;
    }

    let payload: CaptchaPayload;
    try {
      payload = JSON.parse(
        Buffer.from(data, 'base64url').toString(),
      ) as CaptchaPayload;
    } catch {
      return false;
    }

    if (Date.now() > payload.exp) return false;
    return payload.a + payload.b === answer;
  }

  private secret(): string {
    return this.config.get<string>(
      'CAPTCHA_SECRET',
      'shelfshare-captcha-dev-secret',
    );
  }

  private sign(payload: CaptchaPayload): string {
    const data = Buffer.from(JSON.stringify(payload)).toString('base64url');
    const sig = crypto
      .createHmac('sha256', this.secret())
      .update(data)
      .digest('base64url');
    return `${data}.${sig}`;
  }
}
