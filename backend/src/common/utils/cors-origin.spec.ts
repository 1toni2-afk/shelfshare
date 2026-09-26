import { corsOrigin } from './cors-origin';

/** Rulează politica și întoarce decizia, sincron. */
function allows(origin: string | undefined): boolean {
  let decision: boolean | undefined;
  corsOrigin(origin, (_err, allow) => {
    decision = allow;
  });
  return decision === true;
}

describe('corsOrigin', () => {
  const originalEnv = process.env;

  beforeEach(() => {
    process.env = { ...originalEnv };
    delete process.env.PUBLIC_HOSTNAME;
    delete process.env.FRONTEND_URL;
    process.env.NODE_ENV = 'development';
  });

  afterAll(() => {
    process.env = originalEnv;
  });

  it('permite cererile fără Origin (server-to-server, curl)', () => {
    expect(allows(undefined)).toBe(true);
  });

  it('permite localhost în afara producției', () => {
    expect(allows('http://localhost:5173')).toBe(true);
    expect(allows('http://127.0.0.1:5961')).toBe(true);
  });

  it('respinge un domeniu public necunoscut în afara producției', () => {
    expect(allows('https://exemplu.ro')).toBe(false);
  });

  describe('PUBLIC_HOSTNAME cu o singură valoare', () => {
    beforeEach(() => {
      process.env.PUBLIC_HOSTNAME = 'sv-toni.tail6e27d0.ts.net';
    });

    it('permite gazda configurată, cu sau fără port', () => {
      expect(allows('https://sv-toni.tail6e27d0.ts.net')).toBe(true);
      expect(allows('https://sv-toni.tail6e27d0.ts.net:8443')).toBe(true);
    });

    it('respinge altă gazdă', () => {
      expect(allows('https://beta.shelfshare.ro')).toBe(false);
    });
  });

  describe('PUBLIC_HOSTNAME cu listă separată prin virgulă', () => {
    beforeEach(() => {
      process.env.PUBLIC_HOSTNAME = 'sv-toni.tail6e27d0.ts.net, beta.shelfshare.ro';
    });

    it('permite ambele gazde', () => {
      expect(allows('https://sv-toni.tail6e27d0.ts.net:8443')).toBe(true);
      expect(allows('https://beta.shelfshare.ro')).toBe(true);
    });

    it('acceptă prefixul www', () => {
      expect(allows('https://www.beta.shelfshare.ro')).toBe(true);
    });

    it('respinge o gazdă din afara listei', () => {
      expect(allows('https://altceva.shelfshare.ro')).toBe(false);
    });

    it('nu permite un sufix care doar SEAMĂNĂ cu o gazdă din listă', () => {
      // Ancorele din regex sunt singurul lucru care oprește asta; fără ele,
      // un atacator și-ar înregistra `beta.shelfshare.ro.exemplu.ro` și ar
      // trece de politică.
      expect(allows('https://beta.shelfshare.ro.exemplu.ro')).toBe(false);
      expect(allows('https://evilbeta.shelfshare.ro')).toBe(false);
    });
  });

  describe('în producție', () => {
    beforeEach(() => {
      process.env.NODE_ENV = 'production';
      process.env.FRONTEND_URL = 'https://shelfshare.ro';
    });

    it('permite doar FRONTEND_URL', () => {
      expect(allows('https://shelfshare.ro')).toBe(true);
      expect(allows('http://localhost:5173')).toBe(false);
    });

    it('permite și gazdele din PUBLIC_HOSTNAME', () => {
      process.env.PUBLIC_HOSTNAME = 'beta.shelfshare.ro';
      expect(allows('https://beta.shelfshare.ro')).toBe(true);
    });
  });
});
