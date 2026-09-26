import { useState, type FormEvent } from 'react';
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { Link } from 'react-router-dom';
import { useTranslation } from 'react-i18next';
import { ScreenHeader } from '@/components/layout/ScreenHeader';
import { FolderTabs } from '@/components/ui/FolderTabs';
import { Plus, Users } from 'lucide-react';
import { groupsRepository, socialKeys } from './socialRepository';
import { Button, ErrorNotice, Field, Spinner } from '@/components/ui';
import { Switch } from '@/components/ui/Switch';

type Tab = 'mine' | 'discover';

export function GroupsScreen() {
  const { t } = useTranslation();
  const queryClient = useQueryClient();

  const [tab, setTab] = useState<Tab>('mine');
  const [creating, setCreating] = useState(false);
  const [name, setName] = useState('');
  const [description, setDescription] = useState('');
  const [isPublic, setIsPublic] = useState(true);

  const groups = useQuery({
    queryKey: tab === 'mine' ? socialKeys.groupsMine() : socialKeys.groupsDiscover(),
    queryFn: ({ signal }) =>
      tab === 'mine' ? groupsRepository.mine(signal) : groupsRepository.discover(signal),
  });

  const create = useMutation({
    mutationFn: () =>
      groupsRepository.create({
        name: name.trim(),
        description: description.trim() || undefined,
        isPublic,
      }),
    onSuccess: () => {
      void queryClient.invalidateQueries({ queryKey: socialKeys.groupsMine() });
      void queryClient.invalidateQueries({ queryKey: socialKeys.groupsDiscover() });
      setCreating(false);
      setName('');
      setDescription('');
    },
  });

  function onCreate(event: FormEvent) {
    event.preventDefault();
    if (!name.trim()) return;
    create.mutate();
  }

  const header = <ScreenHeader title={t('groupsTitle')} back />;

  return (
    <div className="mx-auto w-full max-w-[680px] px-5 pb-16 pt-2 min-[900px]:px-8">
      {header}
      <FolderTabs
        label={t('groupsTitle')}
        value={tab}
        onChange={setTab}
        tabs={[
          { value: 'discover' as const, label: t('groupsTabDiscover') },
          { value: 'mine' as const, label: t('groupsTabMine') },
        ]}
        className="mt-2"
      >
      <div className="mb-4 flex flex-wrap items-center justify-between gap-3">
        <Button onClick={() => setCreating((open) => !open)}>
          <Plus size={18} />
          {t('groupsCreateTitle')}
        </Button>
      </div>

      {creating && (
        <form
          onSubmit={onCreate}
          className="mb-6 flex flex-col gap-4 rounded-[16px] border border-border bg-card p-5"
        >
          <Field
            label={t('groupsNameLabel')}
            name="name"
            value={name}
            autoFocus
            onChange={(event) => setName(event.target.value)}
          />
          <div className="flex flex-col gap-1.5">
            <label htmlFor="description" className="text-sm font-medium text-muted-foreground">
              {t('groupsDescriptionLabel')}
            </label>
            <textarea
              id="description"
              rows={3}
              value={description}
              onChange={(event) => setDescription(event.target.value)}
              className="w-full resize-y rounded-[16px] bg-muted px-4 py-4 text-foreground focus:outline-none"
            />
          </div>
          <Switch checked={isPublic} onChange={setIsPublic} label={t('collectionsPublicSwitch')} />
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

      {groups.isPending ? (
        <div className="flex h-40 items-center justify-center text-accent">
          <Spinner size={26} />
        </div>
      ) : groups.isError ? (
        <ErrorNotice message={t('groupsLoadError')} onRetry={() => void groups.refetch()} />
      ) : groups.data.length === 0 ? (
        <p className="py-16 text-center text-muted-foreground">{t('groupsEmpty')}</p>
      ) : (
        <ul className="flex flex-col gap-2">
          {groups.data.map((group) => (
            <li key={group.id}>
              <Link
                to={`/groups/${group.id}`}
                className="flex items-center gap-3 rounded-[16px] border border-border bg-card p-4 hover:bg-muted"
              >
                <Users size={18} className="shrink-0 text-muted-foreground" />
                <div className="min-w-0 flex-1">
                  <p className="truncate font-semibold">{group.name}</p>
                  {group.description && (
                    <p className="truncate text-sm text-muted-foreground">{group.description}</p>
                  )}
                  <p className="text-xs text-muted-foreground">
                    {t('groupsMemberCount', { count: group.memberCount })}
                  </p>
                </div>
              </Link>
            </li>
          ))}
        </ul>
      )}
      </FolderTabs>
    </div>
  );
}
