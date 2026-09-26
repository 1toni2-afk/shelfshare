import { useState, type ReactNode } from 'react';
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { useNavigate } from 'react-router-dom';
import { useTranslation } from 'react-i18next';
import { api, ApiError } from '@/lib/api/client';
import { booksKeys, booksRepository } from './booksRepository';
import { exchangeKeys, exchangesRepository } from '@/features/exchanges/exchangesRepository';
import { Button, Field, Spinner } from '@/components/ui';
import { useToast } from '@/components/ui/Toast';
import { toNumber, type UserBook } from '@/types/models';

/**
 * Câte cărți în plus pot intra într-un pachet. Trebuie să oglindească
 * MAX_BUNDLE_BOOKS din backend/src/exchanges/dto/create-exchange-request.dto.ts.
 */
const MAX_ADDITIONAL_BOOKS = 5;

/**
 * „Propune un schimb". Port al `_RequestExchangeSheet` din book_detail_screen.dart.
 *
 * Cererea e postată direct ca mesaj în chat, deci după trimitere ducem userul
 * acolo: vede cardul imediat, nu doar un toast.
 */
export function RequestExchangeSheet({
  book,
  initialOfferedBookId = null,
  onClose,
}: {
  /** Doar id-ul anunțului și titlul: din Potriviri nu avem un UserBook întreg. */
  book: Pick<UserBook, 'id'> & { book: Pick<UserBook['book'], 'title'> };
  /** Precompletat din Potriviri, unde știm deja ce carte a ta vrea celălalt. */
  initialOfferedBookId?: string | null;
  onClose: () => void;
}) {
  const { t } = useTranslation();
  const navigate = useNavigate();
  const toast = useToast();
  const queryClient = useQueryClient();

  const [offeredBookId, setOfferedBookId] = useState<string | null>(initialOfferedBookId);
  const [additional, setAdditional] = useState<string[]>([]);
  const [message, setMessage] = useState('');

  const library = useQuery({
    queryKey: booksKeys.myLibrary(),
    queryFn: ({ signal }) => booksRepository.getMyLibrary(signal),
    // Doar ce e chiar la schimb: restul n-ar fi acceptat de celălalt oricum.
    select: (books) => books.filter((item) => item.availableForSwap),
  });

  const sent = useQuery({
    queryKey: exchangeKeys.sent(),
    queryFn: ({ signal }) => exchangesRepository.sent(signal),
  });

  const submit = useMutation({
    mutationFn: () =>
      api.post<{ id: string; conversationId?: string | null }>('/exchanges', {
        requestedBookId: book.id,
        ...(offeredBookId ? { offeredBookId } : {}),
        ...(additional.length > 0 ? { additionalOfferedBookIds: additional } : {}),
        ...(message.trim() ? { message: message.trim() } : {}),
      }),
    onSuccess: (created) => {
      void queryClient.invalidateQueries({ queryKey: exchangeKeys.all });
      onClose();
      toast.show(t('bookDetailRequestSent'));
      if (created.conversationId) void navigate(`/chat/${created.conversationId}`);
    },
    onError: (cause) => toast.show(messageOf(cause) ?? t('bookDetailRequestError'), 'danger'),
  });

  function send() {
    // Dacă n-a mai trimis nicio cerere, un memento de siguranță o singură dată.
    if (sent.isSuccess && sent.data.length === 0) {
      if (!window.confirm(`${t('bookDetailFirstExchangeTitle')}\n\n${t('bookDetailFirstExchangeBody')}`)) {
        return;
      }
    }
    submit.mutate();
  }

  const mine = library.data ?? [];
  const others = mine.filter((item) => item.id !== offeredBookId);

  return (
    <Sheet title={t('bookDetailRequestedTitle', { title: book.book.title })} onClose={onClose}>
      {library.isPending ? (
        <div className="flex justify-center py-4 text-accent">
          <Spinner size={24} />
        </div>
      ) : mine.length === 0 ? (
        <p className="mb-4 text-sm text-muted-foreground">{t('bookDetailNoBooksToOffer')}</p>
      ) : (
        <label className="mb-4 flex flex-col gap-1.5">
          <span className="text-sm font-medium text-muted-foreground">
            {t('bookDetailOfferOneOfYourBooks')}
          </span>
          <select
            value={offeredBookId ?? ''}
            onChange={(event) => {
              setOfferedBookId(event.target.value || null);
              // Pachetul se leagă de cartea principală: dacă aceea se schimbă,
              // restul selecției nu mai are sens.
              setAdditional([]);
            }}
            className="w-full rounded-[16px] bg-muted px-4 py-3.5 text-foreground focus:outline-none"
          >
            <option value="">{t('bookDetailNoOffer')}</option>
            {mine.map((item) => (
              <option key={item.id} value={item.id}>
                {item.book.title}
              </option>
            ))}
          </select>
        </label>
      )}

      {offeredBookId && others.length > 0 && (
        <div className="mb-4">
          <p className="mb-1 text-sm text-muted-foreground">{t('bookDetailBundleAddMore')}</p>
          {others.map((item) => (
            <label key={item.id} className="flex cursor-pointer items-center gap-3 py-1.5 text-sm">
              <input
                type="checkbox"
                checked={additional.includes(item.id)}
                onChange={(event) =>
                  setAdditional((current) =>
                    event.target.checked
                      ? current.length < MAX_ADDITIONAL_BOOKS
                        ? [...current, item.id]
                        : current
                      : current.filter((id) => id !== item.id),
                  )
                }
                className="size-4 accent-[var(--ss-accent)]"
              />
              <span className="min-w-0 truncate">{item.book.title}</span>
            </label>
          ))}
        </div>
      )}

      <label className="mb-5 flex flex-col gap-1.5">
        <span className="text-sm font-medium text-muted-foreground">
          {t('bookDetailMessageOptional')}
        </span>
        <textarea
          rows={3}
          value={message}
          onChange={(event) => setMessage(event.target.value)}
          className="w-full resize-y rounded-[16px] bg-muted px-4 py-3.5 text-foreground focus:outline-none"
        />
      </label>

      <Button fullWidth onClick={send} loading={submit.isPending}>
        {t('bookDetailSendRequest')}
      </Button>
    </Sheet>
  );
}

