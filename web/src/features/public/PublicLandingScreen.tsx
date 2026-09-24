import { useMemo } from 'react';
import { Link } from 'react-router-dom';
import { useQuery } from '@tanstack/react-query';
import { useTranslation } from 'react-i18next';
import { BookOpen, Repeat, Search } from 'lucide-react';
import { booksKeys, booksRepository } from '@/features/books/booksRepository';
import { BookCard } from '@/features/books/BookCard';
import { BookGrid, useBookGridColumns } from '@/features/books/BookGrid';
import { Spinner } from '@/components/ui';
import { TypewriterText, type TypewriterPhrase } from '@/components/ui/TypewriterText';
import { useDocumentMeta } from '@/lib/seo/useDocumentMeta';
import { LANDING_META } from '@/lib/seo/routes';
import type { UserBook } from '@/types/models';
import { staticPageUrl } from '@/lib/staticPages';
import { BookMatchDemo } from './BookMatchDemo';
import { LandingFeatures } from './LandingFeatures';

/**
 * Câte RÂNDURI de anunțuri vede vizitatorul: ultimele adăugate, o tăietură.
 *
 * Rânduri, nu un număr fix de cărți: pe un ecran lat grila are 5-6 coloane, iar
 * un 12 fix lăsa ultimul rând cu două cărți răzlețe sub estompare - arăta a
 * listă care s-a terminat, nu a listă tăiată.
 *
 * Nu e o pagină de catalog - n-are filtre, sortare sau „încarcă mai multe".
 * Rostul listei e să arate că site-ul e VIU și că lucrurile de aici sunt reale;
 * restul cere un cont.
 */
const GUEST_PREVIEW_ROWS = 3;

/** Cât cerem: destul pentru 3 rânduri și la lățimea maximă a grilei (8 coloane). */
const GUEST_PREVIEW_LIMIT = 24;

/**
 * Pagina principală a vizitatorului fără cont, la „/".
 *
 * Stă în ACELAȘI shell ca aplicația logată (bara laterală, aceeași bară de
 * sus, aceleași carduri de carte). Până acum vizitatorul avea un antet-subsol
 * complet diferit, deci interfața se schimba din temelii în secunda de după
 * înregistrare, iar omul învăța produsul de două ori.
 *
 * Ce diferă: numele vânzătorilor sunt estompate (vezi `SellerName`), lista se
 * oprește după ultimele anunțuri sub o estompare cu „fă-ți cont ca să vezi mai
 * multe", iar orice apăsare în afara paginii ăsteia deschide dialogul de cont.
 *
 * Conținutul rămâne text real în HTML (titluri, paragrafe, `<a href>`), nu doar
 * imagini sau butoane cu `onClick`: e singura pagină de pe care un robot
 * pornește descoperirea restului site-ului, iar varianta pre-randată din
 * scripts/beta-seo.js trebuie să spună același lucru.
 */
export function PublicLandingScreen({ decorative = false }: { decorative?: boolean } = {}) {
  const { t, i18n } = useTranslation();
  /*
    `decorative`: aceeași pagină e randată și estompat, ca fundal al ecranelor
    de autentificare (vezi AuthLayout). Acolo NU are voie să atingă `<head>` -
    altfel titlul din tab și cardul de „distribuie" al paginii de login ar
    deveni cele ale paginii de prezentare, iar un link către /login distribuit
    de cineva ar arăta ca pagina principală.
  */
  /*
    Titlul și descrierea se iau din traduceri, nu din constanta fixă:
    beta-server.js servește deja pagina în limba din `Accept-Language`, iar
    dacă aplicația ar rescrie `<head>`-ul cu varianta românească, titlul din
    tab ar sări înapoi pe română la o secundă după ce s-a încărcat - exact
    tranziția pe care o eliminăm. Valorile rămân în oglindă cu STRINGS din
    scripts/beta-seo.js.
  */
  useDocumentMeta(
    decorative
      ? null
      : {
          ...LANDING_META,
          title: t('seoLandingTitle'),
          description: t('seoLandingDescription'),
        },
  );

  // Recalculate doar la schimbarea limbii: un tablou nou la fiecare randare ar
  // reporni animația din prima literă (vezi comentariul din TypewriterText).
  const headlines = useMemo<TypewriterPhrase[]>(
    () => [
      { text: t('landingHeadline', 'Dă-ți cărțile citite mai departe'), holdMs: 10000 },
      // Fraze scurte, sub ~34 de semne: pe telefon titlul are 18ch și una mai
      // lungă ar trece pe al treilea rând; pe desktop (36ch) încap pe un rând.
      { text: t('landingHeadline2', 'Cartea citită merită alt cititor'), holdMs: 5000 },
      { text: t('landingHeadline3', 'Nu o lăsa să adune praf'), holdMs: 5000 },
      { text: t('landingHeadline4', 'Următoarea carte e la alt om'), holdMs: 5000 },
    ],
    [t],
  );

  // Aceleași anunțuri publice pe care le ia și beta-seo.js pentru varianta
  // pre-randată a paginii. Endpointul e public (`GET /books/browse`, fără
  // gardian), deci merge fără token.
  const recent = useQuery({
    queryKey: booksKeys.browse({ limit: GUEST_PREVIEW_LIMIT, sort: 'recent' }),
    queryFn: ({ signal }) =>
      booksRepository.browse({ limit: GUEST_PREVIEW_LIMIT, sort: 'recent' }, signal),
  });

  return (
    <>
      {/*
        Fără bară proprie de ecran: pe desktop un antet care scria doar
        „ShelfShare" repeta numele de pe bara laterală și împingea titlul în jos
        cu 64px degeaba. Pagina începe direct cu titlul.

        Nici `pt-16` nu mai e nevoie sub pragul de sidebar: butonul de meniu nu
        mai plutește peste conținut, stă în bara de brand din AppShell, care își
        ocupă singură spațiul.
      */}
      <div className="mx-auto w-full max-w-[1350px] px-4 pb-16 pt-4 min-[900px]:px-6 min-[900px]:pt-8">
        <section className="pt-4">
          {/*
            Titlul se scrie literă cu literă, ca salutul de pe pagina
            principală a userului logat - același `TypewriterText`, ca cele
            două pagini să pară același produs.

            `min-h`: frazele au lungimi diferite, iar fără o înălțime minimă
            tot ce urmează ar sălta cu un rând la fiecare schimbare de frază.
            Prima frază rămâne cea pre-randată de scripts/beta-seo.js în `<h1>`,
            deci ce vede robotul e și ce se scrie primul pe ecran.
          */}
          <h1 className="min-h-[2.5em] max-w-[18ch] font-display text-3xl font-bold leading-tight min-[900px]:max-w-[36ch] min-[900px]:text-5xl">
            <TypewriterText phrases={headlines} />
          </h1>
          <p className="mt-5 max-w-[60ch] text-lg leading-relaxed text-muted-foreground">
            {t(
              'landingIntro',
              'ShelfShare este comunitatea de cititori din România unde cărțile second-hand își găsesc un cititor nou. Îți pui pe raft cărțile pe care le-ai terminat, cauți ce vrei să citești în continuare și te înțelegi direct cu omul care o are - prin schimb sau la un preț pe care îl stabiliți voi.',
            )}
          </p>

          <div className="mt-7 flex flex-wrap gap-3">
            <Link
              to="/register"
              className="rounded-full bg-primary px-6 py-3 text-sm font-bold text-primary-foreground"
            >
              {t('landingCtaRegister', 'Creează cont gratuit')}
            </Link>
          </div>
        </section>

        <RecentListings items={recent.data?.items ?? []} loading={recent.isPending} />

        {!decorative && <BookMatchDemo />}

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

        <LandingFeatures />

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
            <a
              href={staticPageUrl('safety-center', i18n.language)}
              className="text-sm font-semibold text-accent"
            >
              {t('settingsSafetyCenter')}
            </a>
            <a
              href={staticPageUrl('help-center', i18n.language)}
              className="text-sm font-semibold text-accent"
            >
              {t('settingsHelpCenter')}
            </a>
          </div>
        </section>

      </div>
    </>
  );
}

