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
import { useDocumentMeta } from '@/lib/seo/useDocumentMeta';
import { bookTitle, type DocumentMeta } from '@/lib/seo/routes';
import { toNumber, type BookCondition, type UserBook } from '@/types/models';

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
function bookDocumentMeta(item: UserBook, userBookId: string): DocumentMeta {
  const price = toNumber(item.salePrice);
  const forSale = item.isForSale && price !== null && price > 0;
  const cover = item.mainPhotoUrl ?? item.book.coverUrl ?? undefined;
  const byline = item.book.author ? `${item.book.title} de ${item.book.author}` : item.book.title;

  return {
    title: bookTitle(item.book.title, item.book.author),
    description:
      item.description?.slice(0, 200) ||
      item.book.description?.slice(0, 200) ||
      `${byline}, disponibilă pe ShelfShare${item.city ? ` în ${item.city}` : ''}${
        forSale ? ` - ${price} lei` : ' - disponibilă pentru schimb'
      }.`,
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

          {item.user && (
            <Link
              to={`/users/${item.user.id}`}
              className="mt-6 flex items-center gap-3 rounded-[16px] border border-border bg-card p-3 hover:bg-muted"
            >
              <div className="flex size-10 items-center justify-center overflow-hidden rounded-full bg-muted font-bold">
                {item.user.profileImage ? (
                  <img src={item.user.profileImage} alt="" className="size-full object-cover" />
                ) : (
                  (item.user.name ?? item.user.username ?? '?').charAt(0).toUpperCase()
                )}
              </div>
              <div className="min-w-0">
                <p className="truncate font-medium">{item.user.name ?? item.user.username}</p>
                {item.user.city && (
                  <p className="truncate text-sm text-muted-foreground">{item.user.city}</p>
                )}
              </div>
            </Link>
          )}

          {/* Vizitatorul fără cont vede anunțul, dar ca să ceară cartea are
              nevoie de un cont - butoanele ar duce la un 401. */}
          {!user && (
            <div className="mt-8">
              <Link
                to="/login"
                className="inline-flex rounded-full bg-primary px-6 py-3 text-sm font-bold text-primary-foreground"
              >
                {t('bookDetailRequestExchange')}
              </Link>
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
