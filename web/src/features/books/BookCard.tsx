import { useState, type MouseEvent } from 'react';
import { Link } from 'react-router-dom';
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { useTranslation } from 'react-i18next';
import {
  Flame,
  Gavel,
  Heart,
  HeartHandshake,
  Hourglass,
  MapPin,
  Repeat,
  Sparkles,
  Store,
} from 'lucide-react';
import { BookCover } from '@/components/ui/BookCover';
import { listsKeys, wishlistRepository } from '@/features/lists/listsRepository';
import { useAuth } from '@/features/auth/AuthProvider';
import { useGuestGate } from '@/features/auth/GuestGate';
import { useToast } from '@/components/ui/Toast';
import { useListingScore } from './useListingScore';
import { toNumber, type UserBook } from '@/types/models';
import { ApiError } from '@/lib/api/client';
import { cn } from '@/lib/utils/cn';

/**
 * Cardul de carte: copertă cu badge de scor (doar admini), inimă de favorite,
 * indicator de preț sau schimb, plus titlu, autor și localitate dedesubt.
 *
 * Port fidel al shared/widgets/book_card.dart - aceleași poziții (6px de la
 * colțuri), aceleași raze (12 pentru copertă și badge-uri) și aceeași umbră.
 */
export function BookCard({
  item,
  eager = false,
  hideLocation = false,
}: {
  item: UserBook;
  eager?: boolean;
  /** Pe profilul unui user toate cărțile sunt ale lui, iar orașul e deja sus. */
  hideLocation?: boolean;
}) {
  const { t } = useTranslation();
  const { user } = useAuth();

  // Badge-ul de scor e o unealtă de moderare: backendul nu întoarce scoruri
  // pentru non-admini, deci nici nu le cerem.
  const score = useListingScore(item.id, user?.isAdmin === true);

  return (
    <Link to={`/books/${item.id}`} className="group flex flex-col focus:outline-none">
      {/*
        `aspect-[2/3]`, nu 5/7: e raportul folosit de aplicația de telefon, iar
        o diferență de câțiva pixeli se vede imediat când cele două rulează
        una lângă alta.
      */}
      <div
        className="relative aspect-[2/3] overflow-hidden rounded-[12px] bg-muted"
        style={{ boxShadow: '0 6px 12px rgb(0 0 0 / 0.14)' }}
      >
        <BookCover
          // `mainPhotoUrl` ÎNAINTE de coperta din catalog: e poza aleasă
          // explicit de proprietar. Invers, alegerea lui nu s-ar vedea
          // niciodată pe carduri.
          url={item.mainPhotoUrl ?? item.book.coverUrl}
          fallbackUrl={item.photos[0] ?? item.book.coverUrl}
          title={item.book.title}
          eager={eager}
          className="transition duration-300 group-hover:scale-[1.03]"
        />

        {score !== null && (
          <span className="absolute left-1.5 top-1.5 flex items-center gap-1 rounded-[8px] bg-black/75 px-2 py-1">
            <Flame size={13} className="text-[#FFAB40]" />
            <span className="text-xs font-bold text-white">{score.toFixed(1)}</span>
          </span>
        )}

        <WishlistHeart bookId={item.book.id} userBookId={item.id} />

        <PriceBadge item={item} />

        {/* Anunțul rezervat de un schimb acceptat rămâne în listă - marcajul e
            singurul lucru care îl deosebește de unul liber. */}
        {item.isReservedForExchange && (
          <span className="absolute bottom-1.5 left-1.5 flex items-center gap-1 rounded-[8px] bg-foreground/[0.78] px-1.5 py-0.5">
            <Hourglass size={11} className="text-white" />
            <span className="text-[10px] font-semibold text-white">
              {t('listingReservedBadge')}
            </span>
          </span>
        )}
      </div>

      <p className="mt-2 truncate font-display text-[15px] font-bold text-foreground">
        {item.book.title}
      </p>

      {item.book.author && (
        <p className="truncate text-sm text-muted-foreground">{item.book.author}</p>
      )}

      {!hideLocation && (item.user?.city || item.city || item.user?.isStore) && (
        <div className="mt-0.5 flex items-center gap-1 text-sm text-muted-foreground">
          {/* Anunțul unui anticariat arată altfel decât cel al unui om: are
              preț fix, stoc și program - merită spus pe card. */}
          {item.user?.isStore && <Store size={13} className="shrink-0 text-accent" />}
          {(item.user?.city || item.city) && <MapPin size={13} className="shrink-0" />}
          <span className="truncate">
            {item.user?.city ?? item.city ?? t('storeBadge')}
          </span>
        </div>
      )}
    </Link>
  );
}

