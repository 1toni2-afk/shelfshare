import { ExecutionContext, Injectable } from '@nestjs/common';
import { AuthGuard } from '@nestjs/passport';
import type { Request } from 'express';

@Injectable()
export class GoogleAuthGuard extends AuthGuard('google') {
  /**
   * Aplicația mobilă nu poate primi redirectul http de final al fluxului
   * (ajungea în browser, pe varianta web a aplicației, iar userul rămânea
   * nelogat în app). Trebuie să ne întoarcem la ea printr-un deep link, dar
   * asta se decide abia în callback - iar singurul parametru pe care Google
   * îl întoarce nemodificat este `state`. Îl marcăm aici, la pornirea
   * fluxului (/auth/google?platform=mobile).
   */
  getAuthenticateOptions(context: ExecutionContext) {
    const req = context.switchToHttp().getRequest<Request>();
    return req.query?.platform === 'mobile' ? { state: 'mobile' } : {};
  }
}
