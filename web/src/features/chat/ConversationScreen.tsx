import { useEffect, useMemo, useRef, useState, type FormEvent } from 'react';
import { useQuery, useQueryClient } from '@tanstack/react-query';
import { useParams } from 'react-router-dom';
import { useTranslation } from 'react-i18next';
import { ScreenHeader } from '@/components/layout/ScreenHeader';
import { ImageOff, ImagePlus, Send } from 'lucide-react';
import { chatKeys, chatRepository, type ChatMessage } from './chatRepository';
import { chatSocket } from '@/lib/socket/chatSocket';
import { Avatar } from '@/components/ui/Avatar';
import { ErrorNotice, Spinner } from '@/components/ui';
import { useToast } from '@/components/ui/Toast';
import { useAuth } from '@/features/auth/AuthProvider';
import { formatDay, formatTime } from '@/lib/utils/time';
import { cn } from '@/lib/utils/cn';

/** Cât timp ținem indicatorul „scrie…" după ultimul semnal primit. */
const TYPING_TIMEOUT_MS = 3000;

/** Cât de des trimitem semnalul de tastare cât timp userul scrie continuu. */
const TYPING_THROTTLE_MS = 1500;

export function ConversationScreen() {
  const { conversationId = '' } = useParams();
  const { t, i18n } = useTranslation();
  const { user } = useAuth();
  const queryClient = useQueryClient();
  const toast = useToast();

  const [draft, setDraft] = useState('');
  const [sending, setSending] = useState(false);
  const [otherOnline, setOtherOnline] = useState(false);
  const [otherTyping, setOtherTyping] = useState(false);

  const bottomRef = useRef<HTMLDivElement>(null);
  const lastTypingSent = useRef(0);
  const fileInput = useRef<HTMLInputElement>(null);

  const conversations = useQuery({
    queryKey: chatKeys.conversations(false),
    queryFn: ({ signal }) => chatRepository.getConversations(false, signal),
  });

  const messages = useQuery({
    queryKey: chatKeys.messages(conversationId),
    queryFn: ({ signal }) => chatRepository.getMessages(conversationId, signal),
    enabled: !!conversationId,
  });

  const conversation = conversations.data?.find((item) => item.id === conversationId);
  const otherName =
    conversation?.otherUser.name ?? conversation?.otherUser.username ?? t('commonUnknownUser');

  // Intrarea în cameră + marcarea ca citit. `join_conversation` întoarce și
  // starea online a celuilalt: fără ea, antetul ar arăta „offline" până la
  // următoarea lui conectare sau deconectare.
  useEffect(() => {
    if (!conversationId) return;
    let cancelled = false;

    void chatSocket
      .joinConversation(conversationId)
      .then((result) => {
        if (!cancelled) setOtherOnline(result.otherUserOnline ?? false);
        return chatSocket.markRead(conversationId);
      })
      .then(() => {
        // Bulina din meniu trebuie să scadă imediat ce am citit, nu la
        // următoarea reîncărcare a listei.
        void queryClient.invalidateQueries({ queryKey: chatKeys.conversations() });
        void queryClient.invalidateQueries({ queryKey: chatKeys.unreadCount() });
      })
      .catch(() => {
        // Fără socket, conversația rămâne perfect utilizabilă: mesajele vin pe
        // HTTP, doar actualizările live lipsesc.
      });

    return () => {
      cancelled = true;
    };
  }, [conversationId, queryClient]);

  // Mesaje noi în timp real.
  useEffect(() => {
    const offNew = chatSocket.on<ChatMessage>('new_message', (message) => {
      if (message.conversationId !== conversationId) return;

      queryClient.setQueryData<ChatMessage[]>(chatKeys.messages(conversationId), (current) => {
        if (!current) return current;
        // Serverul retrimite pe cameră și mesajul propriu. Fără verificarea de
        // id, mesajul trimis de mine apare de două ori: o dată optimist, o dată
        // la ecou.
        if (current.some((existing) => existing.id === message.id)) return current;
        return [...current, message];
      });

      void chatSocket.markRead(conversationId).catch(() => {});
    });

    const offRead = chatSocket.on<{ conversationId: string }>('messages_read', (payload) => {
      if (payload.conversationId !== conversationId) return;
      queryClient.setQueryData<ChatMessage[]>(chatKeys.messages(conversationId), (current) =>
        current?.map((message) => (message.isRead ? message : { ...message, isRead: true })),
      );
    });

    const offPresence = chatSocket.on<{ userId: string; online: boolean }>(
      'user_presence',
      (payload) => {
        if (payload.userId === conversation?.otherUser.id) setOtherOnline(payload.online);
      },
    );

    return () => {
      offNew();
      offRead();
      offPresence();
    };
  }, [conversationId, conversation?.otherUser.id, queryClient]);

  // Indicatorul „scrie…". Se stinge singur după un timp: serverul emite doar
  // începutul tastării, nu și oprirea, deci fără cronometru ar rămâne aprins
  // la nesfârșit dacă celălalt se răzgândește.
  useEffect(() => {
    const off = chatSocket.on<{ conversationId: string; userId: string }>(
      'user_typing',
      (payload) => {
        if (payload.conversationId !== conversationId) return;
        setOtherTyping(true);
      },
    );
    return off;
  }, [conversationId]);

  useEffect(() => {
    if (!otherTyping) return;
    const timer = window.setTimeout(() => setOtherTyping(false), TYPING_TIMEOUT_MS);
    return () => window.clearTimeout(timer);
  }, [otherTyping, messages.data?.length]);

  // Derulare la ultimul mesaj. `behavior: 'auto'` la prima încărcare (nu vrem
  // să vedem toată conversația defilând), animat pentru mesajele care sosesc.
  const messageCount = messages.data?.length ?? 0;
  const firstRender = useRef(true);
  useEffect(() => {
    if (messageCount === 0) return;
    bottomRef.current?.scrollIntoView({ behavior: firstRender.current ? 'auto' : 'smooth' });
    firstRender.current = false;
  }, [messageCount]);

  async function onSend(event: FormEvent) {
    event.preventDefault();
    const content = draft.trim();
    if (!content || sending) return;

    setSending(true);
    // Golim câmpul ÎNAINTE de confirmare: altfel, pe o conexiune lentă, userul
    // apucă să mai tasteze peste textul trimis. La eșec îl punem la loc.
    setDraft('');
    try {
      const message = await chatSocket.emitWithAck<ChatMessage & { error?: string }>(
        'send_message',
        { conversationId, content },
      );
      if (message.error) throw new Error(message.error);

      queryClient.setQueryData<ChatMessage[]>(chatKeys.messages(conversationId), (current) =>
        current && !current.some((existing) => existing.id === message.id)
          ? [...current, message]
          : current,
      );
      void queryClient.invalidateQueries({ queryKey: chatKeys.conversations() });
    } catch {
      setDraft(content);
      toast.show(t('chatSendFailed'), 'danger');
    } finally {
      setSending(false);
    }
  }

  function onDraftChange(value: string) {
    setDraft(value);
    // Throttle: fără el, fiecare tastă ar emite un eveniment pe socket.
    const now = Date.now();
    if (now - lastTypingSent.current > TYPING_THROTTLE_MS) {
      lastTypingSent.current = now;
      chatSocket.typing(conversationId);
    }
  }

  async function onPickPhoto(file: File | undefined) {
    if (!file) return;
    try {
      const message = await chatRepository.sendPhoto(conversationId, file);
      queryClient.setQueryData<ChatMessage[]>(chatKeys.messages(conversationId), (current) => {
        if (!current) return current;
        /*
          Aceeași verificare de id ca la textul trimis, și din același motiv -
          doar că aici lipsea: serverul emite `new_message` pe cameră imediat ce
          a salvat, deci ecoul pe socket ajunge de regulă ÎNAINTEA răspunsului
          HTTP la upload. Fără verificare, aceeași poză intra de două ori în
          listă, iar o singură poză trimisă arăta ca două mesaje.
        */
        if (current.some((existing) => existing.id === message.id)) return current;
        return [...current, message];
      });
    } catch {
      toast.show(t('chatPhotoSendError'), 'danger');
    }
  }

  const grouped = useMemo(() => groupByDay(messages.data ?? [], i18n.language), [
    messages.data,
    i18n.language,
  ]);

  // Antetul conversatiei nu e un titlu text: are avatarul celuilalt si starea
  // lui („online" / „scrie...") - la fel ca `_ConversationTitle` din Flutter.
  const header = (
    <ScreenHeader
      back="/chat"
      title={
        <span className="flex min-w-0 items-center gap-3">
          <Avatar src={conversation?.otherUser.profileImage} name={otherName} size={36} />
          <span className="min-w-0 text-left">
            <span className="block truncate font-semibold">
              {conversation ? otherName : t('chatConversationFallbackTitle')}
            </span>
            <span className="block truncate text-xs font-normal text-muted-foreground">
              {otherTyping ? (
                <span className="text-accent">{t('chatTyping')}</span>
              ) : otherOnline ? (
                <span className="text-success">{t('chatOnline')}</span>
              ) : (
                t('chatOffline')
              )}
            </span>
          </span>
        </span>
      }
    />
  );

  if (messages.isPending) {
    return (
      <>
        {header}
        <div className="flex min-h-[60vh] items-center justify-center text-accent">
          <Spinner size={28} />
        </div>
      </>
    );
  }

  if (messages.isError) {
    return (
      <>
        {header}
        <div className="mx-auto max-w-2xl p-6">
          <ErrorNotice message={t('chatLoadError')} onRetry={() => void messages.refetch()} />
        </div>
      </>
    );
  }

  return (
    // Inaltimea ferestrei MINUS bara de sus: zona de mesaje deruleaza singura,
    // iar campul de scris ramane lipit jos. Pe telefon, `dvh` (nu `vh`) tine
    // cont de bara de adrese care se retrage la scroll - cu `vh`, campul
    // ajungea sub ea.
    <div className="flex h-[calc(100dvh-4rem)] flex-col">
      {header}

      <div className="min-h-0 flex-1 overflow-y-auto px-4 py-4">
        {messageCount === 0 ? (
          <p className="py-16 text-center text-muted-foreground">{t('chatEmptyMessages')}</p>
        ) : (
          <div className="mx-auto flex max-w-[760px] flex-col gap-1">
            {grouped.map(({ day, items }) => (
              <div key={day} className="flex flex-col gap-1">
                <p className="my-4 text-center text-xs text-muted-foreground">{day}</p>
                {items.map((message) => (
                  <MessageBubble
                    key={message.id}
                    message={message}
                    mine={message.senderId === user?.id}
                  />
                ))}
              </div>
            ))}
          </div>
        )}
        <div ref={bottomRef} />
      </div>

      <form
        onSubmit={onSend}
        className="flex shrink-0 items-end gap-2 border-t border-border bg-background px-4 py-3"
      >
        <input
          ref={fileInput}
          type="file"
          accept="image/*"
          hidden
          onChange={(event) => {
            void onPickPhoto(event.target.files?.[0]);
            // Resetăm valoarea: fără asta, alegerea ACELEIAȘI poze a doua oară
            // nu declanșează `change`, deci pare că butonul nu face nimic.
            event.target.value = '';
          }}
        />
        <button
          type="button"
          onClick={() => fileInput.current?.click()}
          aria-label={t('chatAttachPhoto')}
          title={t('chatAttachPhoto')}
          className="shrink-0 rounded-full p-2.5 text-muted-foreground hover:bg-muted hover:text-foreground"
        >
          <ImagePlus size={20} />
        </button>

        <textarea
          value={draft}
          onChange={(event) => onDraftChange(event.target.value)}
          onKeyDown={(event) => {
            // Enter trimite, Shift+Enter face rând nou - convenția de pe web.
            // Pe telefon tastatura are propriul buton de trimitere, iar
            // `event.shiftKey` e mereu false acolo, deci nu se ciocnesc.
            if (event.key === 'Enter' && !event.shiftKey) {
              event.preventDefault();
              void onSend(event);
            }
          }}
          rows={1}
          placeholder={t('chatMessageHint')}
          aria-label={t('chatMessageHint')}
          className="max-h-32 min-h-[48px] w-full resize-none rounded-[16px] bg-muted px-4 py-3.5 text-foreground placeholder:text-muted-foreground focus:outline-none"
        />

        <button
          type="submit"
          disabled={!draft.trim() || sending}
          aria-label={t('commonSubmit')}
          className="shrink-0 rounded-full bg-primary p-3 text-primary-foreground disabled:opacity-50"
        >
          {sending ? <Spinner size={20} /> : <Send size={20} />}
        </button>
      </form>
    </div>
  );
}

