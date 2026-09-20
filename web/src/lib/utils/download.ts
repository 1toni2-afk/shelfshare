/**
 * Descarcă un text ca fișier, fără drum pe la server.
 *
 * Port al `downloadTextFile` din core/utils/browser_download_web.dart: un blob,
 * un `<a download>` sintetic, click, revocare. `revokeObjectURL` e amânat un
 * tick - revocat sincron, Safari anulează descărcarea pornită o clipă înainte.
 */
export function downloadTextFile({
  filename,
  content,
  mimeType = 'text/plain',
}: {
  filename: string;
  content: string;
  mimeType?: string;
}): void {
  const blob = new Blob([content], { type: `${mimeType};charset=utf-8` });
  const url = URL.createObjectURL(blob);
  const anchor = document.createElement('a');
  anchor.href = url;
  anchor.download = filename;
  anchor.rel = 'noopener';
  document.body.append(anchor);
  anchor.click();
  anchor.remove();
  setTimeout(() => URL.revokeObjectURL(url), 0);
}
