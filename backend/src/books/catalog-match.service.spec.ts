import { CatalogMatchService } from './catalog-match.service';

function serviceReturning(rows: Array<{ id: string; title: string; author: string | null }>) {
  const prisma = { $queryRaw: jest.fn().mockResolvedValue(rows) };
  return new CatalogMatchService(prisma as never);
}

describe('CatalogMatchService.findByTitle', () => {
  it('leagă titlul fără diacritice de cartea din catalog', async () => {
    const service = serviceReturning([
      { id: 'lotr', title: 'Stăpânul Inelelor', author: 'J.R.R. Tolkien' },
    ]);
    const match = await service.findByTitle('stapanul inelelor', 'Tolkien');
    expect(match?.id).toBe('lotr');
  });

  it('nu leagă un titlu care doar conține cuvintele căutate', async () => {
    const service = serviceReturning([
      { id: 'x', title: 'Stăpânul Inelelor: Frăția Inelului', author: 'J.R.R. Tolkien' },
    ]);
    expect(await service.findByTitle('Stăpânul Inelelor', null)).toBeNull();
  });

  it('cere și autorul să se potrivească, când e dat', async () => {
    const service = serviceReturning([{ id: 'emma', title: 'Emma', author: 'Jane Austen' }]);
    expect(await service.findByTitle('Emma', 'Alt Autor')).toBeNull();
    expect((await service.findByTitle('Emma', 'Austen'))?.id).toBe('emma');
  });

  it('fără autor, nu ghicește între autori diferiți cu același titlu', async () => {
    const service = serviceReturning([
      { id: 'a', title: 'Inferno', author: 'Dan Brown' },
      { id: 'b', title: 'Inferno', author: 'Dante Alighieri' },
    ]);
    expect(await service.findByTitle('Inferno')).toBeNull();
  });

  it('nu blochează adăugarea dacă interogarea pică', async () => {
    const prisma = { $queryRaw: jest.fn().mockRejectedValue(new Error('no unaccent')) };
    const service = new CatalogMatchService(prisma as never);
    expect(await service.findByTitle('Emma')).toBeNull();
  });
});
