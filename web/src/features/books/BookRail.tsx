import { Link } from 'react-router-dom';
import { useTranslation } from 'react-i18next';
import { BookCard } from './BookCard';
import { Spinner } from '@/components/ui';
import type { UserBook } from '@/types/models';

/** Lățimea unui card în carusel și înălțimea rândului, ca în Flutter. */
const CARD_WIDTH = 150;
const RAIL_HEIGHT = 290;

/**
 * O secțiune tematică din feed: titlu colorat, iconiță, „Vezi toate" și un
 * rând orizontal de carduri, peste o bandă de culoare.
 *
 * Banda traversează toată lățimea feedului și NU are margine verticală: atinge
 * grilele de deasupra și de dedesubt, iar tenta se stinge treptat în ele.
 * O margine ar lăsa o linie curată de despărțire - exact chenarul fix pe care
 * degradeul îl înlocuiește.
 *
 * Zonele de tranziție ocupă primii și ultimii ~40% din înălțime - deliberat
 * foarte lungi: un fade scurt s-ar citi tot ca o margine, doar una neclară.
 * Tenta e plină doar pe o fâșie îngustă la mijloc, în dreptul titlului și al
 * cardurilor, și se stinge complet înainte să atingă secțiunea următoare.
 */
export function BookRail({
  title,
  items,
  loading = false,
  seeAllHref,
  icon,
  tone = 'accent',
  stacked = false,
}: {
  title: string;
  items: UserBook[] | undefined;
  loading?: boolean;
  seeAllHref?: string;
  icon?: React.ReactNode;
  /** Culoarea benzii și a titlului. */
  tone?: 'accent' | 'primary';
  /**
   * Secțiuni puse direct una sub alta (Descoperă), fără grile între ele.
   * Marginea lungă de 48px e gândită să se stingă într-o grilă vecină; între
   * două benzi se aduna la ~100px de gol între categorii.
   */
  stacked?: boolean;
}) {
  const { t } = useTranslation();

  // Secțiunea dispare complet când e goală, nu afișează „nimic aici". Pe
  // Descoperă sunt opt secțiuni, iar pentru un cont nou jumătate sunt goale -
  // opt casete goale una sub alta arată ca un ecran stricat.
  if (!loading && (!items || items.length === 0)) return null;

  const color = tone === 'accent' ? 'var(--ss-accent)' : 'var(--ss-primary)';

  return (
    <section
      // `-mx-4`: banda iese din padding-ul paginii (`px-4` pe Home și pe
      // Descoperă) ca să atingă marginile feedului. Trebuie să fie EXACT cât
      // padding-ul: cu mai mult, banda depășea ecranul și pagina se putea
      // trage lateral.
      className={stacked ? '-mx-4 py-5' : '-mx-4 py-12'}
      style={{
        backgroundImage: `linear-gradient(to bottom,
          color-mix(in srgb, ${color} 0%, transparent) 0%,
          color-mix(in srgb, ${color} 4%, transparent) 20%,
          color-mix(in srgb, ${color} 10%, transparent) 42%,
          color-mix(in srgb, ${color} 10%, transparent) 58%,
          color-mix(in srgb, ${color} 4%, transparent) 80%,
          color-mix(in srgb, ${color} 0%, transparent) 100%)`,
      }}
    >
      <div className="mb-2 flex items-center gap-2 px-4">
        <span className="shrink-0" style={{ color }}>
          {icon}
        </span>
        <h2 className="min-w-0 flex-1 truncate font-display text-xl font-bold" style={{ color }}>
          {title}
        </h2>
        {seeAllHref && (
          <Link
            to={seeAllHref}
            className="shrink-0 rounded-[12px] px-3 py-2 text-sm font-medium hover:bg-foreground/5"
          >
            {t('homeSeeAll')}
          </Link>
        )}
      </div>

      {loading ? (
        <div className="flex items-center px-4 text-accent" style={{ height: RAIL_HEIGHT }}>
          <Spinner size={22} />
        </div>
      ) : (
        <div
          className="rail-scroll flex snap-x snap-mandatory scroll-px-4 gap-4 overflow-x-auto px-4 pb-2"
          style={{ minHeight: RAIL_HEIGHT }}
        >
          {items?.map((item, index) => (
            <div
              key={item.id}
              className="shrink-0 snap-start"
              style={{ width: CARD_WIDTH }}
            >
              <BookCard item={item} eager={index < 4} />
            </div>
          ))}
        </div>
      )}
    </section>
  );
}
