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

  it('nu creeaza un al doilea exemplar daca deja exista (retry / dublu Done)', async () => {
    const tx = makeTx(original, { id: 'ub-copie', userId: 'requester-1' });

    const result = await transferListingOwnership(tx as never, 'ub-1', 'requester-1');

    expect(tx.userBook.create).not.toHaveBeenCalled();
    expect(result).toEqual({ id: 'ub-copie', userId: 'requester-1' });
  });

  it('nu face nimic daca anuntul nu mai exista', async () => {
    const tx = makeTx(null);

    const result = await transferListingOwnership(tx as never, 'ub-1', 'requester-1');

    expect(result).toBeNull();
    expect(tx.userBook.update).not.toHaveBeenCalled();
  });
});
