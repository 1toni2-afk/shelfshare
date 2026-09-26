import { useRef, useState } from 'react';
import { useMutation, useQueryClient } from '@tanstack/react-query';
import { Link } from 'react-router-dom';
import { useTranslation } from 'react-i18next';
import { ScreenHeader } from '@/components/layout/ScreenHeader';
import {
  AlertCircle,
  BookOpen,
  CheckCircle2,
  Circle,
  Download,
  ExternalLink,
  HelpCircle,
  Heart,
  LibraryBig,
  MinusCircle,
  RefreshCw,
  Store,
  Upload,
} from 'lucide-react';
import { api } from '@/lib/api/client';
import { booksKeys } from './booksRepository';
import { shelfKeys } from '@/features/shelf/shelfRepository';
import {
  buildImportTemplateCsv,
  GOODREADS_EXPORT_URL,
  IMPORT_CONDITIONS,
  IMPORT_CSV_COLUMNS,
  IMPORT_TEMPLATE_FILENAME,
  STORYGRAPH_EXPORT_URL,
} from './importTemplate';
import { useCompleteOnboardingTodo } from '@/features/home/onboardingTodo';
import { Button } from '@/components/ui';
import { downloadTextFile } from '@/lib/utils/download';
import { cn } from '@/lib/utils/cn';

/** Un rând creat, actualizat sau scos din piață. */
interface ImportedListing {
  title: string;
  userBookId: string;
}

/** Un rând trimis pe raftul de lectură sau la favorite. */
interface ImportedShelved {
  title: string;
  shelf?: string;
}

interface ImportSkipped {
  title: string;
  shelf: string;
}

interface ImportFailed {
  title: string;
  reason: string;
}

/**
 * Rezultatul unui import de anunțuri, așa cum îl întoarce
 * `/books/import-listings`.
 *
 * `updated` și `delisted` există de când CSV-ul poate purta `sku`: un rând cu
 * sku deja cunoscut actualizează anunțul existent în loc să creeze încă unul,
 * iar `qty = 0` îl scoate din piață. Toate listele în afară de `failed` pot
 * lipsi dintr-un răspuns mai vechi, deci se citesc tolerant.
 */
interface ImportResult {
  created?: ImportedListing[];
  updated?: ImportedListing[];
  delisted?: ImportedListing[];
  shelved?: ImportedShelved[];
  favorited?: ImportedShelved[];
  skipped?: ImportSkipped[];
  failed?: ImportFailed[];
}

const GUIDELINES = ['ShelfRead', 'ShelfToRead', 'Listing', 'Skipped', 'NoDuplicates'] as const;

/**
 * Pagina de import, un singur loc pentru toate fișierele cu cărți: exportul de
 * pe Goodreads sau StoryGraph și șablonul propriu, pentru cine își ține
 * biblioteca într-un fișier de-al lui. Port al `import_screen.dart`.
 *
 * Toate rândurile trec prin `/books/import-listings` - singura cale care
 * citește rafturile din fișier și trimite fiecare rând unde-i e locul (raft de
 * lectură, favorite sau anunț), în loc să pună tot ce prinde în piață.
 * `/bookshelf/import/:source` a rămas doar pentru build-urile de Android deja
 * publicate.
 */
