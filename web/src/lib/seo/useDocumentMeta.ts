import { useEffect } from 'react';
import { SITE_NAME, type DocumentMeta } from './routes';
// Instanta i18next direct: hook-ul asta ruleaza si inainte ca o componenta sa
// fi cerut traducerile, iar descrierea implicita ajunge in `<meta>`.
import i18n from '@/lib/i18n';

/**
 * Originea publică a site-ului, pentru URL-uri canonice absolute.
 *
 * Citită din `location.origin`, nu dintr-o constantă compilată: același bundle
 * rulează pe beta.shelfshare.ro, pe localhost în dezvoltare ȘI în APK-ul
 * Capacitor. O constantă ar declara „https://beta.shelfshare.ro" drept
 * canonical inclusiv când pagina e deschisă de pe altundeva.
 */
function origin(): string {
  return typeof window === 'undefined' ? '' : window.location.origin;
}

/**
 * Pune titlul, descrierea, canonical-ul, Open Graph-ul și (opțional)
 * structured data pentru pagina curentă.
 *
 * NU e mecanismul care face paginile indexabile - alea vin deja gata din
 * HTML-ul servit de scripts/beta-server.js, tocmai ca un crawler care nu
 * execută JavaScript să le găsească. Hook-ul ăsta e pentru navigarea ÎN
 * aplicație: după ce routerul schimbă pagina fără reîncărcare, nimeni nu mai
 * rescrie `<head>`-ul, deci titlul din tab și cardul de la „distribuie" ar
 * rămâne blocate pe prima pagină deschisă.
 *
 * De-asta valorile trebuie să fie ACELEAȘI cu cele injectate de server (vezi
 * nota din routes.ts): scopul e ca cele două căi să conveargă, nu să difere.
 */
export function useDocumentMeta(meta: DocumentMeta | null): void {
  const { title, description, path, image, jsonLd } = meta ?? {};
  // `jsonLd` e un obiect nou la fiecare render al apelantului, deci nu poate
  // sta ca atare în lista de dependențe - ar reporni efectul la infinit.
  const jsonLdKey = jsonLd ? JSON.stringify(jsonLd) : null;

  useEffect(() => {
    if (!title || !path) return;

    const url = origin() + path;
    document.title = title;

    setMeta('name', 'description', description || i18n.t('seoDefaultDescription'));
    setLink('canonical', url);

    setMeta('property', 'og:type', 'website');
    setMeta('property', 'og:site_name', SITE_NAME);
    setMeta('property', 'og:title', title);
    setMeta('property', 'og:description', description || i18n.t('seoDefaultDescription'));
    setMeta('property', 'og:url', url);
    setMeta('name', 'twitter:card', image ? 'summary_large_image' : 'summary');
    setMeta('name', 'twitter:title', title);
    setMeta('name', 'twitter:description', description || i18n.t('seoDefaultDescription'));
    if (image) {
      setMeta('property', 'og:image', image);
      setMeta('name', 'twitter:image', image);
    }

    setJsonLd(jsonLdKey);
  }, [title, description, path, image, jsonLdKey]);
}

function setMeta(attribute: 'name' | 'property', key: string, value: string): void {
  let tag = document.head.querySelector<HTMLMetaElement>(`meta[${attribute}="${key}"]`);
  if (!tag) {
    tag = document.createElement('meta');
    tag.setAttribute(attribute, key);
    document.head.appendChild(tag);
  }
  tag.setAttribute('content', value);
}

function setLink(rel: string, href: string): void {
  let tag = document.head.querySelector<HTMLLinkElement>(`link[rel="${rel}"]`);
  if (!tag) {
    tag = document.createElement('link');
    tag.setAttribute('rel', rel);
    document.head.appendChild(tag);
  }
  tag.setAttribute('href', href);
}

/** Marcajul blocului scris de noi, ca să nu-l confundăm cu cel al serverului. */
const JSON_LD_ID = 'ss-jsonld';

/**
 * Structured data pentru pagina curentă.
 *
 * Blocul pus de server e ȘTERS odată cu primul apel: la o navigare în
 * aplicație (de la o carte la alta) altfel ar rămâne în pagină cel al cărții
 * de unde am plecat, iar pagina ar declara două entități diferite.
 */
function setJsonLd(serialized: string | null): void {
  document.head.querySelector('script[type="application/ld+json"]:not([id])')?.remove();
  const existing = document.getElementById(JSON_LD_ID);

  if (!serialized) {
    existing?.remove();
    return;
  }

  const tag = existing ?? document.createElement('script');
  if (!existing) {
    tag.id = JSON_LD_ID;
    tag.setAttribute('type', 'application/ld+json');
    document.head.appendChild(tag);
  }
  tag.textContent = serialized;
}
