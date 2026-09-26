import { useState, type FormEvent } from 'react';
import { useMutation } from '@tanstack/react-query';
import { useNavigate } from 'react-router-dom';
import { useTranslation } from 'react-i18next';
import { Check } from 'lucide-react';
import { BrandMark } from '@/components/ui/BrandMark';
import { api } from '@/lib/api/client';
import { profileRepository } from './profileRepository';
import { Button, Field } from '@/components/ui';
import { Switch } from '@/components/ui/Switch';
import { useToast } from '@/components/ui/Toast';
import { useAuth } from './../auth/AuthProvider';
import { cn } from '@/lib/utils/cn';

/**
 * Pre-înscrierea pentru aplicația de Android. E o rută PUBLICĂ: se ajunge aici
 * de pe materialele de marketing, fără cont. De aceea nu presupune un user
 * logat, dar îi precompletează adresa dacă există.
 */
export function PreRegistrationScreen() {
  const { t } = useTranslation();
  const { user } = useAuth();
  const toast = useToast();
  const [email, setEmail] = useState('');
  const [done, setDone] = useState(false);

  const submit = useMutation({
    // Adresa userului logat e folosită doar dacă n-a scris alta - de aceea
    // câmpul rămâne gol și nu precompletat: altfel, cine vrea altă adresă ar
    // trebui întâi să o șteargă pe cea pusă automat.
    mutationFn: () => api.post('/pre-registration', { email: email.trim() || user?.email }),
    onSuccess: () => setDone(true),
    onError: () => toast.show(t('preRegisterError'), 'danger'),
  });

  function onSubmit(event: FormEvent) {
    event.preventDefault();
    if (!email.trim() && !user?.email) return;
    submit.mutate();
  }

  return (
    <div className="flex min-h-dvh flex-col items-center justify-center bg-background px-5 py-10">
      <div className="w-full max-w-[420px]">
        <div className="mb-8 flex flex-col items-center gap-3 text-center">
          <BrandMark size={56} />
          <h1 className="font-display text-2xl font-bold">{t('preRegisterAndroidHeadline')}</h1>
          <p className="text-muted-foreground">{t('preRegisterAndroidBody')}</p>
        </div>

        {done ? (
          <div className="flex flex-col items-center gap-3 rounded-[16px] border border-success/40 bg-success/10 p-6 text-center">
            <Check size={28} className="text-success" />
            <p className="text-success">{t('preRegisterSuccess')}</p>
          </div>
        ) : (
          <form onSubmit={onSubmit} className="flex flex-col gap-4">
            <Field
              label={t('preRegisterEmailHint')}
              name="email"
              type="email"
              inputMode="email"
              autoComplete="email"
              value={email}
              onChange={(event) => setEmail(event.target.value)}
            />
            {user?.email && (
              <p className="text-sm text-muted-foreground">{t('preRegisterAlreadyLoggedIn')}</p>
            )}
            <Button type="submit" loading={submit.isPending} fullWidth>
              {t('preRegisterSubmit')}
            </Button>
          </form>
        )}
      </div>
    </div>
  );
}

const PURPOSES = ['Swap', 'Sell', 'Discover', 'All'] as const;
const FREQUENCIES = ['Low', 'Mid', 'High'] as const;

/*
  Valorile din formular sunt chei de traducere; backendul așteaptă altceva
  (`@IsIn` din ReadingSurveyDto). Traducem la trimitere, nu în formular:
  etichetele rămân citibile în cod, iar contractul cu API-ul stă într-un
  singur loc.
*/
const PURPOSE_VALUES: Record<(typeof PURPOSES)[number], string> = {
  Swap: 'swap',
  Sell: 'sell',
  Discover: 'discover',
  All: 'all',
};

/** Ritmul de citire, în cărți pe lună - vezi READING_PACES pe backend. */
const PACE_VALUES: Record<(typeof FREQUENCIES)[number], string> = {
  Low: '1',
  Mid: '2-3',
  High: '4+',
};

/**
 * Onboardingul de după primul login: nume, oraș, ce caută userul aici și cât
 * de des citește. Port al pașilor esențiali din onboarding_flow_screen.dart -
 * selecția de genuri și chestionarul de lectură vin cu ecranul lor.
 *
 * Fiecare pas salvează CE POATE la final, într-un singur PATCH. În Flutter
 * erau salvări intermediare, dar pe web un refresh la jumătatea fluxului ar
 * lăsa un profil completat pe jumătate, fără ca userul să știe.
 */
