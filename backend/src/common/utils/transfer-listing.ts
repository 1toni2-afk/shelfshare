import { Prisma } from '@prisma/client';

/**
 * Mută efectiv un exemplar în biblioteca celui care l-a primit, la
 * finalizarea unui schimb sau a unei vânzări.
 *
 * Până acum marcam doar anunțul vechi cu `permanentlyTransferred` și
 * așteptam ca noul proprietar să apese „re-listează" ca să existe undeva o
 * carte a lui - până atunci cartea rămânea, ca obiect, doar în biblioteca
 * celui care o dăduse. Acum creăm imediat exemplarul noului proprietar (copie
 * a celui vechi, nelistat: nici la schimb, nici la vânzare, nici la
 * licitație), legat de anunțul original prin `previousListingId`, iar anunțul
 * vechi iese din biblioteca activă a fostului proprietar și rămâne doar în
 * „Rafturi golite" ca istoric.
 *
 * Idempotent: dacă exemplarul noului proprietar există deja (retry, dublu
 * Done), îl întoarce pe acela în loc să creeze un al doilea.
 */
export async function transferListingOwnership(
  tx: Prisma.TransactionClient,
  userBookId: string,
  newOwnerId: string,
) {
  const original = await tx.userBook.findUnique({ where: { id: userBookId } });
  if (!original) return null;

  // Anunțul unui magazin cu mai multe exemplare nu se închide la prima
  // vânzare: scade stocul cu unul și rămâne pe piață. Fără asta, un anticariat
  // cu 5 exemplare dispărea din căutare după primul client, până la
  // sincronizarea următoare a feed-ului.
  const hasStockLeft = original.stockQuantity > 1;

  // `permanentlyTransferred` există ca să nu poată cineva re-lista cartea pe
  // care tocmai a dat-o din mână. Pentru un magazin, rândul nu e un exemplar,
  // ci o linie de stoc: același sku se reaprovizionează, iar marcajul ar
  // închide definitiv linia și ar face următorul import să eșueze pe ea (vezi
  // syncStockRow). Rămâne doar delistat, cu stoc 0.
  const seller = await tx.user.findUnique({
    where: { id: original.userId },
    select: { isStore: true },
  });
  const soldOut = {
    stockQuantity: 0,
    availableForSwap: false,
    isForSale: false,
    isPromoted: false,
    // Rezervarea („schimb în curs") și-a făcut treaba: de aici încolo anunțul
    // e închis, nu doar pus deoparte.
    reservedForExchangeId: null,
  };

  await tx.userBook.update({
    where: { id: userBookId },
    data: hasStockLeft
      ? { stockQuantity: { decrement: 1 }, reservedForExchangeId: null }
      : seller?.isStore
        ? soldOut
        : { ...soldOut, permanentlyTransferred: true },
  });

  // Cartea rămâne la fostul proprietar doar dacă el e chiar cel care o
  // primește (nu se poate în practică, dar nu vrem un rând duplicat).
  if (original.userId === newOwnerId) return original;

  const existing = await tx.userBook.findFirst({
    where: { previousListingId: userBookId, userId: newOwnerId },
  });
  if (existing) {
    // Retry / dublu „Done": exemplarul e deja creat, dar intrarea de raft
    // poate lipsi (transferuri făcute înainte de schimbarea asta).
    await addToNewOwnerShelf(tx, newOwnerId, original.bookId);
    return existing;
  }

  const copy = await tx.userBook.create({
    data: {
      userId: newOwnerId,
      bookId: original.bookId,
      condition: original.condition,
      language: original.language,
      edition: original.edition,
      isHardcover: original.isHardcover,
      description: original.description,
      tags: original.tags,
      photos: original.photos,
      mainPhotoUrl: original.mainPhotoUrl,
      city: original.city,
      // Ajunge în bibliotecă, nu în piață: ce face mai departe cu ea
      // (schimb, vânzare, licitație) decide noul proprietar.
      availableForSwap: false,
      isForSale: false,
      isAuction: false,
      // Un singur exemplar, oricâte ar mai fi rămas în stocul magazinului:
      // cumpărătorul a primit o carte, nu raftul.
      stockQuantity: 1,
      previousListingId: userBookId,
    },
  });

  await addToNewOwnerShelf(tx, newOwnerId, original.bookId);

  return copy;
}

/**
 * Cartea primită intră și în raftul personal al noului proprietar, exact ca
 * una adăugată manual prin „Add a book" > „Add to shelf" (`owned: true`).
 * Fără asta, exemplarul primit exista doar ca anunț nelistat și nu apărea
 * deloc în „Cărțile mele" din My Shelf.
 *
 * Statusul e „vreau să citesc" doar la creare - dacă userul avea deja cartea
 * pe raft (ex. o marcase „citesc"), nu îi rescriem statusul, doar o marcăm
 * ca deținută.
 */
async function addToNewOwnerShelf(
  tx: Prisma.TransactionClient,
  userId: string,
  bookId: string,
) {
  await tx.bookshelfEntry.upsert({
    where: { userId_bookId: { userId, bookId } },
    create: { userId, bookId, status: 'WANT_TO_READ', owned: true },
    update: { owned: true },
  });
}
