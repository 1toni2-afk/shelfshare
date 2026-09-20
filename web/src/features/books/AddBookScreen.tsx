import { useEffect, useRef, useState, type FormEvent } from 'react';
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { useNavigate } from 'react-router-dom';
import { useTranslation } from 'react-i18next';
import { ScreenHeader } from '@/components/layout/ScreenHeader';
import { BookOpen, Camera, Search, Star, Store, X } from 'lucide-react';
import {
  booksKeys,
  booksRepository,
  type ExternalBookResult,
} from './booksRepository';
import { BookCover } from '@/components/ui/BookCover';
import { Button, ErrorNotice, Field, Spinner } from '@/components/ui';
import { shelfKeys, shelfRepository } from '@/features/shelf/shelfRepository';
import { Switch } from '@/components/ui/Switch';
import { useToast } from '@/components/ui/Toast';
import { useAuth } from '@/features/auth/AuthProvider';
import { cn } from '@/lib/utils/cn';

type ListingMode = 'swap' | 'sale' | 'donation';

/**
 * Ce se întâmplă cu cartea adăugată.
 *
 * Ecranul crea până acum DOAR anunțuri, deci o carte pe care vrei doar s-o
 * citești ajungea automat în piață. Cele două destinații sunt fluxuri
 * diferite, cu endpointuri diferite (`/books` vs `/bookshelf/own`), nu un
 * comutator cosmetic - de-aia raftul ascunde tot ce ține de anunț.
 *
 * Implicit „raft", ca în varianta publică: e alegerea nevinovată. Dacă
 * greșești, cartea rămâne privată, nu apare din greșeală în piață.
 */
type Destination = 'shelf' | 'listing';

const CONDITIONS = [
  { value: 'NOUA', labelKey: 'bookConditionNew' },
  { value: 'FOARTE_BUNA', labelKey: 'bookConditionVeryGood' },
  { value: 'BUNA', labelKey: 'bookConditionGood' },
  { value: 'ACCEPTABILA', labelKey: 'bookConditionAcceptable' },
] as const;

const MAX_TAGS = 5;

/** `_maxPhotos` din add_book_screen.dart. */
const MAX_PHOTOS = 5;

/** O poză aleasă, cu URL-ul ei de previzualizare (revocat la ștergere). */
interface PickedPhoto {
  file: File;
  preview: string;
}

/**
 * Limita e a BACKENDULUI (`@MaxLength(256)` pe AddBookDto), nu o alegere de
 * interfață. Pusă mai mare aici, userul ar putea scrie liniștit 1000 de
 * caractere și ar afla abia la salvare că nu se poate - cu tot formularul de
 * recompletat.
 */
const MAX_DESCRIPTION = 256;

/**
 * Adăugarea unei cărți în bibliotecă. Port al părții esențiale din
 * add_book_screen.dart (2439 de linii acolo).
 *
 * Fluxul e în doi pași pentru un motiv de API, nu estetic: `POST /books`
 * creează anunțul, dar prețul de vânzare și pozele se pun DUPĂ, pe anunțul
 * creat (`PATCH /books/:id`, `POST /books/:id/photos`) - au nevoie de id-ul
 * lui. De aceea „eșec parțial" e o stare reală: cartea poate fi creată, iar
 * poza să nu urce.
 *
 * Scanarea codului de bare cu camera nu e portată încă - pe web ar cere o
 * bibliotecă separată; căutarea după ISBN tastat acoperă același rezultat.
 */
