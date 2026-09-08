import { transferListingOwnership } from './transfer-listing';

/** Minimul din `Prisma.TransactionClient` folosit de helper. */
function makeTx(original: Record<string, unknown> | null, existing: unknown = null) {
  return {
    userBook: {
      findUnique: jest.fn().mockResolvedValue(original),
      findFirst: jest.fn().mockResolvedValue(existing),
      update: jest.fn().mockResolvedValue(original),
      create: jest.fn().mockImplementation(({ data }) => ({ id: 'nou', ...data })),
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
};

describe('transferListingOwnership', () => {
  it('creeaza exemplarul noului proprietar, nelistat, legat de anuntul original', async () => {
    const tx = makeTx(original);

    await transferListingOwnership(tx as never, 'ub-1', 'requester-1');

    expect(tx.userBook.update).toHaveBeenCalledWith({
      where: { id: 'ub-1' },
      data: {
        permanentlyTransferred: true,
        availableForSwap: false,
        isForSale: false,
        isPromoted: false,
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
});
