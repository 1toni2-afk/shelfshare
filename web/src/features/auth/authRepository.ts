import { api, tokenStorage } from '@/lib/api/client';
import type { AppUser, AuthTokens, CaptchaChallenge } from '@/types/models';

/**
 * Port al AuthRepository din frontend/lib/features/auth/data/auth_repository.dart.
 * Endpointurile și forma payload-urilor sunt identice - backendul nu se atinge.
 */
export const authRepository = {
  async register(input: { email: string; password: string; referralCode?: string }): Promise<void> {
    const referralCode = input.referralCode?.trim();
    await api.post('/auth/register', {
      email: input.email,
      password: input.password,
      ...(referralCode ? { referralCode } : {}),
    });
  },

  getLoginCaptcha(): Promise<CaptchaChallenge> {
    return api.get<CaptchaChallenge>('/auth/captcha');
  },

  async login(input: {
    email: string;
    password: string;
    captchaToken?: string;
    captchaAnswer?: number;
  }): Promise<AppUser> {
    const tokens = await api.post<AuthTokens>('/auth/login', {
      email: input.email,
      password: input.password,
      ...(input.captchaToken ? { captchaToken: input.captchaToken } : {}),
      ...(input.captchaAnswer !== undefined ? { captchaAnswer: input.captchaAnswer } : {}),
    });
    await tokenStorage.saveTokens(tokens);

    // Răspunsul de login întoarce un user "subțire" (id/email/isEmailVerified/
    // isAdmin, fără username). Folosit direct, userii care ȘI-AU ALES deja un
    // username ar fi trimiși din nou la onboarding la fiecare login, fiindcă
    // username ar apărea mereu null. Luăm profilul complet, ca la fluxul Google.
    return api.get<AppUser>('/profile/me');
  },

  /**
   * Schimbă codul primit din fluxul Google OAuth (redirect din backend) pe
   * token-uri reale printr-un apel separat - token-urile nu tranzitează
   * niciodată URL-ul de redirect al browserului, doar acest cod opac.
   */
  async completeExternalLogin(code: string): Promise<AppUser> {
    const tokens = await api.post<AuthTokens>('/auth/google/exchange', { code });
    await tokenStorage.saveTokens(tokens);
    return api.get<AppUser>('/profile/me');
  },

  async logout(): Promise<void> {
    try {
      await api.post('/auth/logout');
    } catch {
      // Continuăm oricum să curățăm local, chiar dacă serverul nu răspunde.
    }
    await tokenStorage.clear();
  },

  forgotPassword(email: string): Promise<void> {
    return api.post('/auth/forgot-password', { email });
  },

  verifyResetCode(email: string, code: string): Promise<void> {
    return api.post('/auth/verify-reset-code', { email, code });
  },

  verifyEmail(email: string, code: string): Promise<void> {
    return api.post('/auth/verify-email', { email, code });
  },

  resendVerificationCode(email: string): Promise<void> {
    return api.post('/auth/resend-verification', { email });
  },

  resetPassword(email: string, code: string, newPassword: string): Promise<void> {
    return api.post('/auth/reset-password', { email, code, newPassword });
  },

  async tryRestoreSession(): Promise<AppUser | null> {
    const token = await tokenStorage.getAccessToken();
    if (!token) return null;
    try {
      return await api.get<AppUser>('/profile/me');
    } catch {
      await tokenStorage.clear();
      return null;
    }
  },
};