/**
 * Badge-ul din colțul dreapta-jos: preț sau schimb.
 *
 * Prioritate: licitație > vânzare > „schimb, sau vând cu X" > schimb simplu.
 * Un anunț poate fi mai multe deodată; arătăm cel mai acționabil preț.
 */
function PriceBadge({ item }: { item: UserBook }) {
  const { t } = useTranslation();

  if (item.isAuction && item.auction) {
    return (
      <Badge tone="accent" icon={<Gavel size={13} />}>
        {t('priceLei', { amount: Math.round(toNumber(item.auction.currentPrice) ?? 0) })}
      </Badge>
    );
  }

  if (item.isForSale && item.salePrice !== null) {
    const price = toNumber(item.salePrice) ?? 0;
    const previous = toNumber(item.previousSalePrice);
    // Prețul vechi apare doar dacă a SCĂZUT - unul mai mic decât cel curent
    // ar fi o reducere inversată.
    const reduced = price > 0 && previous !== null && previous > price;

    if (price === 0) {
      return (
        <Badge tone="accent" icon={<HeartHandshake size={13} />}>
          {t('shareListingModeDonation')}
        </Badge>
      );
    }
    return (
      <Badge tone="accent" strikethrough={reduced ? t('priceLei', { amount: Math.round(previous) }) : undefined}>
        {t('priceLei', { amount: Math.round(price) })}
      </Badge>
    );
  }

  // Anunț de SCHIMB pe care proprietarul a bifat „sau vinde cu X lei":
  // `isForSale` rămâne false, dar prețul cerut există și trebuie să se vadă.
  //
  // `> 0`, nu doar „nu e null": backendul stochează 0 pentru anunțurile de
  // schimb la care nu s-a pus niciun preț, iar un badge „0 lei" nu înseamnă
  // nimic pentru cine se uită. Flutter verifică doar `!= null` și afișează
  // „0 lei" în acest caz - aici cădem pe badge-ul simplu de schimb.
  const swapPrice = toNumber(item.swapSalePrice);
  if (swapPrice !== null && swapPrice > 0) {
    return (
      <Badge tone="primary" icon={<Repeat size={13} />}>
        {t('priceLei', { amount: Math.round(swapPrice) })}
      </Badge>
    );
  }

  if (item.availableForSwap) {
    return (
      <Badge tone="primary" icon={<Repeat size={13} />}>
        {t('bookAvailableForSwapShort')}
      </Badge>
    );
  }

  return null;
}

function Badge({
  tone,
  icon,
  strikethrough,
  children,
}: {
  tone: 'accent' | 'primary';
  icon?: React.ReactNode;
  strikethrough?: string;
  children: React.ReactNode;
}) {
  return (
    <span
      className={cn(
        'absolute bottom-1.5 right-1.5 flex items-center gap-1 rounded-[8px] px-2 py-1 text-white',
        tone === 'accent' ? 'bg-accent' : 'bg-primary',
      )}
      style={{ boxShadow: '0 1px 4px rgb(0 0 0 / 0.2)' }}
    >
      {icon}
      {strikethrough && (
        <span className="text-[11px] font-semibold text-white/75 line-through">
          {strikethrough}
        </span>
      )}
      <span className="text-xs font-bold">{children}</span>
    </span>
  );
}

/**
 * Inima de favorite din colțul dreapta-sus.
 *
 * Starea vine din lista de favorite, nu dintr-un bool local: altfel cardul ar
 * porni mereu gol, chiar și pentru cărți deja salvate.
 *
 * Favoritul se leagă de EXEMPLAR (`userBookId`), nu de titlu - inima apăsată
 * pe anunțul unui user nu trebuie să se aprindă și pe celelalte anunțuri ale
 * aceleiași cărți.
 */
