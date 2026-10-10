import { useMemo, useState } from 'react';
import { Field } from '@/components/ui';
import { ROMANIAN_CITIES } from '@/lib/constants/romanianCities';
import { cn } from '@/lib/utils/cn';

/** Câte sugestii afișăm sub câmp - destul cât să nu trebuiască derulat. */
const MAX_SUGGESTIONS = 6;

const fold = (value: string) =>
  value
    .normalize('NFD')
    .replace(/[̀-ͯ]/g, '')
    .toLowerCase();

const FOLDED = ROMANIAN_CITIES.map((city) => ({ city, folded: fold(city) }));

/**
 * Câmpul de oraș cu sugestii din lista orașelor din România.
 *
 * Backend-ul acceptă pe profil doar orașe din `ROMANIAN_CITIES`, deci un câmp
 * de text liber lăsa omul să scrie „Bucuresti" sau „Cluj" și afla abia la
 * salvare că a greșit, printr-un „Something went wrong" generic. Nu `<datalist>`:
 * în WebView-ul de Android sugestiile lui apar inconsecvent sau deloc.
 */
export function CityField({
  label,
  value,
  onChange,
  error,
  hint,
}: {
  label: string;
  value: string;
  onChange: (value: string) => void;
  error?: string | null;
  hint?: string;
}) {
  const [open, setOpen] = useState(false);

  const suggestions = useMemo(() => {
    const query = fold(value.trim());
    if (!query) return [];
    // Întâi cele care încep cu textul tastat, apoi cele care doar îl conțin.
    const starts = FOLDED.filter((c) => c.folded.startsWith(query));
    const contains = FOLDED.filter(
      (c) => !c.folded.startsWith(query) && c.folded.includes(query),
    );
    return [...starts, ...contains].slice(0, MAX_SUGGESTIONS).map((c) => c.city);
  }, [value]);

  // Nu mai arătăm lista când textul e deja exact un oraș din ea.
  const visible =
    open &&
    suggestions.length > 0 &&
    !(suggestions.length === 1 && suggestions[0] === value);

  return (
    <div className="relative">
      <Field
        label={label}
        name="city"
        autoComplete="off"
        value={value}
        error={error}
        hint={hint}
        role="combobox"
        aria-expanded={visible}
        aria-autocomplete="list"
        onChange={(event) => {
          onChange(event.target.value);
          setOpen(true);
        }}
        onFocus={() => setOpen(true)}
        // Întârziat, altfel blur-ul închide lista înainte să ajungă click-ul
        // pe sugestie.
        onBlur={() => setTimeout(() => setOpen(false), 150)}
      />
      {visible && (
        <ul
          role="listbox"
          className="absolute inset-x-0 z-20 mt-1 overflow-hidden rounded-[16px] border border-border bg-card shadow-lg"
        >
          {suggestions.map((city) => (
            <li key={city} role="option" aria-selected={city === value}>
              <button
                type="button"
                // `onMouseDown` + preventDefault: inputul nu pierde focusul,
                // deci tastatura de pe telefon nu se închide și redeschide.
                onMouseDown={(event) => event.preventDefault()}
                onClick={() => {
                  onChange(city);
                  setOpen(false);
                }}
                className={cn(
                  'block w-full px-4 py-3 text-left hover:bg-muted',
                  city === value && 'font-semibold',
                )}
              >
                {city}
              </button>
            </li>
          ))}
        </ul>
      )}
    </div>
  );
}