export function ImportScreen() {
  const { t } = useTranslation();
  const queryClient = useQueryClient();
  const fileInput = useRef<HTMLInputElement>(null);
  const completeTodo = useCompleteOnboardingTodo();

  const [file, setFile] = useState<File | null>(null);
  const [result, setResult] = useState<ImportResult | null>(null);
  const [error, setError] = useState<string | null>(null);

  const upload = useMutation({
    mutationFn: (csv: File) => {
      const form = new FormData();
      form.append('file', csv);
      return api.request<ImportResult>('/books/import-listings', {
        method: 'POST',
        formData: form,
        // Un fișier poate avea sute de rânduri, fiecare cu o căutare în
        // catalog: cele 10s implicite l-ar tăia la mijloc.
        timeoutMs: 60_000,
      });
    },
    onSuccess: (data) => {
      setResult(data);
      setError(null);
      // Importul atinge și raftul de lectură, și biblioteca de anunțuri.
      void queryClient.invalidateQueries({ queryKey: shelfKeys.bookshelf() });
      void queryClient.invalidateQueries({ queryKey: booksKeys.myLibrary() });
      // Bifează pasul din „Descoperă ShelfShare" doar dacă a intrat ceva - un
      // fișier gol sau greșit nu e un import făcut.
      if (touched(data) + (data.shelved?.length ?? 0) + (data.favorited?.length ?? 0) > 0) {
        completeTodo('import');
      }
    },
    onError: (cause: unknown) => {
      setResult(null);
      setError(messageOf(cause) ?? t('libraryImportError'));
    },
  });

  const header = <ScreenHeader title={t('importTitle')} back />;

  return (
    <div className="mx-auto w-full max-w-[720px] px-5 pb-16 pt-2 min-[900px]:px-8">
      {header}
      <p className="mb-5 whitespace-pre-line text-muted-foreground">{t('importIntro')}</p>

      <Step number={1} title={t('importStep1Title')}>
        <div className="flex flex-wrap gap-3">
          <ExternalButton href={GOODREADS_EXPORT_URL} label={t('importStep1Goodreads')} />
          <ExternalButton href={STORYGRAPH_EXPORT_URL} label={t('importStep1StoryGraph')} />
        </div>
        <Hint>{t('importStep1Hint')}</Hint>

        <hr className="my-5 border-border" />

        <button
          onClick={() =>
            downloadTextFile({
              filename: IMPORT_TEMPLATE_FILENAME,
              content: buildImportTemplateCsv(),
              mimeType: 'text/csv',
            })
          }
          className="inline-flex items-center gap-2 rounded-[12px] border border-border px-4 py-2.5 text-sm hover:bg-muted"
        >
          <Download size={18} />
          {t('importStep1Template')}
        </button>
        <Hint>{t('importStep1TemplateHint')}</Hint>
      </Step>

      <Step number={2} title={t('importStep2Title')}>
        <input
          ref={fileInput}
          type="file"
          accept=".csv,text/csv"
          hidden
          onChange={(event) => {
            const picked = event.target.files?.[0] ?? null;
            if (picked) {
              setFile(picked);
              // Un fișier nou înseamnă un import nou: rezultatul celui vechi
              // rămas pe ecran ar părea al acestuia.
              setResult(null);
              setError(null);
            }
            event.target.value = '';
          }}
        />
        <div className="flex flex-wrap items-center gap-3">
          <button
            onClick={() => fileInput.current?.click()}
            disabled={upload.isPending}
            className="inline-flex items-center gap-2 rounded-[12px] border border-border px-4 py-2.5 text-sm hover:bg-muted disabled:opacity-50"
          >
            <Upload size={18} />
            {t(file ? 'importStep2Change' : 'importStep2Choose')}
          </button>
          <span
            className={cn(
              'min-w-0 flex-1 truncate text-sm',
              file ? 'text-success' : 'text-muted-foreground',
            )}
          >
            {file?.name ?? t('importStep2NoFile')}
          </span>
        </div>
      </Step>

      <Step number={3} title={t('importStep3Title')}>
        <Button
          onClick={() => file && upload.mutate(file)}
          disabled={!file}
          loading={upload.isPending}
        >
          <LibraryBig size={18} />
          {t('importStep3Button')}
        </Button>
        {upload.isPending && <Hint>{t('importRunning')}</Hint>}
      </Step>

      {error && (
        <div className="mb-4 flex items-start gap-3 rounded-[16px] border border-danger-text/30 bg-danger-text/10 p-4 text-sm text-danger-text">
          <AlertCircle size={18} className="mt-0.5 shrink-0" />
          <span className="min-w-0 flex-1">{error}</span>
        </div>
      )}

      {result && <ImportResultCard result={result} />}

      <GuidelinesCard />
    </div>
  );
}

