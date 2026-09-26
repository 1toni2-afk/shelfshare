import { Component, type ErrorInfo, type ReactNode } from 'react';
import { useTranslation } from 'react-i18next';
import { Link, useLocation, useRouteError } from 'react-router-dom';
import { TriangleAlert } from 'lucide-react';
import { Button } from '@/components/ui';
import { isChunkLoadError } from '@/lib/chunkReload';

/**
 * Ce vede omul când un ecran crapă la randare, în locul paginii albe cu
 * „Unexpected Application Error!" din React Router.
 *
 * Două niveluri:
 * - `ScreenErrorBoundary` stă în jurul fiecărui ecran (vezi `Screen` din
 *   router.tsx), deci în interiorul shell-ului: meniul și bara de sus rămân,
 *   doar zona ecranului e înlocuită, iar din meniu se poate pleca mai departe.
 * - `RouteErrorScreen` e `errorElement`-ul rutelor de sus - plasa pentru ce
 *   crapă în afara unui ecran (shell-ul însuși, gărzile de autentificare).
 *
 * Exemplul care a scos nevoia: o dată de eveniment citită din câmpul greșit
 * (`startsAt` în loc de `eventAt`) dărâma toată pagina unui grup.
 */
export function ErrorScreen({
  error,
  onRetry,
  fullScreen = false,
}: {
  error: unknown;
  onRetry: () => void;
  fullScreen?: boolean;
}) {
  const { t } = useTranslation();
  const details = describe(error);

  return (
    <div
      role="alert"
      className={
        fullScreen
          ? 'mx-auto flex min-h-dvh max-w-md flex-col items-center justify-center px-6 text-center'
          : 'mx-auto flex min-h-[60dvh] max-w-md flex-col items-center justify-center px-6 py-12 text-center'
      }
    >
      <span className="rounded-2xl bg-accent/15 p-4 text-accent">
        <TriangleAlert size={28} />
      </span>
      <h1 className="mt-4 font-display text-xl font-bold">{t('errorPageTitle')}</h1>
      <p className="mt-2 leading-relaxed text-muted-foreground">{t('errorPageBody')}</p>

      <div className="mt-6 flex flex-wrap justify-center gap-2">
        <Button className="px-5 py-3" onClick={onRetry}>
          {t('commonRetry')}
        </Button>
        {/* Link simplu, nu navigate(): dacă shell-ul e cel stricat, un
            reload complet pe Acasă e singurul drum sigur înapoi. */}
        <Link
          to="/"
          reloadDocument={fullScreen}
          className="inline-flex items-center rounded-[12px] border border-border px-5 py-3 text-[15px] font-bold transition hover:bg-muted"
        >
          {t('commonBackHome')}
        </Link>
      </div>

      {details && (
        <details className="mt-8 w-full text-left text-xs text-muted-foreground">
          <summary className="cursor-pointer text-center">{t('errorPageDetails')}</summary>
          <pre className="mt-2 overflow-x-auto whitespace-pre-wrap break-words rounded-[12px] bg-muted p-3">
            {details}
          </pre>
        </details>
      )}
    </div>
  );
}

function describe(error: unknown): string | null {
  if (error instanceof Error) return `${error.name}: ${error.message}`;
  if (typeof error === 'string') return error;
  if (error && typeof error === 'object' && 'statusText' in error) {
    return String((error as { status?: number; statusText: string }).status ?? '') + ' ' + String(error.statusText);
  }
  return null;
}

/** `errorElement` pentru rutele de sus. */
export function RouteErrorScreen() {
  const error = useRouteError();
  return <ErrorScreen error={error} fullScreen onRetry={() => window.location.reload()} />;
}

class Boundary extends Component<{ resetKey: string; children: ReactNode }, { error: unknown }> {
  state: { error: unknown } = { error: null };

  static getDerivedStateFromError(error: unknown) {
    return { error };
  }

  componentDidUpdate(previous: { resetKey: string }) {
    if (this.state.error !== null && previous.resetKey !== this.props.resetKey) {
      this.setState({ error: null });
    }
  }

  componentDidCatch(error: unknown, info: ErrorInfo) {
    console.error('Ecranul a crăpat la randare:', error, info.componentStack);
  }

  render() {
    if (this.state.error !== null) {
      // Un ecran care nu s-a putut descărca (build nou pe server) nu se
      // repară prin re-randare: același import ar cere același fișier lipsă.
      const retry = isChunkLoadError(this.state.error)
        ? () => window.location.reload()
        : () => this.setState({ error: null });
      return <ErrorScreen error={this.state.error} onRetry={retry} />;
    }
    return this.props.children;
  }
}

/**
 * Granița din jurul unui ecran. Orice navigare (inclusiv spre aceeași adresă,
 * ca „Înapoi la Acasă" apăsat de pe Acasă) șterge eroarea - altfel ea ar rămâne
 * afișată și după ce omul a plecat din meniu. Nu e `key`: o cheie pe
 * `location.key` ar remonta, la fiecare filtru pus în URL, și ecranele care
 * merg, pierzându-le starea.
 */
export function ScreenErrorBoundary({ children }: { children: ReactNode }) {
  const { key } = useLocation();
  return <Boundary resetKey={key}>{children}</Boundary>;
}
