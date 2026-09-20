import { api } from '@/lib/api/client';
import type { Book, DecimalString, PublicUser, UserBook } from '@/types/models';

export interface BookReview {
  id: string;
  userId: string;
  bookId: string;
  rating: number;
  text: string | null;
  authorName: string | null;
  authorAvatar: string | null;
  createdAt: string;
}

export interface ReviewsSummary {
  averageRating: number | null;
  reviewCount: number;
  reviews: BookReview[];
}

export interface BookWork {
  book: Book;
  /**
   * Edițiile aceleiași opere (același titlu + autor, normalizate). Prima e
   * MEREU cea cerută, ca selectorul să se deschidă pe ce a cerut userul, nu pe
   * cea mai nouă din grup.
   */
  editions: Book[];
  reviews: ReviewsSummary;
  /** Anunțurile active pentru oricare dintre ediții. */
  listings: UserBook[];
}

export interface AuctionBidder {
  id: string | null;
  name: string | null;
  username: string | null;
  profileImage: string | null;
  label: string | null;
}

export interface AuctionBid {
  id: string;
  amount: DecimalString;
  createdAt: string;
  bidder: AuctionBidder;
}

export interface Auction {
  id: string;
  startingPrice: DecimalString;
  reservePrice: DecimalString | null;
  buyNowPrice: DecimalString | null;
  currentPrice: DecimalString;
  endsAt: string;
  status: string;
  createdAt: string;
  reserveMet: boolean;
  watchersCount: number;
  highestBidder: AuctionBidder | null;
  bids?: AuctionBid[];
  userBook?: UserBook;
  seller?: PublicUser;
}

export interface MapCity {
  city: string;
  lat: number;
  lng: number;
  count: number;
}

export const workRepository = {
  get(bookId: string, signal?: AbortSignal): Promise<BookWork> {
    return api.get<BookWork>(`/books/work/${bookId}`, { signal });
  },

  addReview(bookId: string, input: { rating: number; text?: string }): Promise<BookReview> {
    return api.post<BookReview>('/reviews', { bookId, ...input });
  },

  deleteReview(bookId: string): Promise<void> {
    return api.delete(`/reviews/${bookId}`);
  },

  myReview(bookId: string, signal?: AbortSignal): Promise<BookReview | null> {
    return api.get<BookReview | null>(`/reviews/book/${bookId}/mine`, { signal });
  },
};

export const auctionsRepository = {
  get(id: string, signal?: AbortSignal): Promise<Auction> {
    return api.get<Auction>(`/auctions/${id}`, { signal });
  },

  bid(id: string, amount: number): Promise<Auction> {
    return api.post<Auction>(`/auctions/${id}/bids`, { amount });
  },

  toggleWatch(id: string): Promise<{ watching: boolean }> {
    return api.post<{ watching: boolean }>(`/auctions/${id}/watch`);
  },

  myBids(signal?: AbortSignal): Promise<Auction[]> {
    return api.get<Auction[]>('/auctions/my-bids', { signal });
  },
};

export const mapRepository = {
  cities(signal?: AbortSignal): Promise<MapCity[]> {
    return api.get<MapCity[]>('/books/map-cities', { signal });
  },
};

export const workKeys = {
  work: (bookId: string) => ['books', 'work', bookId] as const,
  myReview: (bookId: string) => ['reviews', 'mine', bookId] as const,
  auction: (id: string) => ['auctions', id] as const,
  mapCities: () => ['books', 'map-cities'] as const,
};
