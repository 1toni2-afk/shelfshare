import { useState, type FormEvent } from 'react';
import { Link, Navigate, useLocation } from 'react-router-dom';
import { useTranslation } from 'react-i18next';
import { Button, Field } from '@/components/ui';
import { AuthLayout } from './AuthLayout';
import { useAuth } from './AuthProvider';
import { EuropeanFlag, RomanianFlag } from '@/components/ui/Flag';
import { API_BASE_URL } from '@/lib/api/client';

/**
 * Port al login_screen.dart. Aceleași chei de traducere, aceeași ordine a
 * câmpurilor, același flux de captcha.
 */
export function LoginScreen() {
  const { t } = useTranslation();
  const { status, login, busy, clearError } = useAuth();
  const location = useLocation();

  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [captchaAnswer, setCaptchaAnswer] = useState('');
  const [fieldErrors, setFieldErrors] = useState<{ email?: string; password?: string }>({});

  // Userul a ajuns aici de pe o rută protejată; după login îl trimitem înapoi
  // acolo, nu pe Home. Un link din email sau dintr-un push ar fi altfel pierdut.
  const from = (location.state as { from?: string } | null)?.from;

  if (status.kind === 'authenticated') {
    return <Navigate to={from ?? '/'} replace />;
  }

  const captcha = status.kind === 'captchaRequired' ? status.captcha : null;
  const errorMessage =
    status.kind === 'error' ? status.message : status.kind === 'captchaRequired' ? status.message : null;

  /*
    Cont necomfirmat: nu are rost să rămână pe ecranul de autentificare, unde
    n-are ce face. Îl trimitem direct la câmpul de cod, cu adresa deja
    completată - exact pasul care i-a rămas de făcut.
  */
  if (status.kind === 'emailNotVerified') {
    return <Navigate to={`/verify-email?email=${encodeURIComponent(status.email)}`} replace />;
  }

  function validate(): boolean {
    const errors: { email?: string; password?: string } = {};
    // Aceeași validare minimală ca în Flutter: prezența unui „@" plus un punct
    // după el. Nu o regulă completă de RFC - backendul e oricum autoritatea,
    // iar o regulă agresivă respinge adrese valide.
    if (!/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(email.trim())) {
      errors.email = t('commonEmailInvalid');
    }
    if (!password) {
      errors.password = t('authEnterPasswordError');
    }
    setFieldErrors(errors);
    return Object.keys(errors).length === 0;
  }

  async function onSubmit(event: FormEvent) {
    event.preventDefault();
    if (!validate()) return;

    await login({
      email: email.trim(),
      password,
      ...(captcha && captchaAnswer
        ? { captchaToken: captcha.token, captchaAnswer: Number(captchaAnswer) }
        : {}),
    });
  }

  return (
    <AuthLayout title={t('loginWelcomeBack')}>
      <form onSubmit={onSubmit} className="flex flex-col gap-4" noValidate>
          <Field
            label={t('commonEmailLabel')}
            name="email"
            type="email"
            autoComplete="email"
            inputMode="email"
            value={email}
            error={fieldErrors.email}
            onChange={(e) => {
              setEmail(e.target.value);
              clearError();
            }}
          />

          <Field
            label={t('authPasswordLabel')}
            name="password"
            type="password"
            autoComplete="current-password"
            value={password}
            error={fieldErrors.password}
            onChange={(e) => {
              setPassword(e.target.value);
              clearError();
            }}
          />

          {/* Captcha apare doar după prea multe încercări eșuate - backendul o
              cere prin `requiresCaptcha` în corpul lui 401. */}
          {captcha && (
            <Field
              label={`${captcha.question} — ${t('supportCaptchaAnswerLabel')}`}
              name="captcha"
              type="number"
              inputMode="numeric"
              value={captchaAnswer}
              onChange={(e) => setCaptchaAnswer(e.target.value)}
            />
          )}

          {errorMessage && (
            <p role="alert" className="text-sm text-danger-text">
              {errorMessage}
            </p>
          )}

          <Button type="submit" loading={busy} fullWidth>
            {t('authLoginSubmit')}
          </Button>
        </form>

        <div className="mt-4 flex justify-center">
          <Link to="/forgot-password" className="text-sm text-accent hover:underline">
            {t('authForgotPasswordLink')}
          </Link>
        </div>

        <div className="my-6 flex items-center gap-3 text-xs text-muted-foreground">
          <span className="h-px flex-1 bg-border" />
          {t('commonOr')}
          <span className="h-px flex-1 bg-border" />
        </div>

        {/*
          Un <a> real, nu fetch: fluxul Google e o navigare de browser
          (redirect spre Google și înapoi pe /auth/google/callback). Un XHR ar
          fi blocat de politica de frame a Google și nu ar putea seta cookie-ul
          de sesiune al fluxului OAuth.
        */}
        <a
          href={`${API_BASE_URL}/auth/google`}
          className="flex w-full items-center justify-center gap-2 rounded-[12px] border border-border px-6 py-4 text-[15px] font-bold transition hover:bg-muted"
        >
          <GoogleMark />
          Google
        </a>

        <p className="mt-6 text-center text-sm text-muted-foreground">
          {t('authNoAccount')}
          <Link to="/register" className="font-semibold text-accent hover:underline">
            {t('authCreateOne')}
          </Link>
        </p>

      {/*
        Steagurile sunt SVG, nu emoji: `🇷🇴` și `🇪🇺` sunt perechi de „regional
        indicator", iar Windows nu are glifele de steag - Chrome afișa literele
        `RO` și `EU` în mijlocul frazei. Textul e rupt în două chei tocmai ca
        fiecare steag să stea lângă locul lui, în orice limbă.
      */}
      <p className="mt-8 flex flex-wrap items-center justify-center gap-x-1.5 text-center text-xs text-muted-foreground">
        <span>{t('loginMadeWithLove')}</span>
        <RomanianFlag title={t('commonCountryRomania')} />
        <span aria-hidden="true">·</span>
        <span>{t('loginMadeInEurope')}</span>
        <EuropeanFlag title={t('commonCountryEurope')} />
      </p>
    </AuthLayout>
  );
}

function GoogleMark() {
  return (
    <svg width="18" height="18" viewBox="0 0 48 48" aria-hidden="true">
      <path fill="#4285F4" d="M45.1 24.5c0-1.6-.1-2.8-.4-4H24v7.3h12.1c-.2 2-1.6 5-4.5 7l6.9 5.3c4.1-3.8 6.6-9.4 6.6-15.6z" />
      <path fill="#34A853" d="M24 46c5.9 0 10.9-2 14.5-5.3l-6.9-5.3c-1.9 1.3-4.4 2.2-7.6 2.2-5.8 0-10.7-3.8-12.5-9.1l-7.1 5.5C8 41.1 15.4 46 24 46z" />
      <path fill="#FBBC05" d="M11.5 28.5c-.5-1.4-.7-2.9-.7-4.5s.3-3.1.7-4.5l-7.1-5.5C2.9 17 2 20.4 2 24s.9 7 2.4 10z" />
      <path fill="#EA4335" d="M24 10.7c3.2 0 5.4 1.4 6.7 2.6l6.1-6C33 3.9 29.9 2 24 2 15.4 2 8 6.9 4.4 14l7.1 5.5c1.8-5.3 6.7-8.8 12.5-8.8z" />
    </svg>
  );
}
