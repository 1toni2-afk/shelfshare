/**
 * Partajează un link către o pagină a aplicației. Port al `shareAppLink` din
 * shared/utils/share_link.dart.
 *
 * Pe web Flutter copia linkul în clipboard și arăta un mesaj; aici folosim în
 * plus Web Share API acolo unde există (telefon, unde Capacitor rulează același
 * cod), fiindcă e exact comportamentul pe care îl are aplicația nativă.
 *
 * Textul mesajului e în română, netradus - la fel ca în Flutter, care are acolo
 * un literal, nu o cheie de traducere.
 */
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
    notify('Link copiat în clipboard');
  } catch {
    notify('Link copiat în clipboard');
  }
}
