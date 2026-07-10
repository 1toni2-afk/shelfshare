// Extindem tipul Request din Express ca să recunoască `req.user`,
// populat de Passport după ce o strategie (jwt, jwt-refresh, google) validează cererea.
// userId + refreshToken vin din strategiile jwt/jwt-refresh.
// googleId vine din strategia google (fluxul de OAuth, înainte să existe un user în DB).

export interface AuthenticatedUser {
  userId?: string;
  googleId?: string;
  email: string;
  refreshToken?: string;
}

declare global {
  namespace Express {
    interface Request {
      user?: AuthenticatedUser;
    }
  }
}

export {};
