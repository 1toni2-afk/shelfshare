/**
 * Partajează un link către o pagină a aplicației. Port al `shareAppLink` din
 * shared/utils/share_link.dart.
 *
 * Pe web Flutter copia linkul în clipboard și arăta un mesaj; aici folosim în
 * plus Web Share API acolo unde există (telefon, unde Capacitor rulează același
 * cod), fiindcă e exact comportamentul pe care îl are aplicația nativă.
 */
// Instanța i18next direct: fișierul nu e o componentă React, dar mesajul pe
// care îl trimite ajunge într-un toast, sub ochii userului.
import i18n from '@/lib/i18n';

export async function shareAppLink(
  path: string,
  notify: (message: string) => void,
): Promise<void> {
  const link = `${window.location.origin}${path}`;

  if (navigator.share) {
    try {
      await navigator.share({ url: link });
      return;
    } catch {
      // Anulat de user sau refuzat de browser - cădem pe copiere.
    }
  }

  try {
    await navigator.clipboard.writeText(link);
    notify(i18n.t('shareLinkCopied'));
  } catch {
    notify(i18n.t('shareLinkCopied'));
  }
}
