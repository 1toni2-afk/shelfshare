import { Injectable, UnauthorizedException } from '@nestjs/common';
import { PassportStrategy } from '@nestjs/passport';
import { ExtractJwt, Strategy, JwtFromRequestFunction } from 'passport-jwt';
import { ConfigService } from '@nestjs/config';
import type { Request } from 'express';
import { RevokedTokenService } from '../../common/security/revoked-token.service';

export interface JwtPayload {
  sub: string; // user id
  email: string;
  jti?: string;
  exp?: number;
}

/**
 * Singurele rute care chiar au nevoie de token în URL: linkurile de descărcare
 * .ics (`/exchanges/:id/calendar.ics`, `/offers/:id/calendar.ics`), deschise
 * direct de browser, deci fără header Authorization.
 */
const CALENDAR_DOWNLOAD_PATH = /\/calendar\.ics$/;

const fromQueryParameter = ExtractJwt.fromUrlQueryParameter('token');

/**
 * Extractorul din query string, dar limitat la rutele de calendar.
 *
 * Înainte era înregistrat global, deci un access token cu drepturi complete
 * era acceptat ca `?token=...` pe ORICE endpoint autentificat. Un token pus în
 * URL ajunge în locuri unde un header nu ajunge niciodată: jurnalele
 * Cloudflare, istoricul browserului și header-ul `Referer` trimis către terți.
 * Cine citește apoi acele jurnale poate da replay și intra pe cont. Restrâns
 * aici, suprafața rămâne exact cele două descărcări care nu pot trimite un
 * header - restul API-ului cere Authorization, ca înainte.
 */
const fromCalendarQueryParameter: JwtFromRequestFunction = (req: Request) => {
  if (!CALENDAR_DOWNLOAD_PATH.test(req.path)) return null;
  return fromQueryParameter(req);
};

@Injectable()
export class JwtStrategy extends PassportStrategy(Strategy, 'jwt') {
  constructor(
    config: ConfigService,
    private revokedTokens: RevokedTokenService,
  ) {
    super({
      jwtFromRequest: ExtractJwt.fromExtractors([
        ExtractJwt.fromAuthHeaderAsBearerToken(),
        // Doar pe /…/calendar.ics - vezi fromCalendarQueryParameter.
        fromCalendarQueryParameter,
      ]),
      ignoreExpiration: false,
      secretOrKey: config.get<string>('JWT_ACCESS_SECRET')!,
    });
  }

  validate(payload: JwtPayload) {
    if (this.revokedTokens.isRevoked(payload.jti)) {
      throw new UnauthorizedException('Sesiune invalidată');
    }
    // Ce se întoarce aici ajunge în request.user în controllere
    return {
      userId: payload.sub,
      email: payload.email,
      jti: payload.jti,
      exp: payload.exp,
    };
  }
}