/**
 * Ultimele anunțuri, tăiate de o estompare care se ridică din partea de jos.
 *
 * Estomparea e un strat PESTE grilă, nu o tăietură a listei: ultimele cărți se
 * văd pe jumătate, deci se vede că lista continuă. O listă oprită scurt și
 * curat arată ca un site gol; una care se pierde în ceață arată ca un site
 * plin, din care mai ai de văzut.
 */
function RecentListings({ items, loading }: { items: UserBook[]; loading: boolean }) {
  const { t } = useTranslation();
  // Numărul de coloane e nevoie AICI, nu doar în grilă: din el se calculează
  // câte cărți fac rânduri întregi, deci unde cade tăietura.
  // Lățimea se măsoară pe containerul grilei, care are exact lățimea ei.
  const [gridRef, columns] = useBookGridColumns();
  const visible = items.slice(0, columns * GUEST_PREVIEW_ROWS);

  return (
    <section className="mt-12">
      <h2 className="font-display text-2xl font-bold">
        {t('landingRecentTitle', 'Cărți adăugate recent')}
      </h2>
      <p className="mt-2 max-w-[70ch] text-muted-foreground">
        {t(
          'landingRecentText',
          'O parte din cărțile puse la schimb sau la vânzare de cititori din toată țara.',
        )}
      </p>

      {loading ? (
        <div className="flex min-h-[40vh] items-center justify-center text-accent">
          <Spinner size={28} />
        </div>
      ) : items.length === 0 ? (
        <p className="mt-6 text-muted-foreground">
          <Link to="/browse" className="font-semibold text-accent">
            {t('landingRecentMore', 'Vezi tot catalogul')}
          </Link>
        </p>
      ) : (
        <div ref={gridRef} className="relative mt-6">
          <BookGrid columns={columns}>
            {visible.map((item, index) => (
              <BookCard key={item.id} item={item} eager={index < 6} />
            ))}
          </BookGrid>

          {/*
            `pointer-events-none` pe stratul de estompare, dar NU pe butonul
            dinăuntru: altfel dreptunghiul ar înghiți clicurile pe cărțile de
            sub el, iar ultimul rând n-ar mai putea fi deschis deloc.
          */}
          <div className="pointer-events-none absolute inset-x-0 bottom-0 flex flex-col items-center justify-end gap-3 bg-gradient-to-t from-background via-background/95 to-transparent pb-6 pt-20">
            <p className="max-w-[40ch] px-4 text-center text-sm text-muted-foreground">
              {t(
                'guestMoreBooksText',
                'Mai sunt cărți - și încă una nouă la fiecare câteva minute.',
              )}
            </p>
            <Link
              to="/register"
              className="pointer-events-auto rounded-full bg-primary px-7 py-3.5 text-sm font-bold text-primary-foreground shadow-lg hover:brightness-110"
            >
              {t('guestMoreBooksCta', 'Creează-ți cont ca să vezi mai multe')}
            </Link>
          </div>
        </div>
      )}
    </section>
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
