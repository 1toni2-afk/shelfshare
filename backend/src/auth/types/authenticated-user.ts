// Tipul obiectului populat de Passport pe `req.user`, după ce o strategie
// (jwt, jwt-refresh, google) validează cererea.
// userId + refreshToken vin din strategiile jwt/jwt-refresh.
// googleId vine din strategia google (fluxul de OAuth, înainte să existe un user în DB).

export interface AuthenticatedUser {
  userId?: string;
  googleId?: string;
  email: string;
  refreshToken?: string;
}
