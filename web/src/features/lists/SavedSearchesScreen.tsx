import { useState, type FormEvent } from 'react';
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { Link } from 'react-router-dom';
import { useTranslation } from 'react-i18next';
import { ScreenHeader } from '@/components/layout/ScreenHeader';
import { Plus, Search, Trash2 } from 'lucide-react';
import { listsKeys, savedSearchesRepository } from './listsRepository';
import { booksKeys, booksRepository } from '@/features/books/booksRepository';
import { Button, ErrorNotice, Field, Spinner } from '@/components/ui';
import { useToast } from '@/components/ui/Toast';
import { toNumber } from '@/types/models';

/**
 * Căutări salvate: backendul le verifică periodic și trimite o notificare
 * (SAVED_SEARCH_MATCH) când apare o carte care se potrivește.
 */
export function SavedSearchesScreen() {
  const { t } = useTranslation();
  const queryClient = useQueryClient();
  const toast = useToast();

  const [creating, setCreating] = useState(false);
  const [label, setLabel] = useState('');
  const [genre, setGenre] = useState('');
  const [city, setCity] = useState('');
  const [maxPrice, setMaxPrice] = useState('');

  const searches = useQuery({
    queryKey: listsKeys.savedSearches(),
    queryFn: ({ signal }) => savedSearchesRepository.list(signal),
  });

  const genres = useQuery({
    queryKey: booksKeys.genres(),
    queryFn: ({ signal }) => booksRepository.getGenres(signal),
    staleTime: 60 * 60 * 1000,
  });

  const create = useMutation({
    mutationFn: () =>
      savedSearchesRepository.create({
        label: label.trim() || undefined,
        genre: genre || undefined,
        city: city.trim() || undefined,
        // `Number('')` dă 0, nu NaN - fără verificarea de șir gol, o căutare
        // fără preț maxim s-ar salva cu limita 0 și n-ar găsi nimic niciodată.
        maxPrice: maxPrice.trim() ? Number(maxPrice) : undefined,
      }),
    onSuccess: () => {
      void queryClient.invalidateQueries({ queryKey: listsKeys.savedSearches() });
      setCreating(false);
      setLabel('');
      setGenre('');
      setCity('');
      setMaxPrice('');
    },
    onError: () => toast.show(t('savedSearchCreateError'), 'danger'),
  });

  const remove = useMutation({
    mutationFn: (id: string) => savedSearchesRepository.remove(id),
    onSuccess: () => queryClient.invalidateQueries({ queryKey: listsKeys.savedSearches() }),
  });

  function onCreate(event: FormEvent) {
    event.preventDefault();
    create.mutate();
  }

  const header = <ScreenHeader title={t('savedSearchesTitle')} back />;

  if (searches.isPending) {
    return (
      <div className="flex min-h-dvh items-center justify-center text-accent">
        {header}
        <Spinner size={28} />
      </div>
    );
  }

  if (searches.isError) {
    return (
      <div className="mx-auto max-w-2xl p-6">
        {header}
        <ErrorNotice
          message={t('savedSearchesLoadError')}
          onRetry={() => void searches.refetch()}
        />
      </div>
    );
  }

  return (
    <div className="mx-auto w-full max-w-[680px] px-5 pb-16 pt-2 min-[900px]:px-8">
      {header}
      <div className="mb-6 flex flex-wrap items-center justify-between gap-3">
        <Button onClick={() => setCreating((open) => !open)}>
          <Plus size={18} />
          {t('savedSearchNew')}
        </Button>
      </div>

      {creating && (
        <form
          onSubmit={onCreate}
          className="mb-6 flex flex-col gap-4 rounded-[16px] border border-border bg-card p-5"
        >
          <Field
            label={t('savedSearchLabelHint')}
            name="label"
            value={label}
            autoFocus
            onChange={(event) => setLabel(event.target.value)}
          />

          <div className="flex flex-col gap-1.5">
            <label htmlFor="genre" className="text-sm font-medium text-muted-foreground">
              {t('filtersGenre')}
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

          <Field
            label={t('filtersAnyCity')}
            name="city"
            value={city}
            onChange={(event) => setCity(event.target.value)}
          />

          <Field
            label={t('savedSearchMaxPriceLabel')}
            name="maxPrice"
            type="number"
            inputMode="numeric"
            min={0}
            value={maxPrice}
            onChange={(event) => setMaxPrice(event.target.value)}
          />

          <div className="flex gap-2">
            <Button type="submit" loading={create.isPending}>
              {t('commonSave')}
            </Button>
            <Button type="button" variant="text" onClick={() => setCreating(false)}>
              {t('commonCancel')}
            </Button>
          </div>
        </form>
      )}

      {searches.data.length === 0 ? (
        <p className="py-16 text-center text-muted-foreground">{t('savedSearchesEmpty')}</p>
      ) : (
        <ul className="flex flex-col gap-2">
          {searches.data.map((search) => {
            const price = toNumber(search.maxPrice);
            // Aceeași căutare, redeschisă ca link de răsfoire cu filtrele puse.
            const params = new URLSearchParams();
            if (search.genre) params.set('genre', search.genre);
            if (search.city) params.set('city', search.city);

            return (
              <li
                key={search.id}
                className="flex items-center gap-3 rounded-[16px] border border-border bg-card p-4"
              >
                <Search size={18} className="shrink-0 text-muted-foreground" />
                <div className="min-w-0 flex-1">
                  <p className="truncate font-semibold">
                    {search.label || search.genre || search.city || t('savedSearchesTitle')}
                  </p>
                  <p className="truncate text-sm text-muted-foreground">
                    {[
                      search.genre,
                      search.city,
                      price !== null ? t('savedSearchMaxPriceChip', { amount: price }) : null,
                    ]
                      .filter(Boolean)
                      .join(' · ')}
                  </p>
                </div>

                <Link
                  to={`/browse?${params.toString()}`}
                  className="shrink-0 rounded-[12px] border border-border px-3 py-2 text-sm hover:bg-muted"
                >
                  {t('browseTitle')}
                </Link>

                <button
                  onClick={() => remove.mutate(search.id)}
                  aria-label={t('commonDelete')}
                  className="shrink-0 rounded-[12px] p-2.5 text-muted-foreground hover:bg-muted hover:text-danger-text"
                >
                  <Trash2 size={18} />
                </button>
              </li>
            );
          })}
        </ul>
      )}
    </div>
  );
}
