/**
 * Steagurile României și ale Uniunii Europene, desenate ca SVG.
 *
 * De ce nu emoji: `🇷🇴` și `🇪🇺` sunt perechi de „regional indicator", iar
 * Windows nu are glifele de steag în fontul de emoji - Chrome pe Windows
 * afișează literele `RO` și `EU`, nu steagurile. Pe Android și iOS se vedeau
 * corect, deci defectul trecea neobservat exact pe platforma de pe care se
 * uită cei mai mulți la site.
 *
 * Proporția e cea oficială, 2:3, iar stelele UE sunt calculate, nu desenate
 * de mână: douăsprezece, la fiecare 30°, pe un cerc cu raza cât o treime din
 * înălțime - exact specificația drapelului.
 */

/** Raza cercului pe care stau stelele: o treime din înălțimea drapelului. */
const STAR_RING_RADIUS = 20 / 3;
/** Raza cercului în care se înscrie o stea: a optsprezecea parte din înălțime. */
const STAR_RADIUS = 20 / 9 / 2;

/** Punctele unei stele cu cinci colțuri, cu vârful în sus. */
function starPoints(cx: number, cy: number, outer: number): string {
  const inner = outer * 0.382; // raportul clasic al pentagramei
  const points: string[] = [];
  for (let i = 0; i < 10; i++) {
    const radius = i % 2 === 0 ? outer : inner;
    const angle = (Math.PI / 5) * i - Math.PI / 2;
    points.push(
      `${(cx + radius * Math.cos(angle)).toFixed(3)},${(cy + radius * Math.sin(angle)).toFixed(3)}`,
    );
  }
  return points.join(' ');
}

interface FlagProps {
  /** Numele țării/uniunii, pentru cititoarele de ecran. */
  title: string;
  className?: string;
}

/**
 * `role="img"` + `<title>`: steagul e conținut, nu decor - „Made with ❤️ in
 * Transylvania" fără el s-ar citi fără să se știe despre ce țară e vorba.
 */
export function RomanianFlag({ title, className }: FlagProps) {
  return (
    <svg
      viewBox="0 0 30 20"
      role="img"
      aria-label={title}
      className={className ?? 'inline-block h-[0.9em] w-auto rounded-[1px] align-[-0.1em]'}
    >
      <rect width="10" height="20" fill="#002B7F" />
      <rect x="10" width="10" height="20" fill="#FCD116" />
      <rect x="20" width="10" height="20" fill="#CE1126" />
    </svg>
  );
}

export function EuropeanFlag({ title, className }: FlagProps) {
  const stars = Array.from({ length: 12 }, (_, i) => {
    const angle = (Math.PI / 6) * i - Math.PI / 2;
    return starPoints(
      15 + STAR_RING_RADIUS * Math.cos(angle),
      10 + STAR_RING_RADIUS * Math.sin(angle),
      STAR_RADIUS,
    );
  });

  return (
    <svg
      viewBox="0 0 30 20"
      role="img"
      aria-label={title}
      className={className ?? 'inline-block h-[0.9em] w-auto rounded-[1px] align-[-0.1em]'}
    >
      <rect width="30" height="20" fill="#003399" />
      {stars.map((points) => (
        <polygon key={points} points={points} fill="#FFCC00" />
      ))}
    </svg>
  );
}
