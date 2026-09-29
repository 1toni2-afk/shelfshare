import { AttemptGuardService } from './attempt-guard.service';

describe('AttemptGuardService', () => {
  it('cere captcha după al treilea eșec pe aceeași pereche IP + email', () => {
    const guard = new AttemptGuardService();
    const results = [1, 2, 3, 4].map(() =>
      guard.shouldChallenge('login', '1.2.3.4', 'a@b.ro'),
    );
    expect(results).toEqual([false, false, false, true]);
  });

  it('o reușită golește contorul - login-urile corecte nu se adună', () => {
    const guard = new AttemptGuardService();
    for (let i = 0; i < 6; i++) {
      expect(guard.shouldChallenge('login', '1.2.3.4', 'A@b.ro')).toBe(false);
      guard.reset('login', '1.2.3.4', 'a@b.ro');
    }
  });
});
