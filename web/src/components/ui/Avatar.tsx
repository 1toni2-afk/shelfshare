import { cn } from '@/lib/utils/cn';

/**
 * Avatar rotund cu inițiala ca rezervă. Folosit peste tot unde apare un user
 * (sidebar, conversații, profiluri, participanți la grup).
 */
export function Avatar({
  src,
  name,
  size = 40,
  className,
}: {
  src?: string | null;
  name?: string | null;
  size?: number;
  className?: string;
}) {
  const initial = (name ?? '').trim().charAt(0).toUpperCase() || '?';

  return (
    <div
      style={{ width: size, height: size, fontSize: Math.max(11, size * 0.4) }}
      className={cn(
        'flex shrink-0 items-center justify-center overflow-hidden rounded-full bg-muted font-bold text-muted-foreground',
        className,
      )}
    >
      {src ? (
        <img src={src} alt="" loading="lazy" className="h-full w-full object-cover" />
      ) : (
        initial
      )}
    </div>
  );
}