/**
 * Poza dintr-un mesaj, cu o stare vizibilă de eșec.
 *
 * `alt=""` plus o bulă fără text însemna că o poză care nu se încarcă (gazdă
 * de stocare inaccesibilă, link expirat) arăta exact ca un mesaj gol - nimic
 * pe ecran în afară de oră. Acum se vede că ACOLO era o fotografie și că ea e
 * problema, nu mesajul.
 */
function MessagePhoto({ url }: { url: string }) {
  const { t } = useTranslation();
  const [failed, setFailed] = useState(false);

  if (failed) {
    return (
      <p className="mb-2 flex items-center gap-1.5 text-sm italic opacity-80">
        <ImageOff size={16} className="shrink-0" />
        {t('chatAttachPhoto')}
      </p>
    );
  }

  return (
    <img
      src={url}
      alt={t('chatAttachPhoto')}
      loading="lazy"
      onError={() => setFailed(true)}
      className="mb-2 max-h-64 rounded-lg object-cover"
    />
  );
}

function MessageBubble({ message, mine }: { message: ChatMessage; mine: boolean }) {
  const { t, i18n } = useTranslation();

  return (
    <div className={cn('flex', mine ? 'justify-end' : 'justify-start')}>
      <div
        className={cn(
          'max-w-[75%] rounded-[16px] px-4 py-2.5',
          mine ? 'bg-primary text-primary-foreground' : 'border border-border bg-card',
        )}
      >
        {message.photo && <MessagePhoto url={message.photo} />}

        {message.content && (
          // `whitespace-pre-wrap`: mesajele scrise cu Shift+Enter au rânduri
          // reale, iar `break-words` taie un URL lung în loc să lățească bula
          // peste ecran.
          <p className="whitespace-pre-wrap break-words">{message.content}</p>
        )}

        <p
          className={cn(
            'mt-1 flex items-center justify-end gap-1 text-[11px]',
            mine ? 'text-primary-foreground/70' : 'text-muted-foreground',
          )}
        >
          {formatTime(message.createdAt, i18n.language)}
          {mine && <span>· {message.isRead ? t('chatSeen') : t('chatSent')}</span>}
        </p>
      </div>
    </div>
  );
}

function groupByDay(messages: ChatMessage[], locale: string) {
  const groups: Array<{ day: string; items: ChatMessage[] }> = [];
  for (const message of messages) {
    const day = formatDay(message.createdAt, locale);
    const last = groups.at(-1);
    if (last?.day === day) last.items.push(message);
    else groups.push({ day, items: [message] });
  }
  return groups;
}
