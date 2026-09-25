import { Prisma } from '@prisma/client';

/**
 * Anunțurile pe care le vede publicul. Un anunț poate fi simultan de mai
 * multe tipuri (și la schimb, și la vânzare), deci vizibilitatea se decide
 * per-tip, nu printr-un flag pe anunț: apare dacă ARE MĂCAR UN tip pe care
 * proprietarul nu l-a ascuns (vezi User în schema.prisma). Aceeași listă e
 * folosită de căutare/discover ȘI de pagina operei, ca un anunț ascuns să nu
 * reapară pe o altă rută - și de profilul public, din același motiv.
 */
export const PUBLICLY_VISIBLE_LISTING_OR: Prisma.UserBookWhereInput[] = [
  { availableForSwap: true, user: { hideSwapListingsPublic: false } },
  {
    isForSale: true,
    salePrice: { gt: 0 },
    user: { hideSaleListingsPublic: false },
  },
  {
    isForSale: true,
    salePrice: { equals: 0 },
    user: { hideDonationListingsPublic: false },
  },
  { isAuction: true, user: { hideAuctionListingsPublic: false } },
];
