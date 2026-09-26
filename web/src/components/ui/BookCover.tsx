import { useState } from 'react';
import { cn } from '@/lib/utils/cn';

/**
 * Paleta (fundal, text) pentru coperțile generate din titlu. Aceleași 9
 * perechi ca în shared/widgets/book_cover.dart, ca aceeași carte să primească
 * aceeași culoare în ambele aplicații.
 */
const COVER_PALETTE: ReadonlyArray<readonly [string, string]> = [
  ['#12604C', '#CFEADE'],
  ['#4A41A3', '#DED9FF'],
  ['#8C3717', '#FFD9C9'],
  ['#17537F', '#D3E7F7'],
  ['#7D2C49', '#FFD4E2'],
  ['#4B5F16', '#E4EFC9'],
  ['#8A5C12', '#FFE6BD'],
  ['#7A2626', '#FFD6D6'],
  ['#2F5D63', '#CFE9EC'],
];

/**
 * Hash identic cu cel din Dart (`h * 31 + codeUnit`, mascat pe 31 de biți).
 * `charCodeAt` dă aceleași unități UTF-16 ca `String.codeUnits`, deci
 * rezultatul coincide - inclusiv pentru titluri cu diacritice.
 */
function coverHue(title: string): readonly [string, string] {
  let h = 0;
  for (let i = 0; i < title.length; i++) {
    h = (h * 31 + title.charCodeAt(i)) & 0x7fffffff;
  }
  return COVER_PALETTE[h % COVER_PALETTE.length];
}

interface BookCoverProps {
  url?: string | null;
  /**
   * Folosit când catalogul nu are copertă - de obicei prima poză urcată de
   * proprietar. Multe titluri românești fără ISBN nu se găsesc în Open Library
   * sau Google Books, dar au poza reală a exemplarului, care e oricum mai
   * utilă cumpărătorului decât un chenar gol.
   */
  fallbackUrl?: string | null;
  title?: string;
  className?: string;
  /** Randează eager doar coperțile de deasupra pliului (prima linie din grilă). */
  eager?: boolean;
}

export function BookCover({ url, fallbackUrl, title, className, eager = false }: BookCoverProps) {
  const sources = [url, fallbackUrl].filter((s): s is string => !!s);
  const [failedCount, setFailed] = useState(0);
  const current = sources[failedCount];

  if (!current) {
    return <GeneratedCover title={title} className={className} />;
  }

  return (
    <img
      src={current}
      alt={title ?? ''}
      loading={eager ? 'eager' : 'lazy'}
      decoding="async"
      // Spre deosebire de Flutter Web, aici NU trecem coperțile Google Books
      // prin /books/cover-proxy. Proxy-ul exista fiindcă CanvasKit desenează
      // imaginile din bytes obținuți cu fetch, deci supuși CORS, iar Google
      // Books nu trimite Access-Control-Allow-Origin. Un <img> obișnuit nu e
      // supus CORS pentru simpla afișare, deci URL-ul original merge direct -
      // o cerere mai puțin către API pentru fiecare copertă de pe ecran.
      onError={() => setFailed((n) => n + 1)}
      className={cn('h-full w-full rounded-[12px] object-cover', className)}
    />
  );
}

function GeneratedCover({ title, className }: { title?: string; className?: string }) {
  const [background, foreground] = coverHue(title ?? '');
  return (
    <div
      style={{ backgroundColor: background, color: foreground }}
      className={cn(
        'flex h-full w-full items-center justify-center rounded-[12px] p-3 text-center',
        className,
      )}
    >
      <span className="line-clamp-5 font-display text-sm font-bold leading-tight">
        {title ?? ''}
      </span>
    </div>
  );
}
