import logoMark from '@/assets/brand/logo-mark.png';
import { cn } from '@/lib/utils/cn';

/**
 * Iconița aplicației (cartea portocalie pe pătratul închis), aceeași ca pe
 * telefon și în favicon. Importată prin Vite, deci numele fișierului primește
 * hash - un logo schimbat nu rămâne blocat în cache.
 */
export function BrandMark({ size, className }: { size: number; className?: string }) {
  return (
    <img
      src={logoMark}
      alt=""
      width={size}
      height={size}
      draggable={false}
      className={cn('shrink-0 select-none', className)}
    />
  );
}
