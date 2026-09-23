import { useState } from 'react';
import { useQuery } from '@tanstack/react-query';
import { Link, useParams } from 'react-router-dom';
import { useTranslation } from 'react-i18next';
import { HeaderAction, ScreenHeader } from '@/components/layout/ScreenHeader';
import { useToast } from '@/components/ui/Toast';
import { shareAppLink } from '@/lib/utils/shareLink';
import { Eye, MapPin, Share2 } from 'lucide-react';
import { booksKeys, booksRepository } from './booksRepository';
import { BookCard } from './BookCard';
import { MakeOfferSheet, RequestExchangeSheet } from './BookActionSheets';
import { BookGrid } from './BookGrid';
import { BookCover } from '@/components/ui/BookCover';
import { Button, ErrorNotice, Spinner } from '@/components/ui';
import { useAuth } from '@/features/auth/AuthProvider';
import { SellerName, useGuestGate } from '@/features/auth/GuestGate';
import { useDocumentMeta } from '@/lib/seo/useDocumentMeta';
import { SITE_NAME, type DocumentMeta } from '@/lib/seo/routes';
import i18n from '@/lib/i18n';
import { toNumber, type BookCondition, type PublicUser, type UserBook } from '@/types/models';

/**
 * Metadatele paginii unui anunț.
 *
 * Aceeași formă o produce și scripts/beta-server.js pentru HTML-ul livrat
 * înainte de pornirea aplicației (vezi `fetchBookMeta` acolo) - ce vede
 * crawlerul și ce vede omul trebuie să coincidă.
 *
 * `offers` din JSON-LD apare DOAR când cartea chiar e de vânzare: `salePrice`
 * poate rămâne setat pe un anunț doar-de-schimb (câmpul nu se golește când
 * proprietarul oprește vânzarea), iar un preț declarat pe o carte care nu se
 * vinde ar fi un rezultat fals în Google.
 */
/**
 * Cine vinde cartea.
 *
 * Pentru vizitatorul fără cont numele e estompat, iar cardul nu mai duce la
 * profil, ci deschide dialogul de cont: cine are cartea e exact lucrul pentru
 * care merită să-ți faci cont, iar dat pe gratis n-ar mai rămâne niciun motiv.
 *
 * Rândul rămâne ÎN ACELAȘI LOC și cu aceeași formă ca pentru userul logat -
 * scos cu totul, pagina ar arăta altfel înainte și după înregistrare.
 */
function SellerCard({ user }: { user: PublicUser }) {
  const guest = useGuestGate();
  const name = user.name ?? user.username ?? '?';

  const inner = (
    <>
      <div className="flex size-10 shrink-0 items-center justify-center overflow-hidden rounded-full bg-muted font-bold">
        {user.profileImage ? (
          <img src={user.profileImage} alt="" className="size-full object-cover" />
        ) : (
          // Fără cont, până și inițiala e un indiciu; punem semnul de întrebare.
          (guest.isGuest ? '?' : name).charAt(0).toUpperCase()
        )}
      </div>
      <div className="min-w-0">
        <SellerName name={name} className="block font-medium" />
        {user.city && <p className="truncate text-sm text-muted-foreground">{user.city}</p>}
      </div>
    </>
  );

  const className =
    'mt-6 flex w-full items-center gap-3 rounded-[16px] border border-border bg-card p-3 text-left hover:bg-muted';

  if (guest.isGuest) {
    return (
      <button type="button" onClick={guest.open} className={className}>
        {inner}
      </button>
    );
  }

  return (
    <Link to={`/users/${user.id}`} className={className}>
      {inner}
    </Link>
  );
}

