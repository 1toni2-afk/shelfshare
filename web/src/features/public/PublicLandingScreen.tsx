import { useMemo } from 'react';
import { Link } from 'react-router-dom';
import { useQuery } from '@tanstack/react-query';
import { useTranslation } from 'react-i18next';
import {
  Bell,
  BookMarked,
  BookOpen,
  Compass,
  Heart,
  Images,
  LayoutGrid,
  Map as MapIcon,
  MessageCircle,
  Repeat,
  Rss,
  Search,
  Sparkles,
  TrendingUp,
  Trophy,
  Users,
} from 'lucide-react';
import { booksKeys, booksRepository } from '@/features/books/booksRepository';
import { BookCard } from '@/features/books/BookCard';
import { BookGrid, useBookGridColumns } from '@/features/books/BookGrid';
import { Spinner } from '@/components/ui';
import { TypewriterText, type TypewriterPhrase } from '@/components/ui/TypewriterText';
import { useDocumentMeta } from '@/lib/seo/useDocumentMeta';
import { LANDING_META } from '@/lib/seo/routes';
import type { UserBook } from '@/types/models';

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
  const { t } = useTranslation();
  /*
    `decorative`: aceeași pagină e randată și estompat, ca fundal al ecranelor
    de autentificare (vezi AuthLayout). Acolo NU are voie să atingă `<head>` -
    altfel titlul din tab și cardul de „distribuie" al paginii de login ar
    deveni cele ale paginii de prezentare, iar un link către /login distribuit
    de cineva ar arăta ca pagina principală.
  */
  useDocumentMeta(decorative ? null : LANDING_META);

  // Recalculate doar la schimbarea limbii: un tablou nou la fiecare randare ar
  // reporni animația din prima literă (vezi comentariul din TypewriterText).
  const headlines = useMemo<TypewriterPhrase[]>(
    () => [
      { text: t('landingHeadline', 'Dă-ți cărțile citite mai departe'), holdMs: 10000 },
      // Fraze scurte, sub ~34 de semne: la lățimea titlului (18ch) una mai
      // lungă ar trece pe al treilea rând și ar muta tot ce urmează.
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
        Fără bară de sus: un antet care scria doar „ShelfShare" repeta numele
        de pe bara laterală și împingea titlul în jos cu 64px degeaba. Pagina
        începe direct cu titlul.

        `pt-16` sub pragul de sidebar: acolo butonul de meniu plutește fix în
        colțul din stânga-sus, iar fără spațiul ăsta ar sta peste primul rând
        de text.
      */}
      <div className="mx-auto w-full max-w-[1350px] px-4 pb-16 pt-16 min-[900px]:px-6 min-[900px]:pt-8">
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
          <h1 className="min-h-[2.5em] max-w-[18ch] font-display text-3xl font-bold leading-tight min-[900px]:text-5xl">
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
            <Link
              to="/browse"
              className="rounded-full border border-border px-6 py-3 text-sm font-bold text-foreground hover:bg-muted"
            >
              {t('landingCtaBrowse', 'Vezi cărțile disponibile')}
            </Link>
          </div>
        </section>

        <RecentListings items={recent.data?.items ?? []} loading={recent.isPending} />

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

        <MenuGuide />

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

/**
 * Ce e în meniul din stânga, explicat pe îndelete.
 *
 * Vizitatorul VEDE bara laterală completă (același shell ca userul logat), dar
 * fiecare rând îi cere un cont. Fără explicația asta, meniul e o listă de
 * cuvinte care se termină în același dialog - omul nu are de unde să știe ce
 * primește dacă își face cont. Aici scrie, în ordinea din meniu.
 *
 * Iconițele sunt EXACT cele din AppShell: rândul din explicație și rândul din
 * meniu trebuie să se recunoască unul pe altul dintr-o privire.
 */
function MenuGuide() {
  const { t } = useTranslation();

  const main = [
    {
      icon: <LayoutGrid size={20} />,
      title: t('navHome', 'Acasă'),
      text: t(
        'landingMenuHome',
        'Cele mai noi anunțuri, plus rânduri tematice: ce se caută mult, ce e aproape de tine și ce ți s-ar potrivi după cărțile tale.',
      ),
    },
    {
      icon: <Compass size={20} />,
      title: t('navSearch', 'Descoperă'),
      text: t(
        'landingMenuSearch',
        'Căutare după titlu, autor sau gen, cu filtre de oraș, stare și preț. Căutările pe care le repeți des se salvează.',
      ),
    },
    {
      icon: <BookOpen size={20} />,
      title: t('navLibrary', 'Raftul meu'),
      text: t(
        'landingMenuLibrary',
        'Cărțile tale. Le adaugi scanând ISBN-ul sau le imporți dintr-un fișier Goodreads, apoi spui care sunt la schimb și care la vânzare.',
      ),
    },
    {
      icon: <Rss size={20} />,
      title: t('navActivityFeed', 'Activitate'),
      text: t(
        'landingMenuFeed',
        'Ce au mai pus pe raft cititorii pe care îi urmărești - de obicei de acolo apar cărțile bune înainte să le ia altcineva.',
      ),
    },
    {
      icon: <MessageCircle size={20} />,
      title: t('navChat', 'Chat'),
      text: t(
        'landingMenuChat',
        'Vorbești direct cu omul care are cartea. Cererile de schimb și ofertele de preț ajung tot aici, ca un card în discuție.',
      ),
    },
    {
      icon: <Bell size={20} />,
      title: t('navNotifications', 'Notificări'),
      text: t(
        'landingMenuNotifications',
        'Când cineva îți cere o carte, îți răspunde la o ofertă sau apare pe site un titlu de pe lista ta de dorințe.',
      ),
    },
  ];

  const shortcuts = [
    { icon: <BookMarked size={18} />, label: t('bookshelfTitle', 'Raftul meu de cărți'), text: t('landingMenuBookshelf', 'Rafturile tale, așa cum le vede lumea.') },
    { icon: <Repeat size={18} />, label: t('navMyExchanges', 'Schimburile mele'), text: t('landingMenuExchanges', 'Cererile trimise și primite, de la propunere până la predare.') },
    { icon: <Heart size={18} />, label: t('navWishlist', 'Lista de dorințe'), text: t('landingMenuWishlist', 'Cărțile pe care le vrei; primești un semn când apar.') },
    { icon: <Images size={18} />, label: t('collectionsTitle', 'Colecții'), text: t('landingMenuCollections', 'Îți grupezi cărțile cum vrei tu: de citit, de dat, de păstrat.') },
    { icon: <Sparkles size={18} />, label: t('smartMatchesTitle', 'Potriviri de schimb'), text: t('landingMenuMatches', 'Oameni care au ce vrei tu și vor ce ai tu.') },
    { icon: <Users size={18} />, label: t('shortcutFollowing', 'Urmăriți'), text: t('landingMenuFollowing', 'Cititorii ale căror rafturi le ții aproape.') },
    { icon: <MapIcon size={18} />, label: t('mapTitle', 'Cărți din apropiere'), text: t('landingMenuMap', 'Aceleași anunțuri, puse pe hartă.') },
    { icon: <Users size={18} />, label: t('groupsTitle', 'Grupuri'), text: t('landingMenuGroups', 'Cluburi de lectură, cu discuție și cartea lunii.') },
    { icon: <Trophy size={18} />, label: t('shortcutLeaderboard', 'Clasament'), text: t('landingMenuLeaderboard', 'Cine a dat cele mai multe cărți mai departe.') },
    { icon: <TrendingUp size={18} />, label: t('globalStatsTitle', 'Statistici globale'), text: t('landingMenuStats', 'Cărțile și autorii care circulă cel mai mult.') },
  ];

  return (
    <section className="mt-14">
      <h2 className="font-display text-2xl font-bold">
        {t('landingMenuTitle', 'Ce găsești în meniu')}
      </h2>
      <p className="mt-2 max-w-[70ch] text-muted-foreground">
        {t(
          'landingMenuIntro',
          'Meniul din stânga e aplicația întreagă. Îl vezi de pe acum; ca să-l deschizi, ai nevoie de un cont.',
        )}
      </p>

      <div className="mt-6 grid gap-4 min-[700px]:grid-cols-2 min-[1100px]:grid-cols-3">
        {main.map((item) => (
          <div key={item.title} className="rounded-[16px] border border-border bg-card p-5">
            <div className="flex items-center gap-2.5">
              <span className="inline-flex rounded-lg bg-accent/15 p-2 text-accent">
                {item.icon}
              </span>
              <h3 className="font-display text-lg font-bold">{item.title}</h3>
            </div>
            <p className="mt-2.5 text-sm leading-relaxed text-muted-foreground">{item.text}</p>
          </div>
        ))}
      </div>

      <h3 className="mt-8 text-[11px] font-semibold uppercase tracking-[0.1em] text-muted-foreground">
        {t('navShortcuts', 'SCURTĂTURI')}
      </h3>
      <p className="mt-2 max-w-[70ch] text-sm text-muted-foreground">
        {t(
          'landingMenuShortcutsIntro',
          'Sub meniul principal îți alegi singur ce scurtături stau la vedere. Astea sunt toate:',
        )}
      </p>
      <ul className="mt-4 grid gap-x-8 gap-y-3 min-[700px]:grid-cols-2">
        {shortcuts.map((item) => (
          <li key={item.label} className="flex items-start gap-2.5">
            <span className="mt-0.5 shrink-0 text-accent">{item.icon}</span>
            <span className="text-sm leading-relaxed">
              <span className="font-semibold">{item.label}</span>{' '}
              <span className="text-muted-foreground">{item.text}</span>
            </span>
          </li>
        ))}
      </ul>
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
