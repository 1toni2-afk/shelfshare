import { Injectable, UnauthorizedException } from '@nestjs/common';
import { PassportStrategy } from '@nestjs/passport';
import { ExtractJwt, Strategy } from 'passport-jwt';
import { ConfigService } from '@nestjs/config';
import { RevokedTokenService } from '../../common/security/revoked-token.service';

export interface JwtPayload {
  sub: string; // user id
  email: string;
  jti?: string;
  exp?: number;
}

@Injectable()
export class JwtStrategy extends PassportStrategy(Strategy, 'jwt') {
  constructor(
    config: ConfigService,
    private revokedTokens: RevokedTokenService,
  ) {
    super({
      // fromUrlQueryParameter e necesar pentru link-ul de descărcare .ics
      // al calendarului (deschis direct de browser, fără header Authorization).
      jwtFromRequest: ExtractJwt.fromExtractors([
        ExtractJwt.fromAuthHeaderAsBearerToken(),
        ExtractJwt.fromUrlQueryParameter('token'),
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