/** Câte rânduri au fost atinse în piață, oricum ar fi fost atinse. */
function touched(result: ImportResult): number {
  return (
    (result.created?.length ?? 0) + (result.updated?.length ?? 0) + (result.delisted?.length ?? 0)
  );
}

function ImportResultCard({ result }: { result: ImportResult }) {
  const { t } = useTranslation();

  const created = result.created ?? [];
  const updated = result.updated ?? [];
  const shelved = result.shelved ?? [];
  const favorited = result.favorited ?? [];
  const skipped = result.skipped ?? [];
  const failed = result.failed ?? [];

  const nothingHappened =
    touched(result) === 0 &&
    shelved.length === 0 &&
    favorited.length === 0 &&
    skipped.length === 0 &&
    failed.length === 0;

  return (
    <section className="mb-4 rounded-[16px] border border-border bg-card p-4">
      <div className="mb-3 flex items-center gap-2.5">
        <CheckCircle2 size={20} className="text-success" />
        <h2 className="font-bold">{t('importResultTitle')}</h2>
      </div>

      {nothingHappened ? (
        <p className="text-muted-foreground">{t('importResultEmpty')}</p>
      ) : (
        <div className="flex flex-wrap gap-2">
          {created.length > 0 && (
            <Chip
              icon={Store}
              tone="accent"
              label={t('importResultListed', { count: created.length })}
            />
          )}
          {updated.length > 0 && (
            <Chip
              icon={RefreshCw}
              tone="accent"
              label={t('importResultUpdated', { count: updated.length })}
            />
          )}
          {shelved.length > 0 && (
            <Chip
              icon={BookOpen}
              tone="primary"
              label={t('importResultShelved', { count: shelved.length })}
            />
          )}
          {favorited.length > 0 && (
            <Chip
              icon={Heart}
              tone="primary"
              label={t('importResultFavorited', { count: favorited.length })}
            />
          )}
          {skipped.length > 0 && (
            <Chip
              icon={MinusCircle}
              tone="warning"
              label={t('importResultSkipped', { count: skipped.length })}
            />
          )}
          {failed.length > 0 && (
            <Chip
              icon={AlertCircle}
              tone="danger"
              label={t('importResultFailed', { count: failed.length })}
            />
          )}
        </div>
      )}

      {skipped.length > 0 && (
        <Details
          title={t('importSkippedTitle')}
          rows={skipped.map((row) => [row.title, t('importSkippedShelf', { shelf: row.shelf })])}
        />
      )}
      {failed.length > 0 && (
        <Details
          title={t('libraryImportFailedTitle', { count: failed.length })}
          rows={failed.map((row) => [row.title, row.reason])}
        />
      )}

      {!nothingHappened && (
        <div className="mt-4 flex flex-wrap gap-2">
          {(shelved.length > 0 || favorited.length > 0) && (
            <Link
              to="/bookshelf"
              className="rounded-[12px] border border-border px-4 py-2.5 text-sm hover:bg-muted"
            >
              {t('importGoToShelf')}
            </Link>
          )}
          {touched(result) > 0 && (
            <Link
              to="/library"
              className="rounded-[12px] border border-border px-4 py-2.5 text-sm hover:bg-muted"
            >
              {t('importGoToLibrary')}
            </Link>
          )}
        </div>
      )}
    </section>
  );
}

/**
 * Regulile importului, pliate: cine vrea doar să încarce un export Goodreads
 * n-are nevoie să le citească, dar cine își scrie fișierul de mână trebuie să
 * le găsească fără să întrebe pe cineva.
 */
