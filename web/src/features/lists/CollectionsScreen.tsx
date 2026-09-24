import { useState, type FormEvent } from 'react';
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { Link } from 'react-router-dom';
import { useTranslation } from 'react-i18next';
import { ScreenHeader } from '@/components/layout/ScreenHeader';
import { Globe, Lock, Plus } from 'lucide-react';
import { collectionsRepository, listsKeys } from './listsRepository';
import { Button, ErrorNotice, Field, Spinner } from '@/components/ui';
import { Switch } from '@/components/ui/Switch';

export function CollectionsScreen() {
  const { t } = useTranslation();
  const queryClient = useQueryClient();

  const [creating, setCreating] = useState(false);
  const [name, setName] = useState('');
  const [isPublic, setIsPublic] = useState(false);

  const collections = useQuery({
    queryKey: listsKeys.collections(),
    queryFn: ({ signal }) => collectionsRepository.mine(signal),
  });

  const create = useMutation({
    mutationFn: () => collectionsRepository.create({ name: name.trim(), isPublic }),
    onSuccess: () => {
      void queryClient.invalidateQueries({ queryKey: listsKeys.collections() });
      setCreating(false);
      setName('');
      setIsPublic(false);
    },
  });

  function onCreate(event: FormEvent) {
    event.preventDefault();
    if (!name.trim()) return;
    create.mutate();
  }

  const header = <ScreenHeader title={t('collectionsTitle')} back />;

  if (collections.isPending) {
    return (
      <div className="flex min-h-dvh items-center justify-center text-accent">
        {header}
        <Spinner size={28} />
      </div>
    );
  }

  if (collections.isError) {
    return (
      <div className="mx-auto max-w-2xl p-6">
        {header}
        <ErrorNotice
          message={t('collectionsLoadError')}
          onRetry={() => void collections.refetch()}
        />
      </div>
    );
  }

  return (
    <div className="mx-auto w-full max-w-[760px] px-5 pb-16 pt-2 min-[900px]:px-8">
      {header}
      <div className="mb-6 flex flex-wrap items-center justify-between gap-3">
        <Button onClick={() => setCreating((open) => !open)}>
          <Plus size={18} />
          {t('collectionsCreateTitle')}
        </Button>
      </div>

      {creating && (
        <form
          onSubmit={onCreate}
          className="mb-6 flex flex-col gap-4 rounded-[16px] border border-border bg-card p-5"
        >
          <Field
            label={t('collectionsNameLabel')}
            name="name"
            value={name}
            autoFocus
            onChange={(event) => setName(event.target.value)}
          />
          <Switch
            checked={isPublic}
            onChange={setIsPublic}
            label={t('collectionsPublicSwitch')}
          />
          <div className="flex gap-2">
            <Button type="submit" loading={create.isPending} disabled={!name.trim()}>
              {t('commonSubmit')}
            </Button>
            <Button type="button" variant="text" onClick={() => setCreating(false)}>
              {t('commonGiveUp')}
            </Button>
          </div>
        </form>
      )}

      {collections.data.length === 0 ? (
        <p className="py-16 text-center text-muted-foreground">{t('collectionsEmpty')}</p>
      ) : (
        <ul className="flex flex-col gap-2">
          {collections.data.map((collection) => (
            <li key={collection.id}>
              <Link
                to={`/collections/${collection.id}`}
                className="flex items-center gap-3 rounded-[16px] border border-border bg-card p-4 hover:bg-muted"
              >
                <span className="shrink-0 text-muted-foreground">
                  {collection.isPublic ? <Globe size={18} /> : <Lock size={18} />}
                </span>
                <div className="min-w-0 flex-1">
                  <p className="truncate font-semibold">{collection.name}</p>
                  <p className="text-sm text-muted-foreground">
                    {t('collectionsBookCount', { count: collection.bookCount })}
                  </p>
                </div>
              </Link>
            </li>
          ))}
        </ul>
      )}
    </div>
  );
}