function WishlistHeart({ bookId, userBookId }: { bookId: string; userBookId: string }) {
  const { t } = useTranslation();
  const { user } = useAuth();
  const guest = useGuestGate();
  const queryClient = useQueryClient();
  const toast = useToast();
  const [busy, setBusy] = useState(false);

  const wishlist = useQuery({
    queryKey: listsKeys.wishlist(),
    queryFn: ({ signal }) => wishlistRepository.list(signal),
    enabled: !!user,
    // Lista e mică și se citește de pe fiecare card din grilă; o ținem
    // proaspătă câteva minute ca să nu se refacă la fiecare navigare.
    staleTime: 5 * 60 * 1000,
  });

  /**
   * Rândul acestui ANUNȚ bate rândul „de titlu": un favorit pus pe exemplarul
   * altcuiva nu trebuie să aprindă inima aici. Dacă nu există niciun rând
   * legat de exemplar, cădem pe cel de titlu (Book Match, pagina operei).
   */
  const rows = wishlist.data?.filter((row) => row.book.id === bookId) ?? [];
  const entry =
    rows.find((row) => row.userBookId === userBookId) ??
    rows.find((row) => !row.userBookId);
  const saved = !!entry;
  const fromMatch = entry?.source === 'BOOK_MATCH';

  const toggle = useMutation<void, Error, void>({
    // `void` explicit pe rezultat: `add` intoarce randul creat, `remove` nu
    // intoarce nimic, iar uniunea celor doua nu e un MutationFunction valid.
    // Rezultatul nu ne intereseaza oricum - starea vine din reincarcarea listei.
    mutationFn: async () => {
      if (saved) await wishlistRepository.remove(bookId);
      else await wishlistRepository.add(bookId, userBookId);
    },
    onSuccess: () => queryClient.invalidateQueries({ queryKey: listsKeys.wishlist() }),
    onError: (error) => {
      // Cazul real: limita gratuită de cărți urmărite - backendul întoarce un
      // mesaj clar (403). Înghițit, inima doar revenea la gol, fără explicație.
      toast.show(
        error instanceof ApiError ? error.message : t('bookDetailWishlistError'),
        'danger',
      );
    },
  });

  function onClick(event: MouseEvent) {
    // Cardul întreg e un link; fără asta, clicul pe inimă deschide și cartea.
    event.preventDefault();
    event.stopPropagation();
    if (busy) return;
    setBusy(true);
    toggle.mutate(undefined, { onSettled: () => setBusy(false) });
  }

  /*
    Vizitatorul vede inima, dar apăsarea ei cere un cont: ascunsă, cardul ar
    arăta altfel înainte și după înregistrare, iar omul n-ar afla niciodată că
    poate urmări o carte.
  */
  if (guest.isGuest) {
    return (
      <button
        onClick={guest.block}
        aria-label={t('workWantToRead')}
        className="absolute right-1.5 top-1.5 flex size-[30px] items-center justify-center rounded-full bg-white/90 transition"
        style={{ boxShadow: '0 0 4px rgb(0 0 0 / 0.15)' }}
      >
        <Heart size={17} className="text-muted-foreground" />
      </button>
    );
  }

  if (!user) return null;

  const Icon = saved && fromMatch ? Sparkles : Heart;

  return (
    <button
      onClick={onClick}
      disabled={busy}
      aria-label={t(saved ? 'commonDelete' : 'workWantToRead')}
      aria-pressed={saved}
      className="absolute right-1.5 top-1.5 flex size-[30px] items-center justify-center rounded-full bg-white/90 transition disabled:opacity-60"
      style={{ boxShadow: '0 0 4px rgb(0 0 0 / 0.15)' }}
    >
      <Icon
        size={17}
        className={cn(
          saved && fromMatch && 'fill-primary text-primary',
          saved && !fromMatch && 'fill-destructive text-destructive',
          !saved && 'text-muted-foreground',
        )}
      />
    </button>
  );
}
