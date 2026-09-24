import { useState, type FormEvent } from 'react';
import { Link, Navigate } from 'react-router-dom';
import { useTranslation } from 'react-i18next';
import { Button, Field } from '@/components/ui';
import { AuthLayout } from './AuthLayout';
import { useAuth } from './AuthProvider';

const MIN_PASSWORD_LENGTH = 8;

export function RegisterScreen() {
  const { t } = useTranslation();
  const { status, register, busy, clearError } = useAuth();

  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [confirmPassword, setConfirmPassword] = useState('');
  const [referralCode, setReferralCode] = useState('');
  const [errors, setErrors] = useState<Record<string, string>>({});

  // Contul a fost creat: rămânem pe ACELAȘI ecran și arătăm câmpul de cod, nu
  // navigăm. Userul tocmai și-a scris adresa - dacă l-am muta pe altă pagină,
  // ar trebui s-o rescrie, iar o greșeală de tipar nu s-ar mai putea corecta
  // fără să reia tot.
  const [registered, setRegistered] = useState(false);

  if (status.kind === 'authenticated') return <Navigate to="/" replace />;

  function validate(): boolean {
    const next: Record<string, string> = {};
    if (!/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(email.trim())) {
      next.email = t('commonEmailInvalid');
    }
    if (password.length < MIN_PASSWORD_LENGTH) {
      next.password = t('authMinEightChars');
    }
    if (password !== confirmPassword) {
      next.confirmPassword = t('authPasswordMismatch');
    }
    setErrors(next);
    return Object.keys(next).length === 0;
  }

  async function onSubmit(event: FormEvent) {
    event.preventDefault();
    if (!validate()) return;

    await register({
      email: email.trim(),
      password,
      referralCode: referralCode.trim() || undefined,
    });
    setRegistered(true);
  }

  // `register` pune starea pe `error` dacă backendul a refuzat (ex. adresă deja
  // folosită). Fără verificarea asta am arăta câmpul de cod pentru un cont care
  // nu s-a creat niciodată.
  const failed = status.kind === 'error';

  /*
    Mergem la RUTA de confirmare, nu doar la o stare locală: dacă omul dă back
    sau reîncarcă pagina, ecranul de cod trebuie să existe în continuare. Vezi
    VerifyEmailScreen.
  */
  if (registered && !failed) {
    return <Navigate to={`/verify-email?email=${encodeURIComponent(email.trim())}`} replace />;
  }

  return (
    <AuthLayout title={t('authRegisterTitle')} subtitle={t('authRegisterSubtitle')}>
      <form onSubmit={onSubmit} className="flex flex-col gap-4" noValidate>
        <Field
          label={t('commonEmailLabel')}
          name="email"
          type="email"
          autoComplete="email"
          inputMode="email"
          value={email}
          error={errors.email}
          onChange={(e) => {
            setEmail(e.target.value);
            clearError();
          }}
        />

        <Field
          label={t('authPasswordLabel')}
          name="password"
          type="password"
          autoComplete="new-password"
          value={password}
          error={errors.password}
          onChange={(e) => {
            setPassword(e.target.value);
            clearError();
          }}
        />

        <Field
          label={t('authConfirmPasswordLabel')}
          name="confirmPassword"
          type="password"
          autoComplete="new-password"
          value={confirmPassword}
          error={errors.confirmPassword}
          onChange={(e) => setConfirmPassword(e.target.value)}
        />

        <Field
          label={t('authReferralCodeLabel')}
          name="referralCode"
          autoComplete="off"
          value={referralCode}
          onChange={(e) => setReferralCode(e.target.value)}
        />

        {failed && (
          <p role="alert" className="text-sm text-danger-text">
            {status.message}
          </p>
        )}

        <Button type="submit" loading={busy} fullWidth>
          {t('authRegisterTitle')}
        </Button>
      </form>

      <p className="mt-6 text-center text-sm text-muted-foreground">
        <Link to="/login" className="font-semibold text-accent hover:underline">
          {t('authLoginSubmit')}
        </Link>
      </p>
    </AuthLayout>
  );
}
