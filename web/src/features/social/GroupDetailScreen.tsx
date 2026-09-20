import { useState, type FormEvent } from 'react';
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { Link, useParams } from 'react-router-dom';
import { useTranslation } from 'react-i18next';
import { ScreenHeader } from '@/components/layout/ScreenHeader';
import { CalendarDays, MapPin, Send } from 'lucide-react';
import { groupsRepository, socialKeys } from './socialRepository';
import { Avatar } from '@/components/ui/Avatar';
import { Button, ErrorNotice, Spinner } from '@/components/ui';
import { formatRelativeTime } from '@/lib/utils/time';
import { useAuth } from '@/features/auth/AuthProvider';
import { useDocumentMeta } from '@/lib/seo/useDocumentMeta';
import { groupTitle } from '@/lib/seo/routes';

export function GroupDetailScreen() {
  const { id = '' } = useParams();
  const { t, i18n } = useTranslation();
  const { user } = useAuth();
  const queryClient = useQueryClient();
  const [draft, setDraft] = useState('');

  const group = useQuery({
    queryKey: socialKeys.group(id),
    queryFn: ({ signal }) => groupsRepository.detail(id, signal),
    enabled: !!id,
  });

  /*
    Descrierea se ia din datele grupului, NU din discuție. Postările rămân
    vizibile în pagină, dar nu intră în metadate și nici în varianta
    pre-randată de beta-server.js: sunt mesaje scrise de oameni pentru grupul
    lor, iar un citat dintr-o discuție ajuns în descrierea din Google e cu
    totul altceva decât un grup listat public.
  */
  useDocumentMeta(
    group.data
      ? {
          title: groupTitle(group.data.name),
          description:
            group.data.description ||
            `${group.data.name} - club de lectură pe ShelfShare, cu ${group.data.memberCount} membri.`,
          path: `/groups/${id}`,
        }
      : null,
  );

  const membership = useMutation({
    mutationFn: (join: boolean) =>
      join ? groupsRepository.join(id) : groupsRepository.leave(id),
    onSuccess: () => {
      void queryClient.invalidateQueries({ queryKey: socialKeys.group(id) });
      void queryClient.invalidateQueries({ queryKey: socialKeys.groupsMine() });
    },
  });

  const post = useMutation({
    mutationFn: () => groupsRepository.post(id, draft.trim()),
    onSuccess: () => {
      setDraft('');
      void queryClient.invalidateQueries({ queryKey: socialKeys.group(id) });
    },
  });

  const header = <ScreenHeader title={group.data?.name ?? t('groupsTitle')} back="/groups" />;

  if (group.isPending) {
    return (
      <div className="flex min-h-dvh items-center justify-center text-accent">
        {header}
        <Spinner size={28} />
      </div>
    );
  }

  if (group.isError) {
    return (
      <div className="mx-auto max-w-2xl p-6">
        {header}
        <ErrorNotice message={t('groupsLoadError')} onRetry={() => void group.refetch()} />
      </div>
    );
  }

  const data = group.data;

  function onPost(event: FormEvent) {
    event.preventDefault();
    if (!draft.trim()) return;
    post.mutate();
  }

  return (
    <div className="mx-auto w-full max-w-[680px] px-5 pb-16 pt-2 min-[900px]:px-8">
      {header}
      <header className="mb-6 flex flex-wrap items-start justify-between gap-3">
        <div className="min-w-0">
          <h1 className="font-display text-2xl font-bold">{data.name}</h1>
          {data.description && <p className="mt-1 text-muted-foreground">{data.description}</p>}
          <p className="mt-1 text-sm text-muted-foreground">
            {t('groupsMemberCount', { count: data.memberCount })}
          </p>
        </div>

        {/* Pagina grupului e publică, dar înscrierea cere cont: fără el,
            butonul ar trimite o cerere care se întoarce 401. */}
        {user ? (
          <Button
            variant={data.isMember ? 'outline' : 'primary'}
            loading={membership.isPending}
            onClick={() => membership.mutate(!data.isMember)}
          >
            {t(data.isMember ? 'groupsLeave' : 'groupsJoin')}
          </Button>
        ) : (
          <Link
            to="/login"
            className="rounded-full bg-primary px-5 py-2.5 text-sm font-bold text-primary-foreground"
          >
            {t('groupsJoin')}
          </Link>
        )}
      </header>

      {data.events.length > 0 && (
        <section className="mb-8">
          <h2 className="mb-3 font-display text-lg font-bold">{t('groupsEventsTitle')}</h2>
          <ul className="flex flex-col gap-2">
            {data.events.map((event) => (
              <li
                key={event.id}
                className="flex items-center gap-3 rounded-[16px] border border-border bg-card p-3"
              >
                <CalendarDays size={18} className="shrink-0 text-accent" />
                <div className="min-w-0 flex-1">
                  <p className="truncate font-semibold">{event.title}</p>
                  <p className="text-sm text-muted-foreground">
                    {new Intl.DateTimeFormat(i18n.language, {
                      dateStyle: 'medium',
                      timeStyle: 'short',
                    }).format(new Date(event.startsAt))}
                  </p>
                  {event.location && (
                    <p className="flex items-center gap-1 text-sm text-muted-foreground">
                      <MapPin size={12} />
                      {event.location}
                    </p>
                  )}
                </div>
              </li>
            ))}
          </ul>
        </section>
      )}

      <section>
        <h2 className="mb-3 font-display text-lg font-bold">{t('groupsDiscussionTitle')}</h2>

        {/* Câmpul de postare apare doar membrilor: backendul refuză oricum o
            postare din partea cuiva din afară, iar un formular care eșuează
            garantat e mai rău decât unul absent. */}
        {data.isMember && (
          <form onSubmit={onPost} className="mb-4 flex items-end gap-2">
            <textarea
              value={draft}
              onChange={(event) => setDraft(event.target.value)}
              rows={2}
              placeholder={t('groupsPostHint')}
              aria-label={t('groupsPostHint')}
              className="max-h-40 w-full resize-none rounded-[16px] bg-muted px-4 py-3.5 text-foreground placeholder:text-muted-foreground focus:outline-none"
            />
            <button
              type="submit"
              disabled={!draft.trim() || post.isPending}
              aria-label={t('commonSubmit')}
              className="shrink-0 rounded-full bg-primary p-3 text-primary-foreground disabled:opacity-50"
            >
              {post.isPending ? <Spinner size={20} /> : <Send size={20} />}
            </button>
          </form>
        )}

        {data.posts.length === 0 ? (
          <p className="py-12 text-center text-muted-foreground">{t('groupsNoPosts')}</p>
        ) : (
          <ul className="flex flex-col gap-3">
            {data.posts.map((entry) => {
              const author = entry.author.name ?? entry.author.username ?? t('commonUnknownUser');
              return (
                <li key={entry.id} className="rounded-[16px] border border-border bg-card p-4">
                  <div className="mb-2 flex items-center gap-2">
                    <Avatar src={entry.author.profileImage} name={author} size={28} />
                    <Link
                      to={`/users/${entry.author.id}`}
                      className="truncate text-sm font-semibold hover:underline"
                    >
                      {author}
                    </Link>
                    <span className="ml-auto shrink-0 text-xs text-muted-foreground">
                      {formatRelativeTime(entry.createdAt, i18n.language)}
                    </span>
                  </div>
                  <p className="whitespace-pre-line break-words">{entry.content}</p>
                </li>
              );
            })}
          </ul>
        )}
      </section>
    </div>
  );
}