function bookDocumentMeta(item: UserBook, userBookId: string): DocumentMeta {
  const price = toNumber(item.salePrice);
  const forSale = item.isForSale && price !== null && price > 0;
  const cover = item.mainPhotoUrl ?? item.book.coverUrl ?? undefined;
  /*
    Instanța i18next direct: funcția asta nu e o componentă, dar ce produce
    ajunge în `<head>` - titlul din tab și cardul de la „distribuie". Netradus,
    un vizitator pe engleză ar primi pagina în engleză și titlul în română.
    Formulările rămân în oglindă cu STRINGS din scripts/beta-seo.js, care
    pre-randează aceleași pagini pentru crawlere.
  */
  const byline = item.book.author
    ? i18n.t('seoBookByline', { title: item.book.title, author: item.book.author })
    : item.book.title;
  const city = item.city ? i18n.t('seoInCity', { city: item.city }) : '';

  return {
    title: `${byline} | ${SITE_NAME}`,
    description:
      item.description?.slice(0, 200) ||
      item.book.description?.slice(0, 200) ||
      i18n.t(forSale ? 'seoBookForSale' : 'seoBookAvailable', { byline, city, price }),
    path: `/books/${userBookId}`,
    image: cover,
    jsonLd: {
      '@context': 'https://schema.org',
      '@type': 'Book',
      name: item.book.title,
      ...(item.book.author ? { author: { '@type': 'Person', name: item.book.author } } : {}),
      ...(item.book.isbn ? { isbn: item.book.isbn } : {}),
      ...(cover ? { image: cover } : {}),
      ...(item.book.publishedYear ? { datePublished: String(item.book.publishedYear) } : {}),
      ...(item.book.pageCount ? { numberOfPages: item.book.pageCount } : {}),
      ...(forSale
        ? {
            offers: {
              '@type': 'Offer',
              price,
              priceCurrency: 'RON',
              itemCondition: 'https://schema.org/UsedCondition',
              availability: 'https://schema.org/InStock',
            },
          }
        : {}),
    },
  };
}

/**
 * Detaliul unui anunț. Port al zonei de prezentare din book_detail_screen.dart
 * (2285 de linii acolo, fiindcă include și acțiunile: ofertă de preț, cerere de
 * schimb, licitație, editare, raportare). Aici e portată partea de citire;
 * acțiunile vin în lotul de schimburi/oferte, unde există și ecranele-pereche.
 */