/**
 * „Fă o ofertă". Port al `_MakeOfferSheet`. Suma pornește de la prețul cerut,
 * fie cel de vânzare, fie cel din „sau vinde cu X lei" de pe un anunț de schimb.
 */
export function MakeOfferSheet({ book, onClose }: { book: UserBook; onClose: () => void }) {
  const { t } = useTranslation();
  const navigate = useNavigate();
  const toast = useToast();
  const queryClient = useQueryClient();

  const asking = toNumber(book.salePrice) ?? toNumber(book.swapSalePrice);
  const [amount, setAmount] = useState(asking ? asking.toFixed(0) : '');
  const [message, setMessage] = useState('');

  const submit = useMutation({
    mutationFn: (value: number) =>
      api.post<{ id: string; conversationId?: string | null }>(`/books/${book.id}/offers`, {
        amount: value,
        ...(message.trim() ? { message: message.trim() } : {}),
      }),
    onSuccess: (created) => {
      void queryClient.invalidateQueries({ queryKey: exchangeKeys.offersSent() });
      onClose();
      toast.show(t('bookDetailOfferSent'));
      if (created.conversationId) void navigate(`/chat/${created.conversationId}`);
    },
    onError: (cause) => toast.show(messageOf(cause) ?? t('bookDetailOfferError'), 'danger'),
  });

  function send() {
    // Virgula zecimală e ce tastează un român; `Number` n-o acceptă.
    const value = Number(amount.trim().replace(',', '.'));
    if (!Number.isFinite(value) || value <= 0) {
      toast.show(t('bookDetailInvalidAmount'), 'danger');
      return;
    }
    submit.mutate(value);
  }

  return (
    <Sheet title={t('bookDetailMakeOfferTitle', { title: book.book.title })} onClose={onClose}>
      {asking !== null && (
        <p className="-mt-3 mb-4 text-sm text-muted-foreground">
          {t('bookDetailAskingPrice', { price: t('priceLei', { amount: asking }) })}
        </p>
      )}

      <div className="mb-4 flex items-center gap-2 rounded-[16px] bg-muted px-4">
        <input
          value={amount}
          onChange={(event) => setAmount(event.target.value)}
          inputMode="decimal"
          placeholder={t('bookDetailOfferAmountLabel')}
          aria-label={t('bookDetailOfferAmountLabel')}
          className="w-full bg-transparent py-3.5 text-foreground placeholder:text-muted-foreground focus:outline-none"
        />
        <span className="shrink-0 text-muted-foreground">lei</span>
      </div>

      <Field
        label={t('bookDetailMessageOptional')}
        name="offer-message"
        value={message}
        maxLength={50}
        onChange={(event) => setMessage(event.target.value)}
      />

      <Button className="mt-5" fullWidth onClick={send} loading={submit.isPending}>
        {t('bookDetailSendOffer')}
      </Button>
    </Sheet>
  );
}

/** Foaia glisantă de jos, ca `showModalBottomSheet` din Flutter. */
function Sheet({
  title,
  children,
  onClose,
}: {
  title: string;
  children: ReactNode;
  onClose: () => void;
}) {
  const { t } = useTranslation();

  return (
    <div className="fixed inset-0 z-50 flex items-end justify-center min-[560px]:items-center">
      <button
        aria-label={t('commonCancel')}
        onClick={onClose}
        className="absolute inset-0 bg-black/50"
      />
      <div className="relative max-h-[85dvh] w-full max-w-[480px] overflow-y-auto rounded-t-[20px] bg-card p-6 min-[560px]:rounded-[20px]">
        <h2 className="mb-5 font-display text-xl font-bold">{title}</h2>
        {children}
      </div>
    </div>
  );
}

/**
 * Mesajul serverului e mai util decât unul generic: „ai deja o cerere pentru
 * cartea asta", „anunțul e rezervat" etc.
 */
function messageOf(cause: unknown): string | null {
  const data = cause instanceof ApiError ? (cause.data as { message?: unknown } | null) : null;
  const message = data?.message;
  if (Array.isArray(message)) return message.join(', ');
  if (typeof message === 'string' && message.trim()) return message;
  return null;
}
