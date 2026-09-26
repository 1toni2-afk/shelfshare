import { useState, type FormEvent } from 'react';
import { useMutation, useQueryClient } from '@tanstack/react-query';
import { useNavigate } from 'react-router-dom';
import { useTranslation } from 'react-i18next';
import { ScreenHeader } from '@/components/layout/ScreenHeader';

import { profileKeys, profileRepository } from './profileRepository';
import { Button, Field } from '@/components/ui';
import { Switch } from '@/components/ui/Switch';
import { useToast } from '@/components/ui/Toast';
import { useAuth } from '@/features/auth/AuthProvider';

export function EditProfileScreen() {
  const { t } = useTranslation();
  const { user, setUser } = useAuth();
  const navigate = useNavigate();
  const queryClient = useQueryClient();
  const toast = useToast();

  /**
   * Formularul se precompletează din userul de AUTENTIFICARE, nu dintr-un
   * query separat de profil.
   *
   * Motivul e un bug real din Flutter: valoarea în cache a unui query putea
   * rămâne cea a contului anterior logat pe același browser, iar formularul
   * se deschidea cu numele altcuiva. Userul din auth e mereu al sesiunii
   * curente, fiindcă se golește la logout.
   */
  const [name, setName] = useState(user?.name ?? '');
  const [username, setUsername] = useState(user?.username ?? '');
  const [city, setCity] = useState(user?.city ?? '');
  const [bio, setBio] = useState(user?.bio ?? '');
  const [nameVisible, setNameVisible] = useState(user?.nameVisible ?? true);
  const [showAcquisitionHistory, setShowAcquisitionHistory] = useState(
    user?.showAcquisitionHistory ?? false,
  );

  const save = useMutation({
    mutationFn: () =>
      profileRepository.update({
        // Șirurile goale se trimit ca `null`, nu ca "": backendul le-ar salva
        // literal, iar profilul ar afișa un oraș gol în loc să-l ascundă.
        name: name.trim() || null,
        username: username.trim() || null,
        city: city.trim() || null,
        bio: bio.trim() || null,
        nameVisible,
        showAcquisitionHistory,
      }),
    onSuccess: (updated) => {
      setUser(updated);
      queryClient.setQueryData(profileKeys.me(), updated);
      void navigate('/profile');
    },
    onError: () => toast.show(t('profileSaveError'), 'danger'),
  });

  function onSubmit(event: FormEvent) {
    event.preventDefault();
    save.mutate();
  }

  const header = <ScreenHeader title={t('profileEditProfile')} back="/profile" />;

  return (
    <div className="mx-auto w-full max-w-[560px] px-5 pb-16 pt-2 min-[900px]:px-8">
      {header}
      <form onSubmit={onSubmit} className="flex flex-col gap-4">
        <Field
          label={t('onboardingLastName')}
          name="name"
          autoComplete="name"
          value={name}
          onChange={(event) => setName(event.target.value)}
        />

        {/* Username-ul se alege o dată și rămâne: e identificatorul public al
            omului. Câmpul e blocat vizibil, cu motivul scris dedesubt - un
            câmp editabil care ar fi respins de server la salvare e mai rău
            decât unul care spune din start că nu se poate. Regula e impusă și
            pe server (ProfileService#updateMyProfile). */}
        <Field
          label={t('profileUsernameLabel')}
          name="username"
          autoComplete="username"
          value={username}
          onChange={(event) => setUsername(event.target.value)}
          disabled={!!user?.username}
          hint={t(user?.username ? 'usernameLockedHint' : 'usernameChooseOnceHint')}
        />

        <Field
          label={t('profileCityLabel')}
          name="city"
          autoComplete="address-level2"
          value={city}
          onChange={(event) => setCity(event.target.value)}
        />

        <div className="flex flex-col gap-1.5">
          <label htmlFor="bio" className="text-sm font-medium text-muted-foreground">
            {t('profileAboutMe')}
          </label>
          <textarea
            id="bio"
            rows={4}
            value={bio}
            onChange={(event) => setBio(event.target.value)}
            className="w-full resize-y rounded-[16px] bg-muted px-4 py-4 text-foreground placeholder:text-muted-foreground focus:outline-none"
          />
        </div>

        <Switch
          checked={nameVisible}
          onChange={setNameVisible}
          label={t('onboardingNameVisibleSwitch')}
          hint={t('onboardingUsernameAlwaysVisible')}
        />

        <Switch
          checked={showAcquisitionHistory}
          onChange={setShowAcquisitionHistory}
          label={t('profileShowAcquisitionHistory')}
          hint={t('profileShowAcquisitionHistorySubtitle')}
        />

        <Button type="submit" loading={save.isPending} fullWidth className="mt-2">
          {t('commonSave')}
        </Button>
      </form>
    </div>
  );
}
