import { useState, type FormEvent } from 'react';
import { useSearchParams } from 'react-router-dom';
import { useTranslation } from 'react-i18next';
import { AuthLayout } from './AuthLayout';
import { Button, Field } from '@/components/ui';
import { VerifyCodeSection } from './VerifyCodeSection';

/**
 * Ecran cu ADRESĂ PROPRIE pentru confirmarea contului.
 *
 * Până acum câmpul de cod trăia doar în starea locală a ecranului de
 * înregistrare. Dacă ieșeai din el - back, refresh, închis din greșeală -
 * starea se pierdea și nu mai exista niciun drum înapoi: autentificarea îți
 * spunea „confirmă-ți emailul", dar nu aveai unde să introduci codul. Contul
 * era creat și inutilizabil.
 *
 * Cu o rută adevărată, ecranul se poate redeschide oricând, se poate pune la
 * favorite și supraviețuiește unui refresh. Emailul vine din adresă
 * (`?email=`), nu din starea navigării, tocmai ca să supraviețuiască și el.
 */
export function VerifyEmailScreen() {
  const { t } = useTranslation();
  const [params, setParams] = useSearchParams();

  const emailFromUrl = params.get('email')?.trim() ?? '';
  const [typedEmail, setTypedEmail] = useState('');

  if (emailFromUrl) {
    return (
      <AuthLayout title={t('verifyEmailHeading')}>
        <VerifyCodeSection email={emailFromUrl} />
      </AuthLayout>
    );
  }

  /*
    Fără adresă în URL (cineva a deschis /verify-email direct) o cerem, în loc
    să arătăm un ecran mort. O punem apoi în adresă, ca de acolo încolo
    refresh-ul să funcționeze ca oriunde altundeva.
  */
  function onSubmit(event: FormEvent) {
    event.preventDefault();
    const value = typedEmail.trim();
    if (value) setParams({ email: value }, { replace: true });
  }

  return (
    <AuthLayout title={t('verifyEmailHeading')}>
      <form onSubmit={onSubmit} className="flex flex-col gap-4" noValidate>
        <Field
          label={t('commonEmailLabel')}
          name="email"
          type="email"
          autoComplete="email"
          inputMode="email"
          value={typedEmail}
          onChange={(event) => setTypedEmail(event.target.value)}
        />
        <Button type="submit" fullWidth disabled={!typedEmail.trim()}>
          {t('commonContinue')}
        </Button>
      </form>
    </AuthLayout>
  );
}
