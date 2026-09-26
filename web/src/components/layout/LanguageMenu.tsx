import { useEffect, useRef, useState } from 'react';
import { useTranslation } from 'react-i18next';
import { ChevronDown } from 'lucide-react';
import { setLocale, SUPPORTED_LOCALES, type AppLocale } from '@/lib/i18n';
import { cn } from '@/lib/utils/cn';

const LOCALE_NAMES: Record<AppLocale, string> = {
  ro: 'Română',
  en: 'English',
  de: 'Deutsch',
  hu: 'Magyar',
};

/**
 * Limba curentă scrisă scurt („RO"), cu un meniu cu celelalte limbi. Pentru
 * vizitatorul fără cont, care n-are Setările la îndemână.
 *
 * Coduri de limbă, nu steaguri: pe Windows emoji-urile de steag apar tot ca
 * „RO"/„EU", în două litere pe un fundal gri.
 */
export function LanguageMenu({ className }: { className?: string }) {
  const { t, i18n } = useTranslation();
  const [open, setOpen] = useState(false);
  const rootRef = useRef<HTMLDivElement>(null);
  const current = (SUPPORTED_LOCALES as string[]).includes(i18n.language)
    ? (i18n.language as AppLocale)
    : 'ro';

  useEffect(() => {
    if (!open) return;
    const onPointer = (event: PointerEvent) => {
      if (!rootRef.current?.contains(event.target as Node)) setOpen(false);
    };
    const onKey = (event: KeyboardEvent) => {
      if (event.key === 'Escape') setOpen(false);
    };
    document.addEventListener('pointerdown', onPointer);
    window.addEventListener('keydown', onKey);
    return () => {
      document.removeEventListener('pointerdown', onPointer);
      window.removeEventListener('keydown', onKey);
    };
  }, [open]);

  return (
    <div ref={rootRef} className={cn('relative', className)}>
      <button
        onClick={() => setOpen((value) => !value)}
        aria-haspopup="menu"
        aria-expanded={open}
        aria-label={t('profileLanguage')}
        title={t('profileLanguage')}
        className="flex items-center gap-1 rounded-full px-3 py-2 text-sm font-bold hover:bg-muted"
      >
        {current.toUpperCase()}
        <ChevronDown size={16} className={cn('transition', open && 'rotate-180')} />
      </button>

      {open && (
        <div
          role="menu"
          className="absolute right-0 top-full z-40 mt-1 min-w-[160px] overflow-hidden rounded-[12px] border border-border bg-card py-1 shadow-xl"
        >
          {SUPPORTED_LOCALES.filter((locale) => locale !== current).map((locale) => (
            <button
              key={locale}
              role="menuitem"
              onClick={() => {
                setOpen(false);
                void setLocale(locale as AppLocale);
              }}
              className="flex w-full items-center gap-3 px-4 py-2.5 text-left text-sm hover:bg-muted"
            >
              <span className="w-6 font-bold text-accent">{locale.toUpperCase()}</span>
              <span>{LOCALE_NAMES[locale as AppLocale]}</span>
            </button>
          ))}
        </div>
      )}
    </div>
  );
}
