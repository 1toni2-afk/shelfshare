import { useState, type FormEvent } from 'react';
import { useNavigate } from 'react-router-dom';
import { useTranslation } from 'react-i18next';
import { Button, Field } from '@/components/ui';
import { useToast } from '@/components/ui/Toast';
import { authRepository } from './authRepository';

const CODE_LENGTH = 6;

/**
 * Confirmarea contului printr-un cod de 6 cifre, afișată direct după crearea
 * contului - nu printr-un link separat din email.
 *
 * Motivul e istoric și rămâne valabil: linkurile de confirmare aveau probleme
 * cu cache-ul browserului și cu service worker-ul, iar un cod introdus manual
 * nu depinde de nicio navigare.
 */
export function VerifyCodeSection({ email }: { email: string }) {
  const { t } = useTranslation();
  const navigate = useNavigate();
  const toast = useToast();

  const [code, setCode] = useState('');
  const [error, setError] = useState<string | null>(null);
  const [submitting, setSubmitting] = useState(false);
  const [resending, setResending] = useState(false);

  async function onSubmit(event: FormEvent) {
    event.preventDefault();
    if (code.trim().length !== CODE_LENGTH) {
      setError(t('verifyCodeTooShort'));
      return;
    }

    setSubmitting(true);
    setError(null);
    try {
      await authRepository.verifyEmail(email, code.trim());
      toast.show(t('verifySuccessSnackbar'));
      void navigate('/login', { replace: true });
    } catch {
      // Mesaj unic pentru orice eșec, ca în Flutter: un text diferit pentru
      // „cod greșit" față de „cod expirat" ar spune unui atacator care dintre
      // cele două a nimerit.
      setError(t('verifyInvalidOrExpired'));
    } finally {
      setSubmitting(false);
    }
  }

  async function onResend() {
    setResending(true);
    try {
      await authRepository.resendVerificationCode(email);
    } catch {
      // Ignorăm eșecul dinadins: mesajul de mai jos e formulat neutru („dacă
      // este necesar"), ca să nu confirme dacă adresa există sau nu în baza.
    } finally {
      setResending(false);
      toast.show(t('verifyResendSnackbar'));
    }
  }

  return (
    <form onSubmit={onSubmit} className="flex flex-col gap-4" noValidate>
      <p className="text-center text-muted-foreground">{t('verifySentTo', { email })}</p>

      <Field
        label={t('verifyEmailHeading')}
        hideLabel
        placeholder="000000"
        name="code"
        // `inputMode numeric` + `autoComplete one-time-code`: pe telefon apare
        // tastatura numerică, iar codul primit prin SMS/email e sugerat automat.
        inputMode="numeric"
        autoComplete="one-time-code"
        maxLength={CODE_LENGTH}
        value={code}
        error={error}
        onChange={(e) => {
          // Filtrăm non-cifrele la sursă: un cod lipit din email vine adesea
          // cu spații, iar backendul l-ar respinge fără niciun indiciu vizibil.
          setCode(e.target.value.replace(/\D/g, ''));
          setError(null);
        }}
        className="text-center text-xl tracking-[0.4em]"
      />

      <Button type="submit" loading={submitting} fullWidth>
        {t('verifyConfirmButton')}
      </Button>

      <button
        type="button"
        onClick={() => void onResend()}
        disabled={resending}
        className="text-sm text-accent hover:underline disabled:opacity-60"
      >
        {resending ? t('verifyResending') : t('verifyResendPrompt')}
      </button>
    </form>
  );
}
