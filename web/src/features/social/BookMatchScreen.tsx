import { useRef, useState } from 'react';
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { useTranslation } from 'react-i18next';
import { HeaderAction, ScreenHeader } from '@/components/layout/ScreenHeader';
import { Heart, SkipForward, SlidersHorizontal, X } from 'lucide-react';
import { bookMatchRepository, socialKeys } from './socialRepository';
import { listsKeys } from '@/features/lists/listsRepository';
import { BookCover } from '@/components/ui/BookCover';
import { Button, ErrorNotice, Spinner } from '@/components/ui';
import { useToast } from '@/components/ui/Toast';
import { useCompleteOnboardingTodo } from '@/features/home/onboardingTodo';

/**
 * Book Match: un teanc de cărți pe care userul le acceptă sau le respinge.
 * Un „da" adaugă cartea în lista de dorințe (sursa BOOK_MATCH).
 */
export function BookMatchScreen() {
  const { t } = useTranslation();
  const queryClient = useQueryClient();
  const toast = useToast();
  const completeTodo = useCompleteOnboardingTodo();

  /**
   * Sesiunea se generează O SINGURĂ dată, la montarea ecranului, și se trimite
   * atât la cerere, cât și la fiecare swipe: backendul leagă teancul servit de
   * acest id, iar fără el nu poate corela răspunsurile cu ce a trimis. Un id
   * nou la fiecare randare ar cere de fiecare dată alt teanc.
   */
  const sessionId = useRef(crypto.randomUUID());

  // Indexul cardului curent e local, nu recitit de la server după fiecare
  // swipe: altfel fiecare decizie ar costa o cerere de listă în plus, iar
  // teancul ar clipi la fiecare card.
  const [index, setIndex] = useState(0);

  const queue = useQuery({
    queryKey: socialKeys.bookMatchQueue(),
    queryFn: ({ signal }) => bookMatchRepository.queue(sessionId.current, 20, signal),
  });

  const status = useQuery({
    queryKey: socialKeys.bookMatchStatus(),
    queryFn: ({ signal }) => bookMatchRepository.status(signal),
  });

  const swipe = useMutation({
    mutationFn: (input: { bookId: string; action: 'YES' | 'NO' | 'SKIP'; isDiscovery: boolean }) =>
      bookMatchRepository.swipe({ ...input, sessionId: sessionId.current }),
    onSuccess: (result) => {
      // Invalidăm lista de dorințe doar dacă backendul CHIAR a adăugat ceva.
      // Un „da" pe o carte deja în listă nu schimbă nimic, iar o invalidare
      // inutilă reîncarcă ecranul de wishlist degeaba.
      if (result.addedToWishlist) {
        void queryClient.invalidateQueries({ queryKey: listsKeys.wishlist() });
      }
    },
    onError: () => toast.show(t('commonGenericError'), 'danger'),
  });

  const recalibrate = useMutation({
    mutationFn: () => bookMatchRepository.recalibrate(),
    onSuccess: () => {
      // Sesiune nouă: teancul recalibrat e altul, iar swipe-urile care urmează
      // nu mai au ce căuta în sesiunea veche.
      sessionId.current = crypto.randomUUID();
      void queryClient.invalidateQueries({ queryKey: socialKeys.bookMatchQueue() });
      void queryClient.invalidateQueries({ queryKey: socialKeys.bookMatchStatus() });
      setIndex(0);
      toast.show(t('bookMatchRecalibrateDone'));
    },
    onError: () => toast.show(t('bookMatchRecalibrateError'), 'danger'),
  });

  const header = (
    <ScreenHeader
      title={t('bookMatchTitle')}
      back
      actions={
        <HeaderAction
          label={t('bookMatchRecalibrateTooltip')}
          disabled={!status.data?.canRecalibrate || recalibrate.isPending}
          onClick={() => {
            if (window.confirm(t('bookMatchRecalibrateConfirm'))) recalibrate.mutate();
          }}
        >
          <SlidersHorizontal size={22} />
        </HeaderAction>
      }
    />
  );

  if (queue.isPending) {
    return (
      <div className="flex min-h-dvh items-center justify-center text-accent">
        {header}
        <Spinner size={28} />
      </div>
    );
  }

  if (queue.isError) {
    return (
      <div className="mx-auto max-w-2xl p-6">
        {header}
        <ErrorNotice message={t('bookMatchLoadError')} onRetry={() => void queue.refetch()} />
      </div>
    );
  }

  const cards = queue.data.cards;
  const card = cards[index];

  function decide(action: 'YES' | 'NO' | 'SKIP') {
    // „Încearcă Book Match" din lista „Descoperă ShelfShare" e făcut din clipa
    // în care omul chiar a dat un swipe - nu doar a deschis ecranul și a ieșit.
    completeTodo('bookMatch');
    if (!card) return;
    swipe.mutate({ bookId: card.bookId, action, isDiscovery: card.isDiscovery });
    setIndex((current) => current + 1);
  }

  return (
    <div className="mx-auto flex w-full max-w-[440px] flex-col px-5 pb-16 pt-2 min-[900px]:px-8">
      {header}
      {!card ? (
        <div className="flex flex-col items-center gap-3 py-16 text-center">
          <p className="font-display text-lg font-bold">{t('bookMatchEmptyTitle')}</p>
          <p className="text-muted-foreground">{t('bookMatchEmptyBody')}</p>
          <Button
            variant="outline"
            onClick={() => {
              // Teanc nou = sesiune nouă, din același motiv ca la recalibrare.
              sessionId.current = crypto.randomUUID();
              setIndex(0);
              void queue.refetch();
            }}
          >
            {t('commonRetry')}
          </Button>
        </div>
      ) : (
        <>
          <article className="overflow-hidden rounded-[16px] border border-border bg-card">
            <div className="relative aspect-[5/7] bg-muted">
              <BookCover url={card.coverUrl} title={card.title} eager />
              {card.isDiscovery && (
                <span className="absolute left-2 top-2 rounded-full bg-accent px-2.5 py-1 text-[11px] font-bold text-accent-foreground">
                  {t('bookMatchDiscoveryBadge')}
                </span>
              )}
            </div>

            <div className="p-4">
              <h2 className="font-display text-lg font-bold leading-tight">{card.title}</h2>
              {card.author && <p className="mt-1 text-muted-foreground">{card.author}</p>}
              {card.description && (
                <p className="mt-3 line-clamp-4 text-sm text-muted-foreground">
                  {card.description}
                </p>
              )}
            </div>
          </article>

          <p className="mt-4 text-center text-sm text-muted-foreground">{t('bookMatchHint')}</p>

          <div className="mt-4 flex items-center justify-center gap-4">
            <ActionButton
              onClick={() => decide('NO')}
              label={t('bookMatchNoLabel')}
              tone="border-destructive text-destructive"
            >
              <X size={26} />
            </ActionButton>

            <ActionButton
              onClick={() => decide('SKIP')}
              label={t('bookMatchSkip')}
              tone="border-border text-muted-foreground"
            >
              <SkipForward size={20} />
            </ActionButton>

            <ActionButton
              onClick={() => decide('YES')}
              label={t('bookMatchYesLabel')}
              tone="border-success text-success"
            >
              <Heart size={26} />
            </ActionButton>
          </div>

          <p className="mt-4 text-center text-xs text-muted-foreground">
            {index + 1} / {cards.length}
          </p>
        </>
      )}
    </div>
  );
}

function ActionButton({
  onClick,
  label,
  tone,
  children,
}: {
  onClick: () => void;
  label: string;
  tone: string;
  children: React.ReactNode;
}) {
  return (
    <button
      onClick={onClick}
      aria-label={label}
      title={label}
      className={`flex size-14 items-center justify-center rounded-full border-2 bg-card transition hover:scale-105 ${tone}`}
    >
      {children}
    </button>
  );
}
