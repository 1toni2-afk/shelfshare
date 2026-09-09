import { transferListingOwnership } from './transfer-listing';

/** Minimul din `Prisma.TransactionClient` folosit de helper. */
function makeTx(
  original: Record<string, unknown> | null,
  existing: unknown = null,
  seller: { isStore: boolean } = { isStore: false },
) {
  return {
    userBook: {
      findUnique: jest.fn().mockResolvedValue(original),
      findFirst: jest.fn().mockResolvedValue(existing),
      update: jest.fn().mockResolvedValue(original),
      create: jest.fn().mockImplementation(({ data }) => ({ id: 'nou', ...data })),
    },
    user: {
      findUnique: jest.fn().mockResolvedValue(seller),
    },
    bookshelfEntry: {
      upsert: jest.fn().mockResolvedValue({}),
    },
  };
}

const original = {
  id: 'ub-1',
  userId: 'owner-1',
  bookId: 'book-1',
  condition: 'BUNA',
  language: 'ro',
  edition: '2020',
  isHardcover: true,
  description: 'exemplar cu semne de carte',
  tags: ['clasic'],
  photos: ['a.jpg', 'b.jpg'],
  mainPhotoUrl: 'a.jpg',
  city: 'Cluj-Napoca',
  stockQuantity: 1,
};

describe('transferListingOwnership', () => {
  it('creeaza exemplarul noului proprietar, nelistat, legat de anuntul original', async () => {
    const tx = makeTx(original);

    await transferListingOwnership(tx as never, 'ub-1', 'requester-1');

    expect(tx.userBook.update).toHaveBeenCalledWith({
      where: { id: 'ub-1' },
      data: {
        stockQuantity: 0,
        availableForSwap: false,
        isForSale: false,
        isPromoted: false,
        reservedForExchangeId: null,
        permanentlyTransferred: true,
      },
    });
    expect(tx.userBook.create).toHaveBeenCalledWith({
      data: expect.objectContaining({
        userId: 'requester-1',
        bookId: 'book-1',
        photos: ['a.jpg', 'b.jpg'],
        city: 'Cluj-Napoca',
        availableForSwap: false,
        isForSale: false,
        isAuction: false,
        previousListingId: 'ub-1',
      }),
    });
  });

  it('pune cartea primita si in raftul personal, ca detinuta', async () => {
    const tx = makeTx(original);

    await transferListingOwnership(tx as never, 'ub-1', 'requester-1');

    expect(tx.bookshelfEntry.upsert).toHaveBeenCalledWith({
      where: { userId_bookId: { userId: 'requester-1', bookId: 'book-1' } },
      create: {
        userId: 'requester-1',
        bookId: 'book-1',
        status: 'WANT_TO_READ',
        owned: true,
      },
      update: { owned: true },
    });
  });

  it('nu creeaza un al doilea exemplar daca deja exista (retry / dublu Done)', async () => {
    const tx = makeTx(original, { id: 'ub-copie', userId: 'requester-1' });

    const result = await transferListingOwnership(tx as never, 'ub-1', 'requester-1');

    expect(tx.userBook.create).not.toHaveBeenCalled();
    expect(result).toEqual({ id: 'ub-copie', userId: 'requester-1' });
    // ...dar se asigura ca intrarea de raft exista (transferuri mai vechi).
    expect(tx.bookshelfEntry.upsert).toHaveBeenCalled();
  });

  it('nu face nimic daca anuntul nu mai exista', async () => {
    const tx = makeTx(null);

    const result = await transferListingOwnership(tx as never, 'ub-1', 'requester-1');

    expect(result).toBeNull();
    expect(tx.userBook.update).not.toHaveBeenCalled();
  });

  describe('anunt de magazin (stoc)', () => {
    const storeListing = { ...original, userId: 'store-1', stockQuantity: 3 };

    it('scade stocul si lasa anuntul pe piata cat timp mai are exemplare', async () => {
      const tx = makeTx(storeListing, null, { isStore: true });

      await transferListingOwnership(tx as never, 'ub-1', 'buyer-1');

      expect(tx.userBook.update).toHaveBeenCalledWith({
        where: { id: 'ub-1' },
        data: { stockQuantity: { decrement: 1 }, reservedForExchangeId: null },
      });
      // Cumparatorul primeste un exemplar, nu raftul.
      expect(tx.userBook.create).toHaveBeenCalledWith({
        data: expect.objectContaining({ userId: 'buyer-1', stockQuantity: 1 }),
      });
    });

    it('la ultimul exemplar delisteaza, dar NU marcheaza linia ca transferata definitiv', async () => {
      const tx = makeTx({ ...storeListing, stockQuantity: 1 }, null, { isStore: true });

      await transferListingOwnership(tx as never, 'ub-1', 'buyer-1');

      const data = tx.userBook.update.mock.calls[0][0].data as Record<string, unknown>;
      expect(data.stockQuantity).toBe(0);
      expect(data.availableForSwap).toBe(false);
      // Fara asta, urmatorul import cu acelasi sku ar esua pe linia reaprovizionata.
      expect(data.permanentlyTransferred).toBeUndefined();
    });
  });
});