export function BookDetailScreen() {
  const { userBookId = '' } = useParams();
  const { t } = useTranslation();
  const guest = useGuestGate();
  const toast = useToast();
  const { user } = useAuth();
  const [sheet, setSheet] = useState<'exchange' | 'offer' | null>(null);

  const book = useQuery({
    queryKey: booksKeys.detail(userBookId),
    queryFn: ({ signal }) => booksRepository.getById(userBookId, signal),
    enabled: !!userBookId,
  });

  const similar = useQuery({
    queryKey: booksKeys.similar(userBookId),
    queryFn: ({ signal }) => booksRepository.getSimilar(userBookId, signal),
    // Doar după ce anunțul principal s-a încărcat: pe un id greșit ar fi două
    // cereri eșuate în loc de una.
    enabled: book.isSuccess,
  });

  useDocumentMeta(book.data ? bookDocumentMeta(book.data, userBookId) : null);

  const header = (
    <ScreenHeader
      title={t('bookDetailTitle')}
      back
      actions={
        <HeaderAction
          label={t('profileCopyLink')}
          onClick={() => void shareAppLink(`/books/${userBookId}`, toast.show)}
        >
          <Share2 size={22} />
        </HeaderAction>
      }
    />
  );

  if (book.isPending) {
    return (
      <>
        {header}
        <div className="flex min-h-[60vh] items-center justify-center text-accent">
          <Spinner size={28} />
        </div>
      </>
    );
  }

  if (book.isError) {
    return (
      <>
        {header}
        <div className="mx-auto max-w-2xl p-6">
          <ErrorNotice message={t('homeLoadError')} onRetry={() => void book.refetch()} />
        </div>
      </>
    );
  }

  const item = book.data;
  const price = toNumber(item.salePrice);
  const previousPrice = toNumber(item.previousSalePrice);

  return (
    <div className="mx-auto w-full max-w-[1000px] px-5 pb-16 pt-4 min-[900px]:px-8">
      {header}

      <div className="flex flex-col gap-8 min-[700px]:flex-row">
        <div className="w-full shrink-0 min-[700px]:w-[260px]">
          <div className="aspect-[5/7] overflow-hidden rounded-[16px] border border-border bg-muted">
            <BookCover
              url={item.book.coverUrl}
              fallbackUrl={item.mainPhotoUrl}
              title={item.book.title}
              eager
            />
          </div>

          {/* Pozele reale ale exemplarului, dacă proprietarul a urcat. Sunt
              altceva decât coperta din catalog: arată starea cărții. */}
          {item.photos.length > 0 && (
            <div className="mt-3 flex gap-2 overflow-x-auto">
              {item.photos.map((photo) => (
                <img
                  key={photo}
                  src={photo}
                  alt=""
                  loading="lazy"
                  className="size-16 shrink-0 rounded-lg border border-border object-cover"
                />
              ))}
            </div>
          )}
        </div>

        <div className="min-w-0 flex-1">
          <h1 className="font-display text-2xl font-bold leading-tight">{item.book.title}</h1>
          {item.book.author && (
            <p className="mt-1 text-muted-foreground">{item.book.author}</p>
          )}

          <div className="mt-4 flex flex-wrap items-baseline gap-3">
            {price !== null && (
              <span className="font-display text-3xl font-bold text-accent">
                {formatPrice(price)}
              </span>
            )}
            {/* Prețul vechi apare doar dacă a scăzut - un „preț vechi" mai mic
                decât cel curent ar fi o reducere inversată. */}
            {previousPrice !== null && price !== null && previousPrice > price && (
              <span className="text-muted-foreground line-through">
                {formatPrice(previousPrice)}
              </span>
            )}
            {item.isNegotiable && (
              <span className="text-sm text-muted-foreground">
                {t('bookDetailNegotiableChip')}
              </span>
            )}
          </div>

          <div className="mt-4 flex flex-wrap gap-2">
            {item.availableForSwap && (
              <Tag className="text-success">{t('bookAvailableForSwapShort')}</Tag>
            )}
            {item.isForSale && <Tag>{t('csvHeaderForSale')}</Tag>}
            {item.isAuction && <Tag className="text-warning">{t('addBookAuctionSwitch')}</Tag>}
            {item.isReservedForExchange && (
              <Tag className="text-warning">{t('listingReservedBadge')}</Tag>
            )}
            {/*
              `CONDITION_KEYS[...]` poate fi undefined dacă backendul adaugă o
              valoare nouă în enum înainte ca frontendul să fie actualizat.
              Fără verificarea asta se randa o pastilă complet goală - exact ce
              s-a văzut la prima rulare, când maparea avea valori englezești
              inexistente.
            */}
            {item.condition && CONDITION_KEYS[item.condition] && (
              <Tag>{t(CONDITION_KEYS[item.condition])}</Tag>
            )}
            {item.isHardcover && <Tag>{t('bookDetailHardcoverChip')}</Tag>}
          </div>

          {item.description && (
            <p className="mt-6 whitespace-pre-line leading-relaxed">{item.description}</p>
          )}

          {item.book.description && !item.description && (
            <p className="mt-6 whitespace-pre-line leading-relaxed text-muted-foreground">
              {item.book.description}
            </p>
          )}

          <dl className="mt-6 grid grid-cols-2 gap-x-6 gap-y-3 text-sm">
            <Detail label={t('bookDetailPublisherLabel')} value={item.book.publisher} />
            <Detail label={t('bookDetailYearLabel')} value={item.book.publishedYear} />
            <Detail label={t('bookDetailPagesLabel')} value={item.book.pageCount} />
            <Detail label="ISBN" value={item.book.isbn} />
            <Detail label={t('profileLanguage')} value={item.language ?? item.book.language} />
            <Detail label={t('shareEditionYear')} value={item.edition} />
          </dl>

          <div className="mt-6 flex flex-wrap items-center gap-4 text-sm text-muted-foreground">
            {item.city && (
              <span className="flex items-center gap-1">
                <MapPin size={14} />
                {item.city}
                {item.distanceKm != null && ` · ${Math.round(item.distanceKm)} km`}
              </span>
            )}
            <span className="flex items-center gap-1">
              <Eye size={14} />
              {item.viewCount}
            </span>
          </div>

          {item.user && <SellerCard user={item.user} />}

          {/* Vizitatorul fără cont vede anunțul, dar ca să ceară cartea are
              nevoie de un cont - butoanele ar duce la un 401. Dialogul apare
              PESTE pagină, cu fundalul estompat, în loc să-l mute pe om pe
              ecranul de autentificare: așa nu pierde cartea la care se uita. */}
          {guest.isGuest && (
            <div className="mt-8">
              <Button onClick={guest.open}>{t('bookDetailRequestExchange')}</Button>
            </div>
          )}

          {/* Pe propriul anunț n-au ce căuta: backendul refuză oricum o cerere
              către tine însuți, iar butoanele ar promite ceva imposibil. */}
          {user && item.user && item.user.id !== user.id && (
            <div className="mt-8 flex flex-wrap gap-3">
              {item.availableForSwap && (
                <Button onClick={() => setSheet('exchange')}>
                  {t('bookDetailRequestExchange')}
                </Button>
              )}
              {(item.isForSale || toNumber(item.swapSalePrice) !== null) && (
                <Button variant="outline" onClick={() => setSheet('offer')}>
                  {t('bookDetailMakeOffer')}
                </Button>
              )}
            </div>
          )}
        </div>
      </div>

      {sheet === 'exchange' && (
        <RequestExchangeSheet book={item} onClose={() => setSheet(null)} />
      )}
      {sheet === 'offer' && <MakeOfferSheet book={item} onClose={() => setSheet(null)} />}

      {similar.data && similar.data.length > 0 && (
        <section className="mt-12">
          <h2 className="mb-4 font-display text-lg font-bold">{t('bookDetailSimilarBooksTitle')}</h2>
          <BookGrid>
            {similar.data.slice(0, 5).map((similarItem: UserBook) => (
              <BookCard key={similarItem.id} item={similarItem} />
            ))}
          </BookGrid>
        </section>
      )}
    </div>
  );
}

