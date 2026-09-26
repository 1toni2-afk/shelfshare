import { useQuery } from '@tanstack/react-query';
import { useParams } from 'react-router-dom';
import { useTranslation } from 'react-i18next';
import { ScreenHeader } from '@/components/layout/ScreenHeader';
import { ErrorNotice, Spinner } from '@/components/ui';
import { staticPageUrl, type StaticPageSlug } from '@/lib/staticPages';

/**
 * Paginile publice (centrul de siguranță, întrebări frecvente, despre
 * dezvoltator, confidențialitate, termeni) afișate ÎN aplicație.
 *
 * Până acum erau linkuri cu `target="_blank"`: te scoteau din aplicație într-un
 * tab nou, ceea ce pe telefon înseamnă că ai plecat de tot. Dar nici nu pot fi
 * rescrise ca ecrane React: aceleași adrese trebuie să rămână accesibile
 * PUBLIC, fără autentificare, fiindcă asta cer verificarea OAuth a Google și
 * Play Console, iar politica de confidențialitate promite ea însăși că
 * versiunea actualizată se publică tot acolo.
 *
 * Deci: fișierul HTML rămâne singura sursă a textului, iar ecranul ăsta îi ia
 * doar `<main>`-ul și îl desenează în tema aplicației. Un singur text, două
 * locuri în care se vede.
 */

/**
 * Doar paginile pe care le cunoaștem. Lista e o listă albă, nu o comoditate:
 * fără ea, `/info/<orice>` ar transforma ecranul într-un cititor de fișiere de
 * pe propriul server, cu conținutul injectat în pagină.
 */
const PAGES = {
  'safety-center': { titleKey: 'profileSafetyCenter' },
  'help-center': { titleKey: 'profileHelpCenter' },
  'about-dev': { titleKey: 'aboutDevTitle' },
  privacy: { titleKey: 'profilePrivacyPolicy' },
  terms: { titleKey: 'profileTermsOfService' },
} as const;

export type { StaticPageSlug };

/**
 * Extrage `<main>` din pagină.
 *
 * Folosim DOMParser, nu o expresie regulată: parserul e cel al browserului,
 * deci nu se încurcă în atribute care conțin „</main>" și nu execută nimic -
 * documentul rezultat e inert, scripturile din el nu rulează.
 *
 * Scoatem și navigarea proprie a paginii (înapoi la site, comutatorul de
 * limbă): în aplicație avem deja săgeata din antet, iar limba o dă aplicația.
 */
function extractMain(html: string): string {
  const parsed = new DOMParser().parseFromString(html, 'text/html');
  const main = parsed.querySelector('main');
  /*
    Fără `<main>` înseamnă că n-am primit pagina, ci altceva - de regulă
    index.html-ul aplicației, fiindcă serverul nu cunoaște ruta. Aruncăm, ca să
    se vadă eroarea: un `return ''` ar desena un ecran gol, care arată ca o
    pagină care „nu are conținut" în loc de o configurare greșită.
  */
  if (!main) throw new Error('Pagina nu conține <main>');
  for (const node of main.querySelectorAll('nav, .back, .lang')) node.remove();
  return main.innerHTML;
}

export function StaticPageScreen() {
  const { t, i18n } = useTranslation();
  const { page } = useParams<{ page: string }>();

  const slug = (page && page in PAGES ? page : null) as StaticPageSlug | null;

  const content = useQuery({
    queryKey: ['static-page', slug, i18n.language],
    queryFn: async ({ signal }) => {
      const response = await fetch(staticPageUrl(slug!, i18n.language), { signal });
      if (!response.ok) throw new Error(String(response.status));
      return extractMain(await response.text());
    },
    enabled: slug !== null,
    // Textele astea se schimbă de câteva ori pe an; nu au de ce să fie recerute
    // la fiecare intrare în ecran.
    staleTime: 60 * 60 * 1000,
  });

  const header = <ScreenHeader title={slug ? t(PAGES[slug].titleKey) : ''} back="/settings" />;

  if (!slug) {
    return (
      <div className="mx-auto max-w-2xl p-6">
        {header}
        <ErrorNotice message={t('commonGenericError')} />
      </div>
    );
  }

  return (
    <div className="mx-auto w-full max-w-[720px] px-5 pb-16 pt-2 min-[900px]:px-8">
      {header}

      {content.isPending ? (
        <div className="flex min-h-[50vh] items-center justify-center text-accent">
          <Spinner size={28} />
        </div>
      ) : content.isError ? (
        <ErrorNotice message={t('commonGenericError')} onRetry={() => void content.refetch()} />
      ) : (
        /*
          `dangerouslySetInnerHTML` cu un fișier de pe PROPRIUL server, scris de
          noi, din care parserul a scos deja orice ar putea rula. Nu ajunge aici
          text venit de la utilizatori.
        */
        <article
          className="static-page"
          dangerouslySetInnerHTML={{ __html: content.data }}
        />
      )}
    </div>
  );
}
