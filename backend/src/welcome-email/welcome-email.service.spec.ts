import { ConfigService } from '@nestjs/config';
import { WelcomeEmailService } from './welcome-email.service';
import { PrismaService } from '../prisma/prisma.service';
import { MailService } from '../mail/mail.service';

/**
 * Emailul de bun venit de la 3 zile. Ce contează aici nu e textul, ci cele
 * două garanții: nu pleacă de două ori către același cont și nu pleacă deloc
 * către conturi vechi (altfel o repornire a cronului ar trimite „mulțumim că
 * te-ai înregistrat" întregii baze de useri).
 */
describe('WelcomeEmailService', () => {
  const DAY_MS = 24 * 60 * 60 * 1000;

  function setup(due: { id: string; email: string; name: string | null }[]) {
    const findMany = jest.fn().mockResolvedValue(due);
    const update = jest.fn().mockResolvedValue({});
    const sendWelcomeTipsEmail = jest.fn().mockResolvedValue(undefined);
    const service = new WelcomeEmailService(
      { user: { findMany, update } } as unknown as PrismaService,
      { sendWelcomeTipsEmail } as unknown as MailService,
      new ConfigService({ FRONTEND_URL: 'https://shelfshare.ro' }),
    );
    return { service, findMany, update, sendWelcomeTipsEmail };
  }

  it('cere doar conturile de peste 3 zile, mai noi de 14, netrimise și neșterse', async () => {
    const { service, findMany } = setup([]);
    const before = Date.now();

    await service.sendDueWelcomeEmails();

    const where = findMany.mock.calls[0][0].where;
    expect(where.welcomeEmailSentAt).toBeNull();
    expect(where.deletionScheduledAt).toBeNull();
    // Fereastra: [acum - 14 zile, acum - 3 zile]. Comparăm cu toleranță,
    // fiindcă serviciul își citește propriul `Date.now()`.
    expect(where.createdAt.lte.getTime()).toBeCloseTo(before - 3 * DAY_MS, -3);
    expect(where.createdAt.gte.getTime()).toBeCloseTo(before - 14 * DAY_MS, -3);
  });

  it('trimite și marchează fiecare cont găsit', async () => {
    const { service, update, sendWelcomeTipsEmail } = setup([
      { id: 'u1', email: 'ana@example.com', name: 'Ana' },
      { id: 'u2', email: 'bogdan@example.com', name: null },
    ]);

    await service.sendDueWelcomeEmails();

    expect(sendWelcomeTipsEmail).toHaveBeenCalledTimes(2);
    expect(sendWelcomeTipsEmail).toHaveBeenCalledWith({
      to: 'ana@example.com',
      name: 'Ana',
      appUrl: 'https://shelfshare.ro',
    });
    expect(update).toHaveBeenCalledTimes(2);
    expect(update.mock.calls[0][0].where).toEqual({ id: 'u1' });
    expect(update.mock.calls[0][0].data.welcomeEmailSentAt).toBeInstanceOf(Date);
  });

  it('un email eșuat NU se marchează ca trimis și nu oprește restul lotului', async () => {
    const { service, update, sendWelcomeTipsEmail } = setup([
      { id: 'u1', email: 'ana@example.com', name: 'Ana' },
      { id: 'u2', email: 'bogdan@example.com', name: 'Bogdan' },
    ]);
    sendWelcomeTipsEmail.mockRejectedValueOnce(new Error('resend down'));

    await service.sendDueWelcomeEmails();

    expect(sendWelcomeTipsEmail).toHaveBeenCalledTimes(2);
    expect(update).toHaveBeenCalledTimes(1);
    expect(update.mock.calls[0][0].where).toEqual({ id: 'u2' });
  });

  it('fără conturi eligibile nu atinge deloc serviciul de email', async () => {
    const { service, update, sendWelcomeTipsEmail } = setup([]);

    await service.sendDueWelcomeEmails();

    expect(sendWelcomeTipsEmail).not.toHaveBeenCalled();
    expect(update).not.toHaveBeenCalled();
  });
});