/**
 * Enumul `BookCondition` din schema Prisma e în ROMÂNĂ (NOUA, FOARTE_BUNA,
 * BUNA, ACCEPTABILA) - nu are variante englezești. Aici stă doar maparea spre
 * cheia de traducere; textul afișat vine din .arb, ca pe toate cele 4 limbi.
 */
const CONDITION_KEYS: Record<BookCondition, string> = {
  NOUA: 'bookConditionNew',
  FOARTE_BUNA: 'bookConditionVeryGood',
  BUNA: 'bookConditionGood',
  ACCEPTABILA: 'bookConditionAcceptable',
};

function formatPrice(value: number): string {
  return new Intl.NumberFormat('ro-RO', {
    style: 'currency',
    currency: 'RON',
    maximumFractionDigits: 0,
  }).format(value);
}

function Tag({ children, className }: { children: React.ReactNode; className?: string }) {
  return (
    <span
      className={`rounded-full border border-border px-3 py-1 text-xs font-medium ${className ?? ''}`}
    >
      {children}
    </span>
  );
}

function Detail({ label, value }: { label: string; value: string | number | null | undefined }) {
  if (value === null || value === undefined || value === '') return null;
  return (
    <div>
      <dt className="text-muted-foreground">{label}</dt>
      <dd className="font-medium">{value}</dd>
    </div>
  );
}
