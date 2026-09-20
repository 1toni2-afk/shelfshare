import { api } from '@/lib/api/client';
import type { DecimalString, PublicUser, UserBook } from '@/types/models';

export type ExchangeStatus =
  | 'PENDING'
  | 'ACCEPTED'
  | 'REJECTED'
  | 'CANCELLED'
  | 'COMPLETED'
  | 'EXPIRED';

/** OfferStatus din schema Prisma - aceleași valori ca ExchangeStatus. */
export type OfferStatus = ExchangeStatus;

export interface ExchangeRequest {
  id: string;
  requesterId: string;
  ownerId: string;
  requestedBook: UserBook;
  offeredBook: UserBook | null;
  additionalOfferedBooks: UserBook[];
  offeredAmount: DecimalString | null;
  status: ExchangeStatus;
  message: string | null;
  requester: PublicUser;
  owner: PublicUser;
  meetingTime: string | null;
  meetingLocation: string | null;
  createdAt: string;
  acceptedAt: string | null;
  requesterRatingForOwner: number | null;
  ownerRatingForRequester: number | null;
  requesterDoneAt: string | null;
  ownerDoneAt: string | null;
  cancelReason: string | null;
}

export interface PriceOffer {
  id: string;
  buyerId: string;
  /**
   * Vânzătorul. Se numește `owner`, nu `seller`, pentru că așa îl întoarce
   * API-ul (`INCLUDE_FULL` din offers.service.ts) - o ofertă se face pe cartea
   * cuiva, iar acela e proprietarul ei. Tipul a zis o vreme `seller`, iar
   * TypeScript n-avea cum să prindă diferența: câmpul lipsea pur și simplu din
   * JSON, deci `offer.seller` era `undefined` și ecranul „Oferte trimise"
   * crăpa la primul `.name`.
   */
  ownerId: string;
  userBook: UserBook;
  amount: DecimalString;
  status: OfferStatus;
  message: string | null;
  buyer: PublicUser;
  owner: PublicUser;
  createdAt: string;
  meetingTime: string | null;
  meetingLocation: string | null;
}

export interface RateExchangeInput {
  overall: number;
  punctuality?: number;
  communication?: number;
  condition?: number;
  review?: string;
}

export const exchangesRepository = {
  sent(signal?: AbortSignal): Promise<ExchangeRequest[]> {
    return api.get<ExchangeRequest[]>('/exchanges/sent', { signal });
  },

  received(signal?: AbortSignal): Promise<ExchangeRequest[]> {
    return api.get<ExchangeRequest[]>('/exchanges/received', { signal });
  },

  detail(id: string, signal?: AbortSignal): Promise<ExchangeRequest> {
    return api.get<ExchangeRequest>(`/exchanges/${id}`, { signal });
  },

  accept(id: string): Promise<ExchangeRequest> {
    return api.post<ExchangeRequest>(`/exchanges/${id}/accept`);
  },

  reject(id: string): Promise<ExchangeRequest> {
    return api.post<ExchangeRequest>(`/exchanges/${id}/reject`);
  },

  cancel(id: string, reason?: string): Promise<ExchangeRequest> {
    return api.post<ExchangeRequest>(`/exchanges/${id}/cancel`, reason ? { reason } : undefined);
  },

  /**
   * Marchează schimbul ca efectuat. Nu îl finalizează singur: schimbul devine
   * COMPLETED abia când AMÂNDOI au apăsat, iar între timp rămâne în starea
   * „așteaptă confirmarea celuilalt". De aceea butonul nu dispare după primul
   * clic - vezi EXCHANGE_DONE_PENDING_CONFIRMATION.
   */
  markDone(id: string): Promise<ExchangeRequest> {
    return api.post<ExchangeRequest>(`/exchanges/${id}/done`);
  },

  dispute(id: string, reason?: string): Promise<ExchangeRequest> {
    return api.post<ExchangeRequest>(`/exchanges/${id}/done/dispute`, reason ? { reason } : undefined);
  },

  shareContact(id: string): Promise<ExchangeRequest> {
    return api.post<ExchangeRequest>(`/exchanges/${id}/contact`);
  },

  acknowledgeSafety(id: string): Promise<ExchangeRequest> {
    return api.post<ExchangeRequest>(`/exchanges/${id}/safety-ack`);
  },

  rate(id: string, input: RateExchangeInput): Promise<ExchangeRequest> {
    return api.post<ExchangeRequest>(`/exchanges/${id}/rate`, input);
  },

  proposeMeeting(id: string, input: { meetingTime: string; meetingLocation: string }) {
    return api.patch<ExchangeRequest>(`/exchanges/${id}/meeting`, input);
  },

  acceptMeeting(id: string): Promise<ExchangeRequest> {
    return api.post<ExchangeRequest>(`/exchanges/${id}/meeting/accept`);
  },

  declineMeeting(id: string): Promise<ExchangeRequest> {
    return api.post<ExchangeRequest>(`/exchanges/${id}/meeting/decline`);
  },
};

/**
 * Ofertele de preț. Controllerul nu are prefix, iar rutele includ deja
 * `offers/` - de aceea căile de aici nu sunt sub un segment comun.
 */
export const offersRepository = {
  sent(signal?: AbortSignal): Promise<PriceOffer[]> {
    return api.get<PriceOffer[]>('/offers/sent', { signal });
  },

  received(signal?: AbortSignal): Promise<PriceOffer[]> {
    return api.get<PriceOffer[]>('/offers/received', { signal });
  },

  detail(id: string, signal?: AbortSignal): Promise<PriceOffer> {
    return api.get<PriceOffer>(`/offers/${id}`, { signal });
  },

  create(userBookId: string, input: { amount: number; message?: string }): Promise<PriceOffer> {
    return api.post<PriceOffer>(`/books/${userBookId}/offers`, input);
  },

  accept(id: string): Promise<PriceOffer> {
    return api.post<PriceOffer>(`/offers/${id}/accept`);
  },

  reject(id: string): Promise<PriceOffer> {
    return api.post<PriceOffer>(`/offers/${id}/reject`);
  },

  cancel(id: string): Promise<PriceOffer> {
    return api.post<PriceOffer>(`/offers/${id}/cancel`);
  },

  counter(id: string, amount: number): Promise<PriceOffer> {
    return api.post<PriceOffer>(`/offers/${id}/counter`, { amount });
  },

  markDone(id: string): Promise<PriceOffer> {
    return api.post<PriceOffer>(`/offers/${id}/done`);
  },

  shareContact(id: string): Promise<PriceOffer> {
    return api.post<PriceOffer>(`/offers/${id}/contact`);
  },

  proposeMeeting(id: string, input: { meetingTime: string; meetingLocation: string }) {
    return api.post<PriceOffer>(`/offers/${id}/meeting`, input);
  },

  acceptMeeting(id: string): Promise<PriceOffer> {
    return api.post<PriceOffer>(`/offers/${id}/meeting/accept`);
  },
};

export const exchangeKeys = {
  all: ['exchanges'] as const,
  sent: () => ['exchanges', 'sent'] as const,
  received: () => ['exchanges', 'received'] as const,
  detail: (id: string) => ['exchanges', 'detail', id] as const,
  offersSent: () => ['offers', 'sent'] as const,
  offersReceived: () => ['offers', 'received'] as const,
  offerDetail: (id: string) => ['offers', 'detail', id] as const,
};
