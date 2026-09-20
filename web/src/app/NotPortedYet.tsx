import { Link } from 'react-router-dom';
import { Construction } from 'lucide-react';

/**
 * Marcaj vizibil pentru ecranele care încă nu sunt mutate din Flutter.
 *
 * Există ca să se poată deosebi, pe beta, „încă n-am ajuns aici" de „e stricat".
 * Fără el, orice rută neportată ar cădea pe 404, iar cine testează ar raporta
 * zeci de bug-uri inexistente. Dispare complet la paritate.
 */
export function NotPortedYet({ name, notFound = false }: { name: string; notFound?: boolean }) {
  return (
    <div className="mx-auto flex min-h-dvh max-w-md flex-col items-center justify-center gap-4 px-6 text-center">
      <span className="rounded-2xl bg-muted p-4 text-muted-foreground">
        <Construction size={28} />
      </span>
      <h1 className="font-display text-xl font-bold">{name}</h1>
      <p className="text-muted-foreground">
        {notFound
          ? 'Adresa asta nu există.'
          : 'Ecranul nu e încă mutat pe noul frontend. Pe shelfshare.ro funcționează normal.'}
      </p>
      <Link to="/" className="text-accent hover:underline">
        Înapoi la Acasă
      </Link>
    </div>
  );
}
