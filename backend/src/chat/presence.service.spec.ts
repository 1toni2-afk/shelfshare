import { PresenceService } from './presence.service';
import { PrismaService } from '../prisma/prisma.service';

/**
 * Contorul „online acum" din bara laterală a panoului de admin: adminul ține
 * aplicația deschisă tocmai ca să-l vadă, deci se număra mereu pe sine și
 * „1 online" nu însemna niciodată „mai e cineva pe site".
 */
describe('PresenceService - snapshot fără cine se uită', () => {
  const service = () =>
    new PresenceService({} as unknown as PrismaService);

  it('scoate userul exclus din toate cele trei cifre', () => {
    const presence = service();
    presence.addConnection('admin'); // telefon
    presence.addConnection('admin'); // browser
    presence.addConnection('vizitator');

    expect(presence.snapshot('admin')).toEqual({
      users: 1,
      connections: 1,
      ids: ['vizitator'],
    });
  });

  it('fără exclusiv, numără pe toată lumea (la fel ca metodele vechi)', () => {
    const presence = service();
    presence.addConnection('admin');
    presence.addConnection('admin');
    presence.addConnection('vizitator');

    const snapshot = presence.snapshot();
    expect(snapshot.users).toBe(presence.onlineCount());
    expect(snapshot.connections).toBe(presence.connectionCount());
    expect(snapshot.ids).toEqual(presence.onlineUserIds());
  });

  it('adminul singur pe site vede zero, nu unu', () => {
    const presence = service();
    presence.addConnection('admin');

    expect(presence.snapshot('admin')).toEqual({
      users: 0,
      connections: 0,
      ids: [],
    });
  });
});
