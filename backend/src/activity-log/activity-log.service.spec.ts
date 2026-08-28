import { mkdtempSync, readFileSync, readdirSync } from 'fs';
import { tmpdir } from 'os';
import { join } from 'path';
import { ActivityLogService } from './activity-log.service';
import { PrismaService } from '../prisma/prisma.service';

describe('ActivityLogService', () => {
  let root: string;
  let prisma: { user: { findUnique: jest.Mock } };

  const build = (env: Record<string, string> = {}) => {
    root = mkdtempSync(join(tmpdir(), 'shelfshare-log-'));
    process.env.ACTIVITY_LOG_DIR = root;
    process.env.ACTIVITY_LOG_TZ = 'Europe/Bucharest';
    for (const [key, value] of Object.entries(env)) process.env[key] = value;
    return new ActivityLogService(prisma as unknown as PrismaService);
  };

  /** Singurul fișier scris, cu tot cu calea lui relativă (an/lună/zi). */
  const onlyFile = (stream: string) => {
    const year = readdirSync(join(root, stream))[0];
    const month = readdirSync(join(root, stream, year))[0];
    const day = readdirSync(join(root, stream, year, month))[0];
    return {
      relative: `${stream}/${year}/${month}/${day}`,
      content: readFileSync(join(root, stream, year, month, day), 'utf8'),
    };
  };

  beforeEach(() => {
    prisma = {
      user: {
        findUnique: jest
          .fn()
          .mockResolvedValueOnce({
            name: 'Ana Pop',
            username: null,
            email: 'a@x.ro',
          })
          .mockResolvedValueOnce({
            name: 'Ion Vasile',
            username: null,
            email: 'i@x.ro',
          }),
      },
    };
    delete process.env.ACTIVITY_LOG_CHAT_CONTENT;
    delete process.env.ACTIVITY_LOG_DISABLED;
  });

  it('scrie in logs/activity/AN/LUNA/AN-LUNA-ZI.log, cu antet si linia formatata', async () => {
    const service = build();

    service.record({
      action: 'EXCHANGE_ACCEPTED',
      actorId: 'aaaaaaaa-1111-2222-3333-444444444444',
      targetId: 'bbbbbbbb-1111-2222-3333-444444444444',
      details: { carte: 'Ion' },
    });
    await service.flush();

    const { relative, content } = onlyFile('activity');
    // activity/2026/08/2026-08-28.log
    expect(relative).toMatch(
      /^activity\/\d{4}\/\d{2}\/\d{4}-\d{2}-\d{2}\.log$/,
    );
    expect(content).toMatch(/^# \d{4}-\d{2}-\d{2} \(activity\)\n/);
    expect(content).toContain(
      'Ana Pop (aaaaaaaa) → Ion Vasile (bbbbbbbb) EXCHANGE_ACCEPTED {"carte":"Ion"}',
    );
    expect(content).toMatch(/\[\d{2}:\d{2}:\d{2}\]/);
  });

  it('scrie mesajele in fisierul separat de chat, fara continut', async () => {
    const service = build();

    service.recordChat({
      action: 'MESSAGE_SENT',
      actorId: 'aaaaaaaa-1111-2222-3333-444444444444',
      targetId: 'bbbbbbbb-1111-2222-3333-444444444444',
      content: 'salut, mai e disponibila?',
    });
    await service.flush();

    expect(() => onlyFile('activity')).toThrow();
    const { content } = onlyFile('chat');
    expect(content).toContain('MESSAGE_SENT');
    expect(content).toContain('"length":25');
    expect(content).not.toContain('salut');
  });

  it('include continutul mesajului doar cu ACTIVITY_LOG_CHAT_CONTENT=true', async () => {
    const service = build({ ACTIVITY_LOG_CHAT_CONTENT: 'true' });

    service.recordChat({
      action: 'MESSAGE_SENT',
      actorId: 'aaaaaaaa-1111-2222-3333-444444444444',
      content: 'salut',
    });
    await service.flush();

    expect(onlyFile('chat').content).toContain('"text":"salut"');
  });

  it('nu arunca daca userul nu poate fi citit din baza', async () => {
    prisma.user.findUnique = jest.fn().mockRejectedValue(new Error('db down'));
    const service = build();

    service.record({
      action: 'FOLLOW',
      actorId: 'cccccccc-1111',
      targetId: null,
    });
    await expect(service.flush()).resolves.toBeUndefined();
    expect(onlyFile('activity').content).toContain(
      'necunoscut (cccccccc) FOLLOW',
    );
  });
});