function GuidelinesCard() {
  const { t } = useTranslation();

  return (
    <details className="rounded-[16px] border border-border bg-card">
      <summary className="flex cursor-pointer list-none items-center gap-2.5 p-4 font-bold">
        <HelpCircle size={20} className="shrink-0 text-muted-foreground" />
        {t('importGuidelinesTitle')}
      </summary>
      <ul className="flex flex-col gap-2 px-5 pb-4 text-sm text-muted-foreground">
        {GUIDELINES.map((key) => (
          <Bullet key={key}>{t(`importGuideline${key}`)}</Bullet>
        ))}
        <hr className="my-2 border-border" />
        <Bullet>{t('importGuidelineColumns', { columns: IMPORT_CSV_COLUMNS.join(', ') })}</Bullet>
        <Bullet>
          {t('importGuidelineConditions', { conditions: IMPORT_CONDITIONS.join(', ') })}
        </Bullet>
        <Bullet>{t('importGuidelineLimit')}</Bullet>
      </ul>
    </details>
  );
}

/**
 * Un pas numerotat: cerc cu cifra, titlu, conținut. Numerele fac ordinea
 * evidentă fără să mai scriem „întâi", „apoi" în texte.
 */
function Step({
  number,
  title,
  children,
}: {
  number: number;
  title: string;
  children: React.ReactNode;
}) {
  return (
    <section className="mb-4 rounded-[16px] border border-border bg-card p-4">
      <div className="mb-3.5 flex items-center gap-2.5">
        <span className="flex size-[26px] shrink-0 items-center justify-center rounded-full bg-accent/15 text-[13px] font-bold text-accent">
          {number}
        </span>
        <h2 className="min-w-0 flex-1 font-bold">{title}</h2>
      </div>
      {children}
    </section>
  );
}

function ExternalButton({ href, label }: { href: string; label: string }) {
  return (
    <a
      href={href}
      target="_blank"
      rel="noreferrer noopener"
      className="inline-flex items-center gap-2 rounded-[12px] border border-border px-4 py-2.5 text-sm hover:bg-muted"
    >
      <ExternalLink size={18} />
      {label}
    </a>
  );
}

function Hint({ children }: { children: React.ReactNode }) {
  return <p className="mt-2 text-sm text-muted-foreground">{children}</p>;
}

function Bullet({ children }: { children: React.ReactNode }) {
  return (
    <li className="flex gap-2">
      <Circle size={6} className="mt-1.5 shrink-0 fill-accent text-accent" />
      <span className="min-w-0 flex-1">{children}</span>
    </li>
  );
}

const CHIP_TONES = {
  accent: 'bg-accent/[0.12] text-accent',
  primary: 'bg-primary/[0.12] text-primary',
  warning: 'bg-warning/[0.12] text-warning',
  danger: 'bg-danger-text/[0.12] text-danger-text',
} as const;

function Chip({
  icon: Icon,
  label,
  tone,
}: {
  icon: typeof Store;
  label: string;
  tone: keyof typeof CHIP_TONES;
}) {
  return (
    <span
      className={cn(
        'inline-flex items-center gap-1.5 rounded-full px-2.5 py-1.5 text-xs font-semibold',
        CHIP_TONES[tone],
      )}
    >
      <Icon size={15} />
      {label}
    </span>
  );
}

function Details({ title, rows }: { title: string; rows: Array<[string, string]> }) {
  return (
    <details className="mt-3">
      <summary className="cursor-pointer list-none py-2">{title}</summary>
      <ul className="pb-2">
        {rows.map(([label, detail], index) => (
          <li key={`${label}-${index}`} className="py-1">
            <p className="text-sm">{label}</p>
            <p className="text-xs text-muted-foreground">{detail}</p>
          </li>
        ))}
      </ul>
    </details>
  );
}

/**
 * Mesajul venit de la backend, dacă există. Erorile de validare ale Nest vin ca
 * listă de motive - fără concatenarea asta, userul ar vedea „[object Object]".
 */
function messageOf(cause: unknown): string | null {
  const data = (cause as { data?: { message?: unknown } } | null)?.data;
  const message = data?.message;
  if (Array.isArray(message)) return message.join(', ');
  if (typeof message === 'string' && message.trim()) return message;
  return null;
}