export function OnboardingScreen() {
  const { t } = useTranslation();
  const { user, setUser } = useAuth();
  const navigate = useNavigate();
  const toast = useToast();

  const [step, setStep] = useState(0);
  const [name, setName] = useState(user?.name ?? '');
  const [username, setUsername] = useState(user?.username ?? '');
  const [nameVisible, setNameVisible] = useState(user?.nameVisible ?? true);
  const [city, setCity] = useState(user?.city ?? '');
  const [purpose, setPurpose] = useState<string>('All');
  const [frequency, setFrequency] = useState<string>('Mid');
  const [error, setError] = useState<string | null>(null);

  const save = useMutation({
    mutationFn: async () => {
      const updated = await profileRepository.update({
        name: name.trim() || null,
        username: username.trim() || null,
        nameVisible,
        city: city.trim() || null,
      });

      /*
        Chestionarul se trimite și el, nu doar se completează pe ecran.

        Răspunsurile erau colectate în stare și aruncate la final: se salva doar
        profilul. Pe lângă datele pierdute, asta lăsa `readingSurveyCompletedAt`
        gol pentru totdeauna - adică semnalul după care routerul știe că
        onboardingul s-a terminat nu se aprindea niciodată.
      */
      const survey = await profileRepository.saveReadingSurvey({
        purpose: PURPOSE_VALUES[purpose as (typeof PURPOSES)[number]],
        readingPace: PACE_VALUES[frequency as (typeof FREQUENCIES)[number]],
      });

      // Endpointul de chestionar nu întoarce userul întreg, doar câmpurile lui.
      return { ...updated, readingSurveyCompletedAt: survey.readingSurveyCompletedAt };
    },
    onSuccess: (updated) => {
      setUser(updated);
      void navigate('/');
    },
    onError: () => toast.show(t('onboardingGenericError'), 'danger'),
  });

  const steps = [
    {
      title: t('onboardingTitle'),
      subtitle: t('onboardingSubtitle'),
      body: (
        <div className="flex flex-col gap-4">
          <Field
            label={t('onboardingLastName')}
            name="name"
            autoComplete="name"
            value={name}
            error={error}
            onChange={(event) => {
              setName(event.target.value);
              setError(null);
            }}
          />
          <Field
            label={t('onboardingUsername')}
            name="username"
            autoComplete="username"
            value={username}
            onChange={(event) => setUsername(event.target.value)}
            // Aici se alege username-ul, deci aici trebuie spus că e definitiv -
            // nu într-un mesaj de eroare, după ce omul încearcă să-l schimbe.
            hint={t('usernameChooseOnceHint')}
          />
          <Switch
            checked={nameVisible}
            onChange={setNameVisible}
            label={t('onboardingNameVisibleSwitch')}
            hint={t('onboardingUsernameAlwaysVisible')}
          />
        </div>
      ),
    },
    {
      title: t('onboardingFlowLocationTitle'),
      subtitle: t('onboardingFlowLocationSubtitle'),
      body: (
        <Field
          label={t('profileCityLabel')}
          name="city"
          autoComplete="address-level2"
          value={city}
          onChange={(event) => setCity(event.target.value)}
        />
      ),
    },
    {
      title: t('onboardingFlowPurposeTitle'),
      subtitle: t('onboardingFlowPurposeSubtitle'),
      body: (
        <ChoiceList
          options={PURPOSES.map((key) => ({
            value: key,
            title: t(`onboardingFlowPurpose${key}Title`),
            description: t(`onboardingFlowPurpose${key}Desc`),
          }))}
          selected={purpose}
          onSelect={setPurpose}
        />
      ),
    },
    {
      title: t('onboardingFlowFrequencyTitle'),
      subtitle: t('onboardingFlowFrequencySubtitle'),
      body: (
        <ChoiceList
          options={FREQUENCIES.map((key) => ({
            value: key,
            title: t(`onboardingFlowFrequency${key}Title`),
            description: t(`onboardingFlowFrequency${key}Desc`),
          }))}
          selected={frequency}
          onSelect={setFrequency}
        />
      ),
    },
  ];

  const isLast = step === steps.length - 1;
  const current = steps[step];

  function next() {
    // Numele e singurul câmp obligatoriu - restul pot fi sărite.
    if (step === 0 && !name.trim()) {
      setError(t('commonRequired'));
      return;
    }
    if (isLast) save.mutate();
    else setStep((value) => value + 1);
  }

  return (
    <div className="mx-auto flex min-h-dvh w-full max-w-[480px] flex-col justify-center px-5 py-12">
      <p className="mb-2 text-center text-sm text-muted-foreground">
        {t('onboardingFlowStepLabel', { step: step + 1, total: steps.length })}
      </p>

      <div className="mb-6 flex justify-center gap-1.5">
        {steps.map((item, index) => (
          <span
            key={item.title}
            className={cn(
              'h-1.5 rounded-full transition-all',
              index === step ? 'w-6 bg-accent' : 'w-1.5 bg-border',
            )}
          />
        ))}
      </div>

      <h1 className="mb-2 text-center font-display text-2xl font-bold">{current.title}</h1>
      <p className="mb-6 text-center text-muted-foreground">{current.subtitle}</p>

      {current.body}

      <div className="mt-8 flex flex-col gap-2">
        <Button fullWidth loading={save.isPending} onClick={next}>
          {t(isLast ? 'onboardingFlowFinish' : 'commonContinue')}
        </Button>
        {!isLast && (
          <Button variant="text" fullWidth onClick={() => setStep((value) => value + 1)}>
            {t('onboardingFlowSkip')}
          </Button>
        )}
      </div>
    </div>
  );
}

function ChoiceList({
  options,
  selected,
  onSelect,
}: {
  options: Array<{ value: string; title: string; description: string }>;
  selected: string;
  onSelect: (value: string) => void;
}) {
  return (
    <div className="flex flex-col gap-2">
      {options.map((option) => (
        <button
          key={option.value}
          type="button"
          onClick={() => onSelect(option.value)}
          className={cn(
            'rounded-[16px] border p-4 text-left transition',
            selected === option.value
              ? 'border-accent bg-accent/10'
              : 'border-border bg-card hover:bg-muted',
          )}
        >
          <span className="block font-semibold">{option.title}</span>
          <span className="mt-0.5 block text-sm text-muted-foreground">{option.description}</span>
        </button>
      ))}
    </div>
  );
}
