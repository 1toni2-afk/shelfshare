import { Link } from 'react-router-dom';
import { useQuery } from '@tanstack/react-query';
import { useTranslation } from 'react-i18next';
import { BookOpen, MapPin, Repeat, Search } from 'lucide-react';
import { booksKeys, booksRepository } from '@/features/books/booksRepository';
import { BookCard } from '@/features/books/BookCard';
import { BookGrid } from '@/features/books/BookGrid';
import { useDocumentMeta } from '@/lib/seo/useDocumentMeta';
import { LANDING_META } from '@/lib/seo/routes';

/**
 * Pagina de prezentare, la „/", pentru vizitatorul fără cont.
 *
 * Până acum „/" era Home-ul autentificat, deci oricine nu era logat - inclusiv
 * un crawler - era trimis direct la /login și nu vedea nicăieri ce e
 * ShelfShare. Ecranul autentificat NU se schimbă: `HomeOrLanding` din router
 * alege între cele două după starea sesiunii.
 *
 * Conținutul e text real în HTML (titluri, paragrafe, `<a href>`), nu doar
 * imagini sau butoane cu `onClick`: e singura pagină de pe care un robot
 * pornește descoperirea restului site-ului.
 */
export function PublicLandingScreen() {
  const { t } = useTranslation();
  useDocumentMeta(LANDING_META);

  // Aceleași anunțuri publice pe care le ia și beta-server.js pentru varianta
  // pre-randată a paginii. Endpointul e public (`GET /books/browse`, fără
  // gardian), deci merge fără token.
  const recent = useQuery({
    queryKey: booksKeys.browse({ limit: 12, sort: 'recent' }),
    queryFn: ({ signal }) => booksRepository.browse({ limit: 12, sort: 'recent' }, signal),
  });

  return (
    <div className="mx-auto w-full max-w-[1100px] px-5 pb-16 pt-10 min-[900px]:px-8">
      <section>
        <h1 className="max-w-[18ch] font-display text-3xl font-bold leading-tight min-[900px]:text-5xl">
          {t('landingHeadline', 'Dă-ți cărțile citite mai departe')}
        </h1>
        <p className="mt-5 max-w-[60ch] text-lg leading-relaxed text-muted-foreground">
          {t(
            'landingIntro',
            'ShelfShare este comunitatea de cititori din România unde cărțile second-hand își găsesc un cititor nou. Îți pui pe raft cărțile pe care le-ai terminat, cauți ce vrei să citești în continuare și te înțelegi direct cu omul care o are - prin schimb sau la un preț pe care îl stabiliți voi.',
          )}
        </p>

        <div className="mt-7 flex flex-wrap gap-3">
          <Link
            to="/browse"
            className="rounded-full bg-primary px-6 py-3 text-sm font-bold text-primary-foreground"
          >
            {t('landingCtaBrowse', 'Vezi cărțile disponibile')}
          </Link>
          <Link
            to="/register"
            className="rounded-full border border-border px-6 py-3 text-sm font-bold text-foreground hover:bg-muted"
          >
            {t('landingCtaRegister', 'Creează cont gratuit')}
          </Link>
        </div>
      </section>

      <section className="mt-14">
        <h2 className="font-display text-2xl font-bold">
          {t('landingHowTitle', 'Cum funcționează')}
        </h2>
        <div className="mt-6 grid gap-5 min-[700px]:grid-cols-3">
          <Step
            icon={<BookOpen size={22} />}
            title={t('landingStep1Title', '1. Îți listezi cărțile')}
            text={t(
              'landingStep1Text',
              'Scanezi codul ISBN sau cauți titlul, iar datele cărții se completează singure. Spui în ce stare e și dacă o dai la schimb, o vinzi, sau amândouă.',
            )}
          />
          <Step
            icon={<Search size={22} />}
            title={t('landingStep2Title', '2. Cauți ce vrei să citești')}
            text={t(
              'landingStep2Text',
              'Cauți după titlu, autor sau gen și filtrezi după orașul tău. Dacă o carte nu e încă pe site, o pui pe lista de dorințe și primești o notificare când apare.',
            )}
          />
          <Step
            icon={<Repeat size={22} />}
            title={t('landingStep3Title', '3. Vă înțelegeți direct')}
            text={t(
              'landingStep3Text',
              'Vorbiți în chatul din aplicație și stabiliți cum faceți predarea - în oraș sau prin curier. ShelfShare nu ia comision din nimic.',
            )}
          />
        </div>
      </section>

      <section className="mt-14">
        <h2 className="font-display text-2xl font-bold">
          {t('landingRecentTitle', 'Cărți adăugate recent')}
        </h2>
        <p className="mt-2 text-muted-foreground">
          {t(
            'landingRecentText',
            'O parte din cărțile puse la schimb sau la vânzare de cititori din toată țara.',
          )}
        </p>

        {recent.data && recent.data.items.length > 0 ? (
          <>
            <div className="mt-6">
              <BookGrid>
                {recent.data.items.map((item, index) => (
                  <BookCard key={item.id} item={item} eager={index < 6} />
                ))}
              </BookGrid>
            </div>
            <Link
              to="/browse"
              className="mt-7 inline-flex items-center gap-1.5 text-sm font-semibold text-accent"
            >
              {t('landingRecentMore', 'Vezi tot catalogul')}
            </Link>
          </>
        ) : (
          <p className="mt-6 text-muted-foreground">
            <Link to="/browse" className="font-semibold text-accent">
              {t('landingRecentMore', 'Vezi tot catalogul')}
            </Link>
          </p>
        )}
      </section>

      <section className="mt-14 rounded-[16px] border border-border bg-card p-6 min-[900px]:p-8">
        <h2 className="font-display text-2xl font-bold">
          {t('landingSafetyTitle', 'În siguranță, de la un cititor la altul')}
        </h2>
        <p className="mt-3 max-w-[70ch] text-muted-foreground">
          {t(
            'landingSafetyText',
            'Fiecare cont are nevoie de un email confirmat, iar profilurile adună recenzii după fiecare schimb. Dacă ceva nu e în regulă, poți raporta anunțul sau omul din aplicație.',
          )}
        </p>
        <div className="mt-5 flex flex-wrap gap-x-6 gap-y-2">
          {/* `<a>`, nu `<Link>`: paginile astea sunt HTML servit direct de
              beta-server.js, nu rute ale routerului din browser. */}
          <a href="/safety-center" className="text-sm font-semibold text-accent">
            {t('settingsSafetyCenter', 'Centrul de siguranță')}
          </a>
          <a href="/help-center" className="text-sm font-semibold text-accent">
            {t('settingsHelpCenter', 'Întrebări frecvente')}
          </a>
          <Link to="/leaderboard" className="text-sm font-semibold text-accent">
            {t('publicNavLeaderboard', 'Clasament')}
          </Link>
          <Link to="/global-stats" className="text-sm font-semibold text-accent">
            {t('publicNavStats', 'Statistici')}
          </Link>
        </div>
      </section>

      <section className="mt-14">
        <h2 className="font-display text-2xl font-bold">
          {t('landingCitiesTitle', 'Cărți din toată țara')}
        </h2>
        <p className="mt-2 max-w-[70ch] text-muted-foreground">
          {t(
            'landingCitiesText',
            'Cei mai mulți cititori aleg să se întâlnească în oraș, așa că filtrarea după localitate e primul lucru din catalog.',
          )}
        </p>
        <p className="mt-4 flex items-center gap-1.5 text-sm text-muted-foreground">
          <MapPin size={15} />
          <Link to="/browse" className="font-semibold text-accent">
            {t('landingCitiesLink', 'Caută în catalog după oraș')}
          </Link>
        </p>
      </section>
    </div>
  );
}

function Step({ icon, title, text }: { icon: React.ReactNode; title: string; text: string }) {
  return (
    <div className="rounded-[16px] border border-border bg-card p-5">
      <span className="inline-flex rounded-lg bg-accent/15 p-2 text-accent">{icon}</span>
      <h3 className="mt-3 font-display text-lg font-bold">{title}</h3>
      <p className="mt-2 text-sm leading-relaxed text-muted-foreground">{text}</p>
    </div>
  );
}
