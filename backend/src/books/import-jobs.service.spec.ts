import { ConflictException } from '@nestjs/common';
import { ImportJobsService } from './import-jobs.service';

describe('ImportJobsService - un import odata per user', () => {
  let service: ImportJobsService;

  beforeEach(() => {
    service = new ImportJobsService();
  });

  /** Un import care nu se termina pana nu-l lasam noi. */
  const pending = () => {
    let finish!: () => void;
    const done = new Promise<void>((resolve) => (finish = resolve));
    return { run: () => done, finish };
  };

  it('refuza al doilea import cat timp primul ruleaza in fundal', async () => {
    const first = pending();
    service.start('user-1', first.run);

    expect(() => service.start('user-1', async () => null)).toThrow(
      ConflictException,
    );
    await expect(
      service.runExclusive('user-1', async () => null),
    ).rejects.toBeInstanceOf(ConflictException);
    // Alt user nu e blocat.
    expect(() => service.start('user-2', async () => null)).not.toThrow();

    first.finish();
    await new Promise((resolve) => setImmediate(resolve));
    expect(() => service.start('user-1', async () => null)).not.toThrow();
  });

  it('elibereaza userul si cand importul sincron esueaza', async () => {
    await expect(
      service.runExclusive('user-1', async () => {
        throw new Error('boom');
      }),
    ).rejects.toThrow('boom');

    await expect(
      service.runExclusive('user-1', async () => 'ok'),
    ).resolves.toBe('ok');
  });
});