export function AddBookScreen() {
  const { t } = useTranslation();
  const { user } = useAuth();
  const navigate = useNavigate();
  const queryClient = useQueryClient();
  const toast = useToast();

  const [term, setTerm] = useState('');
  const [query, setQuery] = useState('');
  const [picked, setPicked] = useState<ExternalBookResult | null>(null);

  // Câmpurile formularului. Precompletate din rezultatul ales, dar editabile:
  // datele externe sunt adesea incomplete sau greșite.
  const [title, setTitle] = useState('');
  const [author, setAuthor] = useState('');
  const [publisher, setPublisher] = useState('');
  const [publishedYear, setPublishedYear] = useState('');
  const [pageCount, setPageCount] = useState('');
  const [genre, setGenre] = useState('');
  const [description, setDescription] = useState('');
  const [condition, setCondition] = useState<string>('BUNA');
  const [isHardcover, setIsHardcover] = useState(false);
  const [city, setCity] = useState(user?.city ?? '');
  const [tags, setTags] = useState<string[]>([]);
  const [tagDraft, setTagDraft] = useState('');

  const [destination, setDestination] = useState<Destination>('shelf');
  const [mode, setMode] = useState<ListingMode>('swap');
  const [price, setPrice] = useState('');
  const [isNegotiable, setIsNegotiable] = useState(true);

  const [photos, setPhotos] = useState<PickedPhoto[]>([]);
  const [mainPhotoIndex, setMainPhotoIndex] = useState<number | null>(null);
  const [dragging, setDragging] = useState(false);
  const fileInput = useRef<HTMLInputElement>(null);

  // Fiecare `createObjectURL` ține fișierul în memorie până e revocat.
  useEffect(() => {
    return () => {
      for (const item of photos) URL.revokeObjectURL(item.preview);
    };
    // Dinadins fără dependențe: curățăm o singură dată, la ieșirea din ecran.
    // Ștergerea unei poze își revocă propriul URL pe loc.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  const [error, setError] = useState<string | null>(null);

  /*
    Sugestiile apar pe MĂSURĂ ce scrii, nu doar după Enter.

    Până acum căutarea pornea exclusiv din `onSubmit`-ul formularului, deci pe
    telefon - unde tastatura n-are un Enter evident și nimeni nu se gândește să
    trimită un câmp de căutare - autocompletarea părea pur și simplu că nu
    funcționează. Enter rămâne, ca scurtătură care sare peste așteptare.

    350ms: destul cât să nu trimitem o cerere pe literă, destul de puțin cât
    lista să pară că vine singură.
  */
  useEffect(() => {
    const trimmed = term.trim();
    if (trimmed === query) return;
    const timer = window.setTimeout(() => setQuery(trimmed), 350);
    return () => window.clearTimeout(timer);
  }, [term, query]);

  const results = useQuery({
    queryKey: ['books', 'search', query],
    queryFn: ({ signal }) => booksRepository.search(query, signal),
    enabled: query.length > 2,
  });

  const genres = useQuery({
    queryKey: booksKeys.genres(),
    queryFn: ({ signal }) => booksRepository.getGenres(signal),
    staleTime: 60 * 60 * 1000,
  });

  function choose(result: ExternalBookResult) {
    setPicked(result);
    setTitle(result.title ?? '');
    setAuthor(result.author ?? '');
    setPublisher(result.publisher ?? '');
    setPublishedYear(result.publishedYear ? String(result.publishedYear) : '');
    setPageCount(result.pageCount ? String(result.pageCount) : '');
    setGenre(result.genre ?? '');
    setDescription(result.description ?? '');
  }

  /** Primește un TABLOU de fișiere, nu un `FileList` - vezi handler-ul. */
  function pickPhotos(files: readonly File[]) {
    if (files.length === 0) return;
    setPhotos((current) => {
      const room = MAX_PHOTOS - current.length;
      if (room <= 0) return current;
      const added = files
        .filter((file) => file.type.startsWith('image/'))
        .slice(0, room)
        .map((file) => ({ file, preview: URL.createObjectURL(file) }));
      return [...current, ...added];
    });
  }

  function removePhoto(index: number) {
    setPhotos((current) => {
      URL.revokeObjectURL(current[index].preview);
      return current.filter((_, position) => position !== index);
    });
    // Indexul poziției principale se mută odată cu lista, altfel steaua ar
    // sări pe altă poză după o ștergere.
    setMainPhotoIndex((current) => {
      if (current === null) return null;
      if (current === index) return null;
      return current > index ? current - 1 : current;
    });
  }

  const submit = useMutation({
    mutationFn: async () => {
      // Raftul e un drum complet separat: un singur apel, fără poze, preț sau
      // pașii de după creare. Întoarce cartea din catalog, nu un anunț.
      if (destination === 'shelf') {
        const book = await shelfRepository.addOwned({
          title: title.trim(),
          author: author.trim() || undefined,
          isbn: picked?.isbn ?? undefined,
          coverUrl: picked?.coverUrl ?? undefined,
          genre: genre || undefined,
          publisher: publisher.trim() || undefined,
          publishedYear: publishedYear ? Number(publishedYear) : undefined,
          totalPages: pageCount ? Number(pageCount) : undefined,
        });
        return { shelfBook: book, created: null, problems: [] as string[] };
      }

      const created = await booksRepository.addToLibrary({
        bookId: picked?.id,
        isbn: picked?.isbn ?? undefined,
        title: title.trim(),
        author: author.trim() || undefined,
        publisher: publisher.trim() || undefined,
        publishedYear: publishedYear ? Number(publishedYear) : undefined,
        pageCount: pageCount ? Number(pageCount) : undefined,
        genre: genre || undefined,
        description: description.trim() || undefined,
        condition,
        isHardcover,
        city: city.trim() || undefined,
        tags,
        mainPhotoUrl: picked?.coverUrl ?? undefined,
      });

      // Pasul doi: prețul și poza, pe anunțul deja creat. Eșecurile de aici
      // NU pierd cartea - de-asta sunt raportate separat, ca „a mers pe
      // jumătate", nu ca „n-a mers".
      const problems: string[] = [];

      if (mode === 'sale') {
        try {
          await booksRepository.markForSale(created.id, Number(price), isNegotiable);
        } catch {
          problems.push('price');
        }
      }

      // Pozele urcă una câte una; reținem URL-urile ca să putem marca apoi
      // poza principală aleasă de user.
      const uploaded: Array<string | undefined> = [];
      for (const item of photos) {
        try {
          const result = await booksRepository.addPhoto(created.id, item.file);
          uploaded.push(result.photoUrl);
        } catch {
          uploaded.push(undefined);
          problems.push('photo');
        }
      }

      // O poză bifată ca principală bate coperta externă aleasă la căutare.
      const main = mainPhotoIndex !== null ? uploaded[mainPhotoIndex] : undefined;
      if (main) {
        try {
          await booksRepository.setMainPhoto(created.id, main);
        } catch {
          problems.push('photo');
        }
      }

      return { shelfBook: null, created, problems };
    },
    onSuccess: ({ shelfBook, created, problems }) => {
      if (shelfBook) {
        // Raftul, nu biblioteca de anunțuri: alte liste, altă destinație.
        void queryClient.invalidateQueries({ queryKey: shelfKeys.all });
        toast.show(t('shelfAddedToShelf'));
        void navigate('/bookshelf');
        return;
      }
      void queryClient.invalidateQueries({ queryKey: booksKeys.myLibrary() });
      toast.show(problems.length > 0 ? t('addBookPartialError') : t('addBookSuccess'));
      void navigate(`/books/${created!.id}`);
    },
    onError: () => toast.show(t('addBookGenericError'), 'danger'),
  });

  function onSubmit(event: FormEvent) {
    event.preventDefault();

    if (!title.trim()) {
      setError(t('addBookTitleRequired'));
      return;
    }
    // `Number('')` dă 0, deci verificăm și șirul gol: un anunț de vânzare
    // trimis fără preț s-ar salva la 0 lei.
    if (destination === 'listing' && mode === 'sale' && (!price.trim() || !(Number(price) > 0))) {
      setError(t('addBookInvalidPrice'));
      return;
    }
    setError(null);
    submit.mutate();
  }

  function addTag() {
    const value = tagDraft.trim();
    if (!value) return;
    if (tags.length >= MAX_TAGS) {
      toast.show(t('shareMaxTagsReached'));
      return;
    }
    if (!tags.includes(value)) setTags([...tags, value]);
    setTagDraft('');
  }

  const header = (
    <ScreenHeader
      title={t(destination === 'shelf' ? 'shelfAddModeShelf' : 'shelfAddModeListing')}
      back="/library"
    />
  );

  const DESTINATIONS = [
    {
      value: 'shelf' as const,
      icon: BookOpen,
      label: t('shelfAddModeShelf'),
      hint: t('shelfAddModeShelfHint'),
    },
    {
      value: 'listing' as const,
      icon: Store,
      label: t('shelfAddModeListing'),
      hint: t('shelfAddModeListingHint'),
    },
  ];

  return (
    <div className="mx-auto w-full max-w-[680px] px-5 pb-16 pt-2 min-[900px]:px-8">
      {header}

      {/*
        Prima întrebare, înaintea oricărui câmp: ce se întâmplă cu cartea.
        Pusă la sfârșit, ar fi o surpriză după un formular completat; pusă
        aici, decide ce câmpuri are rost să vezi.
      */}
      <fieldset className="mb-5 border-0 p-0">
        <legend className="mb-2 px-0 text-sm font-medium text-muted-foreground">
          {t('shelfAddModeQuestion')}
        </legend>
        <div className="flex flex-col gap-2">
          {DESTINATIONS.map((option) => {
            const Icon = option.icon;
            const active = destination === option.value;
            return (
              <button
                key={option.value}
                type="button"
                aria-pressed={active}
                onClick={() => setDestination(option.value)}
                className={cn(
                  'flex w-full items-start gap-3 rounded-[16px] border p-4 text-left transition',
                  active ? 'border-accent bg-accent/10' : 'border-border hover:bg-muted',
                )}
              >
                <Icon
                  size={22}
                  className={cn('mt-0.5 shrink-0', active ? 'text-accent' : 'text-muted-foreground')}
                />
                <span className="min-w-0">
                  <span className="block font-bold">{option.label}</span>
                  <span className="block text-sm text-muted-foreground">{option.hint}</span>
                </span>
              </button>
            );
          })}
        </div>
      </fieldset>

      {/*
        Poza stă SUS și e mare dinadins: e primul lucru pe care îl are omul la
        îndemână (cartea e în mâna lui), iar un anunț cu poză reală arată cu
        totul altfel decât unul doar cu coperta din catalog. Ca buton mic la
        coada formularului era de fapt sărit.

        Aceleași reguli ca în `_PhotoPicker` din add_book_screen.dart: maximum
        cinci poze, contorul pe zonă, steaua care marchează poza principală.
      */}
      {/* Pozele aparțin ANUNȚULUI. O carte pusă doar în raft n-o vede
          nimeni altcineva, deci nu are de ce să fie fotografiată. */}
      {destination === 'listing' && (
        <>
      <input
        ref={fileInput}
        type="file"
        accept="image/*"
        multiple
        hidden
        onChange={(event) => {
          /*
            Copiem lista ACUM, sincron, înainte de resetare.

            `input.value = ''` golește chiar obiectul `FileList` întors de
            `input.files` - e viu, nu o copie. `pickPhotos` citea lista
            înăuntrul unui updater de state, care rulează abia la următoarea
            randare, deci găsea lista deja goală: nicio poză nu se atașa
            vreodată de pe buton. Mergea doar prin drag & drop, care nu
            resetează nimic - adică pe telefon nu mergea deloc.
          */
          const files = Array.from(event.target.files ?? []);
          // Resetarea rămâne: fără ea, aceeași poză aleasă a doua oară nu mai
          // declanșează `change`, fiindcă valoarea câmpului nu s-a schimbat.
          event.target.value = '';
          pickPhotos(files);
        }}
      />

      <button
        type="button"
        onClick={() => fileInput.current?.click()}
        disabled={photos.length >= MAX_PHOTOS}
        // Drag & drop pe desktop: zona e oricum mare, iar o poză trasă peste ea
        // e gestul evident. Pe telefon nu se schimbă nimic.
        onDragOver={(event) => {
          event.preventDefault();
          setDragging(true);
        }}
        onDragLeave={() => setDragging(false)}
        onDrop={(event) => {
          event.preventDefault();
          setDragging(false);
          pickPhotos(Array.from(event.dataTransfer.files));
        }}
        className={cn(
          'flex h-40 w-full flex-col items-center justify-center gap-1.5 rounded-[12px] border text-center transition',
          photos.length >= MAX_PHOTOS
            ? 'cursor-not-allowed border-border bg-muted opacity-60'
            : dragging
              ? 'border-accent bg-accent/10'
              : 'border-border bg-muted hover:bg-muted/70',
        )}
      >
        <Camera size={42} className="text-muted-foreground" />
        <span className="font-display text-lg font-bold">{t('shareAddPhotos')}</span>
        <span className="text-xs text-muted-foreground">
          {photos.length} / {MAX_PHOTOS}
        </span>
      </button>

      {photos.length > 0 && (
        <>
          <ul className="mt-3 flex gap-2 overflow-x-auto pb-1">
            {photos.map((item, index) => (
              <li key={item.preview} className="relative size-20 shrink-0">
                <img
                  src={item.preview}
                  alt=""
                  className="size-20 rounded-lg object-cover"
                />
                <button
                  type="button"
                  onClick={() => removePhoto(index)}
                  aria-label={t('profileFeedbackRemovePhoto')}
                  className="absolute right-0 top-0 rounded-xl bg-destructive p-0.5 text-white"
                >
                  <X size={14} />
                </button>
                <button
                  type="button"
                  onClick={() => setMainPhotoIndex(index)}
                  aria-label={t('shareMainPhotoHint')}
                  title={t('shareMainPhotoHint')}
                  className={cn(
                    'absolute bottom-0.5 left-0.5 rounded-[10px] p-[3px] text-white',
                    mainPhotoIndex === index ? 'bg-accent' : 'bg-black/45',
                  )}
                >
                  <Star size={14} className={mainPhotoIndex === index ? 'fill-white' : undefined} />
                </button>
              </li>
            ))}
          </ul>
          <p className="mt-1.5 text-[11px] text-muted-foreground">{t('shareMainPhotoHint')}</p>
        </>
      )}
        </>
      )}


      <div className="h-4" />

      {/* Pasul 2: caută în catalog. Nu e obligatoriu - se poate completa tot
          de mână - dar scutește de tastat și leagă anunțul de cartea existentă
          din catalog (`bookId`), ceea ce contează pentru pagina operei. */}
      <form
        onSubmit={(event) => {
          event.preventDefault();
          setQuery(term.trim());
        }}
        className="mb-4 flex items-center gap-2 rounded-[16px] bg-muted px-4"
      >
        <Search size={18} className="shrink-0 text-muted-foreground" />
        <input
          value={term}
          onChange={(event) => setTerm(event.target.value)}
          placeholder={t('browseSearchHint')}
          aria-label={t('browseSearchHint')}
          className="w-full bg-transparent py-3.5 text-foreground placeholder:text-muted-foreground focus:outline-none"
        />
      </form>

      {/* Fără indiciu, un câmp de căutare gol nu spune că are sugestii. */}
      {term.trim().length <= 2 && !picked && (
        <p className="mb-4 -mt-2 px-1 text-sm text-muted-foreground">
          {t('shareTitleAutocomplete')}
        </p>
      )}

      {query.length > 2 && !picked && (
        <div className="mb-6">
          {results.isPending ? (
            <div className="flex h-24 items-center justify-center text-accent">
              <Spinner size={22} />
            </div>
          ) : results.isError ? (
            <ErrorNotice message={t('commonGenericError')} onRetry={() => void results.refetch()} />
          ) : results.data.length === 0 ? (
            <p className="py-6 text-center text-muted-foreground">{t('shareScanNoResult')}</p>
          ) : (
            <ul className="flex flex-col gap-2">
              {results.data.slice(0, 8).map((result, index) => (
                <li key={result.id ?? result.isbn ?? index}>
                  <button
                    onClick={() => choose(result)}
                    className="flex w-full items-center gap-3 rounded-[16px] border border-border bg-card p-3 text-left hover:bg-muted"
                  >
                    <div className="h-[60px] w-[44px] shrink-0 overflow-hidden rounded-lg bg-muted">
                      <BookCover url={result.coverUrl} title={result.title} />
                    </div>
                    <span className="min-w-0 flex-1">
                      <span className="block truncate font-medium">{result.title}</span>
                      {result.author && (
                        <span className="block truncate text-sm text-muted-foreground">
                          {result.author}
                        </span>
                      )}
                    </span>
                  </button>
                </li>
              ))}
            </ul>
          )}
        </div>
      )}

      <form onSubmit={onSubmit} className="flex flex-col gap-4">
        {picked && (
          <div className="flex items-center gap-3 rounded-[16px] border border-accent/40 bg-accent/5 p-3">
            <div className="h-[60px] w-[44px] shrink-0 overflow-hidden rounded-lg bg-muted">
              <BookCover url={picked.coverUrl} title={picked.title} />
            </div>
            <span className="min-w-0 flex-1 truncate text-sm">{t('shareCoverSelected')}</span>
            <button
              type="button"
              onClick={() => setPicked(null)}
              aria-label={t('shareCoverRemove')}
              className="shrink-0 p-1.5 text-muted-foreground hover:text-danger-text"
            >
              <X size={16} />
            </button>
          </div>
        )}

        <Field
          label={t('addBookTitleLabel')}
          name="title"
          value={title}
          onChange={(event) => {
            setTitle(event.target.value);
            setError(null);
          }}
        />
        <Field
          label={t('shareAuthorHint')}
          name="author"
          value={author}
          onChange={(event) => setAuthor(event.target.value)}
        />

        <div className="grid grid-cols-2 gap-4">
          <Field
            label={t('sharePublisher')}
            name="publisher"
            value={publisher}
            onChange={(event) => setPublisher(event.target.value)}
          />
          <Field
            label={t('sharePublishedYear')}
            name="publishedYear"
            type="number"
            inputMode="numeric"
            value={publishedYear}
            onChange={(event) => setPublishedYear(event.target.value)}
          />
        </div>

        <div className="grid grid-cols-2 gap-4">
          <Field
            label={t('sharePageCountCustom')}
            name="pageCount"
            type="number"
            inputMode="numeric"
            value={pageCount}
            onChange={(event) => setPageCount(event.target.value)}
          />
          {/* Localitatea e locul SCHIMBULUI, deci nu spune nimic despre o
              carte pe care o ții doar în raft. */}
          {destination === 'listing' && (
            <Field
              label={t('shareCityHint')}
              name="city"
              value={city}
              onChange={(event) => setCity(event.target.value)}
            />
          )}
        </div>

        <div className="flex flex-col gap-1.5">
          <label htmlFor="genre" className="text-sm font-medium text-muted-foreground">
            {t('shareGenreHint')}
          </label>
          <select
            id="genre"
            value={genre}
            onChange={(event) => setGenre(event.target.value)}
            className="w-full rounded-[16px] bg-muted px-4 py-4 text-foreground focus:outline-none"
          >
            <option value="">{t('filtersAny')}</option>
            {genres.data?.map((stat) => (
              <option key={stat.genre} value={stat.genre}>
                {stat.genre}
              </option>
            ))}
          </select>
        </div>

        {/* Tot ce urmează descrie un ANUNȚ: stare, etichete, mod de
            listare, preț. Pentru raft n-au niciun înțeles. */}
        {destination === 'listing' && (
          <>
        <div>
          <p className="mb-2 text-sm font-medium text-muted-foreground">{t('filtersCondition')}</p>
          <div className="flex flex-wrap gap-2">
            {CONDITIONS.map((option) => (
              <button
                key={option.value}
                type="button"
                onClick={() => setCondition(option.value)}
                className={cn(
                  'rounded-full border px-4 py-2 text-sm transition',
                  condition === option.value
                    ? 'border-accent bg-accent/15 font-semibold text-accent'
                    : 'border-border hover:bg-muted',
                )}
              >
                {t(option.labelKey)}
              </button>
            ))}
          </div>
        </div>

        <Switch
          checked={isHardcover}
          onChange={setIsHardcover}
          label={t('addBookHardcoverSwitch')}
        />

        <div className="flex flex-col gap-1.5">
          <label htmlFor="description" className="text-sm font-medium text-muted-foreground">
            {t('shareDescriptionHint')}
          </label>
          <textarea
            id="description"
            rows={4}
            maxLength={MAX_DESCRIPTION}
            value={description}
            onChange={(event) => setDescription(event.target.value)}
            className="w-full resize-y rounded-[16px] bg-muted px-4 py-4 text-foreground focus:outline-none"
          />
          <p className="text-right text-xs text-muted-foreground">
            {t('shareDescriptionCharsLeft', { n: MAX_DESCRIPTION - description.length })}
          </p>
        </div>

        <div>
          <p className="mb-2 text-sm font-medium text-muted-foreground">{t('shareMoreInfo')}</p>
          <div className="mb-2 flex flex-wrap gap-2">
            {tags.map((tag) => (
              <span
                key={tag}
                className="flex items-center gap-1.5 rounded-full border border-border px-3 py-1.5 text-sm"
              >
                {tag}
                <button
                  type="button"
                  onClick={() => setTags(tags.filter((value) => value !== tag))}
                  aria-label={t('commonDelete')}
                  className="text-muted-foreground hover:text-danger-text"
                >
                  <X size={12} />
                </button>
              </span>
            ))}
          </div>
          <div className="flex gap-2">
            <input
              value={tagDraft}
              onChange={(event) => setTagDraft(event.target.value)}
              onKeyDown={(event) => {
                // Enter adaugă eticheta, nu trimite formularul - altfel prima
                // etichetă scrisă ar publica anunțul pe jumătate completat.
                if (event.key === 'Enter') {
                  event.preventDefault();
                  addTag();
                }
              }}
              aria-label={t('shareMoreInfo')}
              className="w-full rounded-[16px] bg-muted px-4 py-3.5 text-foreground focus:outline-none"
            />
            <Button type="button" variant="outline" onClick={addTag}>
              {t('adminAdd')}
            </Button>
          </div>
        </div>

        <div>
          <p className="mb-2 text-sm font-medium text-muted-foreground">{t('shareListingMode')}</p>
          <div className="flex flex-wrap gap-2">
            {(['swap', 'sale', 'donation'] as const).map((option) => (
              <button
                key={option}
                type="button"
                onClick={() => setMode(option)}
                className={cn(
                  'rounded-full border px-4 py-2 text-sm transition',
                  mode === option
                    ? 'border-accent bg-accent/15 font-semibold text-accent'
                    : 'border-border hover:bg-muted',
                )}
              >
                {t(
                  option === 'swap'
                    ? 'shareListingModeSwap'
                    : option === 'sale'
                      ? 'shareListingModeSale'
                      : 'shareListingModeDonation',
                )}
              </button>
            ))}
          </div>
        </div>

        {mode === 'sale' && (
          <>
            <Field
              label={t('addBookPriceLabel')}
              name="price"
              type="number"
              inputMode="decimal"
              min={0}
              value={price}
              onChange={(event) => {
                setPrice(event.target.value);
                setError(null);
              }}
            />
            <Switch
              checked={!isNegotiable}
              onChange={(value) => setIsNegotiable(!value)}
              label={t('addBookNonNegotiable')}
              hint={t('addBookNonNegotiableHint')}
            />
          </>
        )}
          </>
        )}


        {error && (
          <p role="alert" className="text-sm text-danger-text">
            {error}
          </p>
        )}

        <Button type="submit" loading={submit.isPending} fullWidth>
          {t(destination === 'shelf' ? 'shelfOwnedAddCta' : 'commonSubmit')}
        </Button>
      </form>
    </div>
  );
}
