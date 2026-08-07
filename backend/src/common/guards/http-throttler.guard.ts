import { Injectable, ExecutionContext } from '@nestjs/common';
import { ThrottlerGuard } from '@nestjs/throttler';

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
}
