import { useState } from 'react';
import { useTranslation } from 'react-i18next';
import {
  ArrowRight,
  Compass,
  Crown,
  Heart,
  Languages,
  Library,
  Lock,
  Medal,
  MessageSquareHeart,
  Repeat,
  Rocket,
  Shapes,
  ShieldCheck,
  Sparkles,
  Sprout,
  Trophy,
  X,
  type LucideIcon,
} from 'lucide-react';
import { cn } from '@/lib/utils/cn';
import type { Achievement } from '@/types/models';

/** Iconița fiecărei insigne. O cheie necunoscută (insignă nouă) primește trofeul. */
const BADGE_ICONS: Record<string, LucideIcon> = {
  first_swap: Sprout,
  ten_swaps: Repeat,
  fifty_swaps: Medal,
  collector: Library,
  trusted_member: ShieldCheck,
  early_adopter: Rocket,
  genre_master: Shapes,
  community_helper: MessageSquareHeart,
  explorer: Compass,
  fantasy_collector: Sparkles,
  top_swapper: Crown,
  book_explorer: Languages,
  supporter: Heart,
};

/** `first_swap` → `badgeFirstSwap`, cheia de traducere. */
function i18nKey(key: string): string {
  return 'badge' + key.split('_').map((part) => part[0]!.toUpperCase() + part.slice(1)).join('');
}

function useBadgeText() {
  const { t, i18n } = useTranslation();
  return (badge: Achievement) => {
    const key = i18nKey(badge.key);
    // Fallback pe textul serverului: o insignă adăugată pe backend apare
    // imediat, în română, până primește traducere.
    return {
      label: i18n.exists(key) ? t(key) : badge.label,
      description: i18n.exists(`${key}Desc`) ? t(`${key}Desc`) : badge.description,
    };
  };
}

/** Hexagonul insignei - forma din machetă, desenată din CSS, nu dintr-o imagine. */
function BadgeHex({ badge, size = 56 }: { badge: Achievement; size?: number }) {
  const Icon = BADGE_ICONS[badge.key] ?? Trophy;
  return (
    <span
      className={cn(
        'flex shrink-0 items-center justify-center',
        badge.achieved ? 'bg-accent/20 text-accent' : 'bg-muted text-muted-foreground/60',
      )}
      style={{
        width: size,
        height: size * 1.1,
        clipPath: 'polygon(50% 0, 100% 25%, 100% 75%, 50% 100%, 0 75%, 0 25%)',
      }}
    >
      {badge.achieved ? <Icon size={size * 0.45} /> : <Lock size={size * 0.34} />}
    </span>
  );
}

/**
 * Cardul „Insigne" de pe profilul propriu: primele patru obținute, iar „Vezi
 * tot" deschide lista completă - și pe cele încă blocate, cu condiția fiecăreia,
 * ca să fie clar cum se câștigă.
 */
export function BadgesCard({ achievements }: { achievements: Achievement[] }) {
  const { t } = useTranslation();
  const text = useBadgeText();
  const [open, setOpen] = useState(false);

  if (achievements.length === 0) return null;
  const earned = achievements.filter((badge) => badge.achieved);

  return (
    <section className="rounded-[16px] border border-border bg-card p-4">
      <div className="flex items-baseline justify-between gap-3">
        <h2 className="font-display text-lg font-bold">{t('profileBadgesTitle')}</h2>
        <button
          onClick={() => setOpen(true)}
          className="flex items-center gap-1 text-sm font-medium text-accent hover:underline"
        >
          {t('commonSeeAll')}
          <ArrowRight size={14} />
        </button>
      </div>

      {earned.length === 0 ? (
        <p className="mt-2 text-[13px] text-muted-foreground">{t('profileBadgesEmpty')}</p>
      ) : (
        <ul className="mt-3 grid grid-cols-4 gap-2">
          {earned.slice(0, 4).map((badge) => {
            const { label, description } = text(badge);
            return (
              <li key={badge.key} title={description} className="flex flex-col items-center gap-1.5 text-center">
                <BadgeHex badge={badge} size={48} />
                <span className="text-xs leading-tight">{label}</span>
              </li>
            );
          })}
        </ul>
      )}

      {open && <BadgesDialog achievements={achievements} onClose={() => setOpen(false)} />}
    </section>
  );
}

function BadgesDialog({
  achievements,
  onClose,
}: {
  achievements: Achievement[];
  onClose: () => void;
}) {
  const { t } = useTranslation();
  const text = useBadgeText();
  const earned = achievements.filter((badge) => badge.achieved);
  const locked = achievements.filter((badge) => !badge.achieved);

  const list = (badges: Achievement[]) => (
    <ul className="flex flex-col gap-3">
      {badges.map((badge) => {
        const { label, description } = text(badge);
        return (
          <li key={badge.key} className="flex items-center gap-3">
            <BadgeHex badge={badge} size={40} />
            <div className="min-w-0">
              <p className={cn('font-semibold', !badge.achieved && 'text-muted-foreground')}>{label}</p>
              <p className="text-sm text-muted-foreground">{description}</p>
            </div>
          </li>
        );
      })}
    </ul>
  );

  return (
    <div role="dialog" aria-modal className="fixed inset-0 z-50 flex items-center justify-center p-5">
      <button aria-label={t('commonClose')} onClick={onClose} className="absolute inset-0 bg-black/50" />
      <div className="relative flex max-h-[80vh] w-full max-w-[480px] flex-col rounded-[20px] bg-card">
        <div className="flex items-center gap-3 border-b border-border p-5">
          <h2 className="flex-1 font-display text-lg font-bold">{t('profileBadgesTitle')}</h2>
          <button
            onClick={onClose}
            aria-label={t('commonClose')}
            className="rounded-md p-1.5 text-muted-foreground hover:bg-muted"
          >
            <X size={20} />
          </button>
        </div>
        <div className="flex flex-col gap-6 overflow-y-auto p-5">
          {earned.length > 0 && (
            <section>
              <h3 className="mb-3 text-sm font-semibold text-muted-foreground">
                {t('profileBadgesEarned', { count: earned.length })}
              </h3>
              {list(earned)}
            </section>
          )}
          {locked.length > 0 && (
            <section>
              <h3 className="mb-3 text-sm font-semibold text-muted-foreground">
                {t('profileBadgesLocked')}
              </h3>
              {list(locked)}
            </section>
          )}
        </div>
      </div>
    </div>
  );
}
