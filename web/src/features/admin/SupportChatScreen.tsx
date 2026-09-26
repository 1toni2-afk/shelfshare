import { useEffect, useState, type FormEvent } from 'react';
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { useTranslation } from 'react-i18next';
import { ScreenHeader } from '@/components/layout/ScreenHeader';
import { Circle, Send } from 'lucide-react';
import { adminChatRepository, adminKeys } from './adminRepository';
import { ErrorNotice, Spinner } from '@/components/ui';
import { formatTime } from '@/lib/utils/time';
import { cn } from '@/lib/utils/cn';

const GUIDELINES = ['ResponseTime', 'NoSpam', 'BeRespectful'] as const;

/**
 * Firul userului cu echipa de suport. E cealaltă față a aceluiași lucru pe
 * care adminii îl văd în `/admin/chat`: aici e o singură conversație, a mea,
 * fără listă și fără alegere de destinatar.
 */
export function SupportChatScreen() {
  const { t, i18n } = useTranslation();
  const queryClient = useQueryClient();
  const [draft, setDraft] = useState('');

  const thread = useQuery({
    queryKey: adminKeys.adminChatMine(),
    queryFn: ({ signal }) => adminChatRepository.myThread(signal),
  });

  // Marcăm citit la deschidere, ca badge-ul de notificări să scadă imediat.
  // Eșecul e ignorat: e o curățenie, nu o acțiune pe care userul o așteaptă.
  useEffect(() => {
    if (!thread.isSuccess) return;
    void adminChatRepository.markMineRead().catch(() => {});
  }, [thread.isSuccess]);

  const send = useMutation({
    mutationFn: () => adminChatRepository.sendAsUser(draft.trim()),
    onSuccess: () => {
      setDraft('');
      void queryClient.invalidateQueries({ queryKey: adminKeys.adminChatMine() });
    },
  });

  function onSend(event: FormEvent) {
    event.preventDefault();
    if (draft.trim()) send.mutate();
  }

  const header = <ScreenHeader title={t('adminChatTitle')} back />;

  return (
    <div className="mx-auto w-full max-w-[680px] px-5 pb-16 pt-2 min-[900px]:px-8">
      {header}
      {/* Regulile se arată DOAR când firul e gol. După primul mesaj ar fi doar
          zgomot deasupra conversației. */}
      {thread.isSuccess && thread.data.length === 0 && (
        <section className="mb-6 rounded-[16px] border border-border bg-card p-5">
          <h2 className="mb-2 font-display text-lg font-bold">{t('adminChatGuidelinesTitle')}</h2>
          <p className="mb-3 text-muted-foreground">{t('adminChatGuidelinesIntro')}</p>
          <ul className="flex flex-col gap-1.5 text-sm text-muted-foreground">
            {GUIDELINES.map((key) => (
              <li key={key} className="flex gap-2">
                <Circle size={6} className="mt-1.5 shrink-0 fill-accent text-accent" />
                {t(`adminChatGuideline${key}`)}
              </li>
            ))}
          </ul>
        </section>
      )}

      {thread.isPending ? (
        <div className="flex h-40 items-center justify-center text-accent">
          <Spinner size={26} />
        </div>
      ) : thread.isError ? (
        <ErrorNotice message={t('chatLoadError')} onRetry={() => void thread.refetch()} />
      ) : thread.data.length === 0 ? (
        <p className="py-8 text-center text-muted-foreground">{t('adminChatEmpty')}</p>
      ) : (
        <ul className="mb-4 flex flex-col gap-2">
          {thread.data.map((message) => (
            <li
              key={message.id}
              className={cn(
                'max-w-[80%] rounded-[16px] px-4 py-2.5',
                // `fromAdmin` inversat față de chatul normal: aici „al meu" e
                // mesajul care NU vine de la administrator.
                message.fromAdmin
                  ? 'self-start border border-border bg-card'
                  : 'self-end bg-primary text-primary-foreground',
              )}
            >
              <p className="whitespace-pre-line break-words">{message.content}</p>
              <p
                className={cn(
                  'mt-1 text-right text-[11px]',
                  message.fromAdmin ? 'text-muted-foreground' : 'text-primary-foreground/70',
                )}
              >
                {formatTime(message.createdAt, i18n.language)}
              </p>
            </li>
          ))}
        </ul>
      )}

      <form onSubmit={onSend} className="flex items-end gap-2">
        <textarea
          value={draft}
          onChange={(event) => setDraft(event.target.value)}
          rows={2}
          placeholder={t('adminChatInputHint')}
          aria-label={t('adminChatInputHint')}
          className="max-h-32 w-full resize-none rounded-[16px] bg-muted px-4 py-3.5 text-foreground placeholder:text-muted-foreground focus:outline-none"
        />
        <button
          type="submit"
          disabled={!draft.trim() || send.isPending}
          aria-label={t('commonSubmit')}
          className="shrink-0 rounded-full bg-primary p-3 text-primary-foreground disabled:opacity-50"
        >
          {send.isPending ? <Spinner size={20} /> : <Send size={20} />}
        </button>
      </form>
    </div>
  );
}
