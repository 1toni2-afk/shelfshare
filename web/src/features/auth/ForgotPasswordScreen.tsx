import { useState, type FormEvent } from 'react';
import { Link } from 'react-router-dom';
import { useTranslation } from 'react-i18next';
import { CheckCircle2 } from 'lucide-react';
import { Button, Field } from '@/components/ui';
import { useToast } from '@/components/ui/Toast';
import { AuthLayout } from './AuthLayout';
import { authRepository } from './authRepository';

const CODE_LENGTH = 6;
const MIN_PASSWORD_LENGTH = 8;

/**
 * Resetarea parolei, în patru pași pe ACELAȘI ecran: adresă, cod, parolă nouă,
 * confirmare.
 *
 * Pașii nu sunt rute separate dinadins. Starea (adresa + codul verificat) n-ar
 * supraviețui unei navigări reale, iar un refresh la jumătatea fluxului ar lăsa
 * userul pe o pagină care cere un cod fără să știe pentru ce adresă. În Flutter
 * era exact aceeași alegere.
 */
type Step = 'email' | 'code' | 'password' | 'done';

export function ForgotPasswordScreen() {
  const { t } = useTranslation();
  const toast = useToast();

  const [step, setStep] = useState<Step>('email');
  const [email, setEmail] = useState('');
  const [code, setCode] = useState('');
  const [password, setPassword] = useState('');
  const [confirmPassword, setConfirmPassword] = useState('');
  const [error, setError] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);

  async function requestCode(event: FormEvent) {
    event.preventDefault();
    if (!/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(email.trim())) {
      setError(t('commonEmailInvalid'));
      return;
    }

    setBusy(true);
    setError(null);
    try {
      await authRepository.forgotPassword(email.trim());
    } catch {
      // Trecem la pasul următor chiar dacă cererea a eșuat. Backendul răspunde
      // la fel pentru o adresă inexistentă, tocmai ca să nu se poată afla ce
      // adrese sunt înregistrate; a ne opri aici cu o eroare ar dezvălui exact
      // informația pe care el o ascunde.
    } finally {
      setBusy(false);
      setStep('code');
    }
  }

  async function verifyCode(event: FormEvent) {
    event.preventDefault();
    if (code.trim().length !== CODE_LENGTH) {
      setError(t('verifyCodeTooShort'));
      return;
    }

    setBusy(true);
    setError(null);
    try {
      await authRepository.verifyResetCode(email.trim(), code.trim());
      setStep('password');
    } catch {
      setError(t('verifyInvalidOrExpired'));
    } finally {
      setBusy(false);
    }
  }

  async function submitPassword(event: FormEvent) {
    event.preventDefault();
    if (password.length < MIN_PASSWORD_LENGTH) {
      setError(t('authMinEightChars'));
      return;
    }
    if (password !== confirmPassword) {
      setError(t('authPasswordMismatch'));
      return;
    }

    setBusy(true);
    setError(null);
    try {
      await authRepository.resetPassword(email.trim(), code.trim(), password);
      setStep('done');
    } catch {
      setError(t('resetPasswordGenericError'));
    } finally {
      setBusy(false);
    }
  }

  async function resendCode() {
    try {
      await authRepository.forgotPassword(email.trim());
    } catch {
      /* la fel ca mai sus - mesajul e neutru indiferent de rezultat */
    }
    toast.show(t('verifyResendSnackbar'));
  }

  if (step === 'done') {
    return (
      <AuthLayout title={t('resetPasswordSuccessHeading')}>
        <div className="flex flex-col items-center gap-4 text-center">
          <CheckCircle2 size={40} className="text-success" />
          <p className="text-muted-foreground">{t('resetPasswordSuccessBody')}</p>
          <Link
            to="/login"
            className="rounded-[12px] bg-primary px-6 py-4 text-[15px] font-bold text-primary-foreground"
          >
            {t('resetPasswordGoToLogin')}
          </Link>
        </div>
      </AuthLayout>
    );
  }

  if (step === 'password') {
    return (
      <AuthLayout title={t('resetPasswordTitle')} subtitle={t('resetPasswordSubtitle')}>
        <form onSubmit={submitPassword} className="flex flex-col gap-4" noValidate>
          <Field
            label={t('resetPasswordNewLabel')}
            name="newPassword"
            type="password"
            autoComplete="new-password"
            value={password}
            onChange={(e) => {
              setPassword(e.target.value);
              setError(null);
            }}
          />
          <Field
            label={t('authConfirmPasswordLabel')}
            name="confirmPassword"
            type="password"
            autoComplete="new-password"
            value={confirmPassword}
            error={error}
            onChange={(e) => {
              setConfirmPassword(e.target.value);
              setError(null);
            }}
          />
          <Button type="submit" loading={busy} fullWidth>
            {t('resetPasswordSubmit')}
          </Button>
        </form>
      </AuthLayout>
    );
  }

  if (step === 'code') {
    return (
      <AuthLayout title={t('forgotPasswordCodeHeading')}>
        <form onSubmit={verifyCode} className="flex flex-col gap-4" noValidate>
          <p className="text-center text-muted-foreground">
            {t('forgotPasswordCodeSentTo', { email: email.trim() })}
          </p>
          <Field
            label={t('forgotPasswordCodeHeading')}
            hideLabel
            placeholder="000000"
            name="code"
            inputMode="numeric"
            autoComplete="one-time-code"
            maxLength={CODE_LENGTH}
            value={code}
            error={error}
            onChange={(e) => {
              setCode(e.target.value.replace(/\D/g, ''));
              setError(null);
            }}
            className="text-center text-xl tracking-[0.4em]"
          />
          <Button type="submit" loading={busy} fullWidth>
            {t('verifyConfirmButton')}
          </Button>
          <button
            type="button"
            onClick={() => void resendCode()}
            className="text-sm text-accent hover:underline"
          >
            {t('verifyResendPrompt')}
          </button>
        </form>
      </AuthLayout>
    );
  }

  return (
    <AuthLayout title={t('forgotPasswordTitle')} subtitle={t('forgotPasswordSubtitle')}>
      <form onSubmit={requestCode} className="flex flex-col gap-4" noValidate>
        <Field
          label={t('commonEmailLabel')}
          name="email"
          type="email"
          autoComplete="email"
          inputMode="email"
          value={email}
          error={error}
          onChange={(e) => {
            setEmail(e.target.value);
            setError(null);
          }}
        />
        <Button type="submit" loading={busy} fullWidth>
          {t('forgotPasswordSubmit')}
        </Button>
      </form>

      <p className="mt-6 text-center text-sm">
        <Link to="/login" className="text-accent hover:underline">
          {t('resetPasswordGoToLogin')}
        </Link>
      </p>
    </AuthLayout>
  );
}
