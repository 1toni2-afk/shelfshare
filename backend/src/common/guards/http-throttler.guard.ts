import { Injectable, ExecutionContext } from '@nestjs/common';
import { ThrottlerGuard } from '@nestjs/throttler';
import type { Request } from 'express';
import { clientIp } from '../utils/client-ip';

/**
 * ThrottlerGuard assumes an HTTP request/response (req.ip, res.header(...)).
 * Applied globally, it would also intercept WebSocket gateway handlers
 * (chat.gateway.ts), whose execution context has no res.header - throwing
 * on every socket message. Skip anything that isn't a plain HTTP context.
 */
@Injectable()
export class HttpThrottlerGuard extends ThrottlerGuard {
  protected shouldSkip(context: ExecutionContext): Promise<boolean> {
    return Promise.resolve(context.getType() !== 'http');
  }

  /**
   * Cheia pe care se numără cererile. Implicit e `req.ip`, care în spatele
   * tunelului Cloudflare e identic pentru toți userii - adică o singură
   * găleată globală în loc de una per client (vezi client-ip.ts). `clientIp`
   * întoarce adresa reală, deci limitele stricte de pe /auth/* chiar
   * încetinesc un atacator, nu tot traficul deodată.
   */
  protected getTracker(req: Request): Promise<string> {
    return Promise.resolve(clientIp(req));
  }
}
