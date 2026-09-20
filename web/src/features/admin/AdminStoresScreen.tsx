import { useState } from 'react';
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { useTranslation } from 'react-i18next';
import { Store, Trash2 } from 'lucide-react';
import { api, ApiError } from '@/lib/api/client';
import { ScreenHeader } from '@/components/layout/ScreenHeader';
import { Button, ErrorNotice, Field, Spinner } from '@/components/ui';
import { Switch } from '@/components/ui/Switch';
import { RequireAdmin } from './AdminScreens';
import { adminRepository } from './adminRepository';

/** Datele comerciale ale unui cont de magazin. */
interface StoreProfile {
  userId?: string;
  displayName: string;
  description?: string | null;
  address?: string | null;
  city?: string | null;
  website?: string | null;
  phone?: string | null;
  openingHours?: string | null;
  deliveryPolicy?: string | null;
}

/**
 * Un magazin așa cum îl vede panoul: profilul plus contul din spatele lui și
 * cât stoc are, ca să se vadă dintr-o privire dacă importul a intrat.
 */
interface StoreAccount {
  profile: StoreProfile;
  userId: string;
  name: string | null;
  username: string | null;
  email: string;
  /** Suspendat: profilul rămâne, dar contul nu mai primește stoc nou. */
  isActive: boolean;
  listingsCount: number;
}

const FIELDS: Array<{ key: keyof StoreProfile; labelKey: string; rows?: number }> = [
  { key: 'displayName', labelKey: 'adminStoreName' },
  { key: 'description', labelKey: 'adminStoreDescription', rows: 3 },
  { key: 'openingHours', labelKey: 'adminStoreHours' },
  { key: 'deliveryPolicy', labelKey: 'adminStoreDelivery', rows: 2 },
  { key: 'address', labelKey: 'adminStoreAddress' },
  { key: 'city', labelKey: 'adminStoreCity' },
  { key: 'website', labelKey: 'adminStoreWebsite' },
  { key: 'phone', labelKey: 'adminStorePhone' },
];

const EMPTY_PROFILE: StoreProfile = {
  displayName: '',
  description: '',
  address: '',
  city: '',
  website: '',
  phone: '',
  openingHours: '',
  deliveryPolicy: '',
};

const storesKey = ['admin', 'stores'] as const;

/**
 * Conturile de anticariat/librărie - doar pentru super-admini.
 *
 * Un magazin e un cont obișnuit marcat ca atare: aici i se dau datele
 * comerciale (nume, program, livrare) și de aici i se retrag. Ce câștigă un
 * astfel de cont e dreptul de a-și importa stocul cu preț - inclusiv de a lista
 * la vânzare fără pozele cerute tuturor - deci aprobarea e manuală.
 */
export function AdminStoresScreen() {
  const { t } = useTranslation();
  const [editing, setEditing] = useState<StoreAccount | 'new' | null>(null);

  const stores = useQuery({
    queryKey: storesKey,
    queryFn: ({ signal }) => api.get<StoreAccount[]>('/admin/stores', { signal }),
  });

  return (
    <RequireAdmin>
      <div className="mx-auto w-full max-w-[760px] px-5 pb-16 pt-4 min-[900px]:px-8">
        <ScreenHeader title={t('adminStoresTitle')} back="/admin" />

        {stores.isPending ? (
          <div className="flex h-40 items-center justify-center text-accent">
            <Spinner size={26} />
          </div>
        ) : stores.isError ? (
          <ErrorNotice message={t('commonGenericError')} onRetry={() => void stores.refetch()} />
        ) : stores.data.length === 0 ? (
          <div className="py-16 text-center">
            <p>{t('adminStoresEmpty')}</p>
            <p className="mt-1 text-sm text-muted-foreground">{t('adminStoresSubtitle')}</p>
          </div>
        ) : (
          <ul className="flex flex-col gap-2">
            {stores.data.map((store) => (
              <StoreRow key={store.userId} store={store} onEdit={() => setEditing(store)} />
            ))}
          </ul>
        )}

        <button
          onClick={() => setEditing('new')}
          className="fixed bottom-6 right-6 z-20 flex items-center gap-2 rounded-full bg-primary px-5 py-3.5 text-sm font-bold text-primary-foreground shadow-lg hover:brightness-110"
        >
          <Store size={18} />
          {t('adminStoresAdd')}
        </button>

        {editing && (
          <StoreEditor
            store={editing === 'new' ? null : editing}
            onClose={() => setEditing(null)}
          />
        )}
      </div>
    </RequireAdmin>
  );
}

function StoreRow({ store, onEdit }: { store: StoreAccount; onEdit: () => void }) {
  const { t } = useTranslation();
  const queryClient = useQueryClient();

  const remove = useMutation({
    mutationFn: () => api.delete(`/admin/stores/${store.userId}`),
    onSuccess: () => queryClient.invalidateQueries({ queryKey: storesKey }),
  });

  return (
    <li className="flex items-center gap-3 rounded-[16px] border border-border bg-card p-3">
      <Store size={22} className={store.isActive ? 'text-accent' : 'text-muted-foreground'} />

      <button onClick={onEdit} className="min-w-0 flex-1 text-left">
        <span className="flex items-center gap-2">
          <span className="min-w-0 truncate font-semibold">{store.profile.displayName}</span>
          {!store.isActive && (
            <span className="shrink-0 text-xs text-destructive">{t('adminStoreSuspended')}</span>
          )}
        </span>
        <span className="block truncate text-sm text-muted-foreground">
          {store.email} · {t('adminStoreListings', { count: store.listingsCount })}
        </span>
      </button>

      <button
        onClick={() => {
          if (window.confirm(t('adminStoreRemoveConfirm'))) remove.mutate();
        }}
        disabled={remove.isPending}
        title={t('adminStoreRemove')}
        aria-label={t('adminStoreRemove')}
        className="shrink-0 rounded-[12px] p-2 text-muted-foreground hover:bg-muted hover:text-destructive disabled:opacity-50"
      >
        <Trash2 size={18} />
      </button>
    </li>
  );
}

/**
 * Formularul de creare/editare. La creare cere întâi contul (căutare după
 * nume/@username/email, ca peste tot în panou - `id` e un UUID pe care nimeni
 * nu-l are la îndemână); la editare contul e deja fixat.
 */
function StoreEditor({ store, onClose }: { store: StoreAccount | null; onClose: () => void }) {
  const { t } = useTranslation();
  const queryClient = useQueryClient();

  const [profile, setProfile] = useState<StoreProfile>({
    ...EMPTY_PROFILE,
    ...(store?.profile ?? {}),
  });
  const [isActive, setIsActive] = useState(store?.isActive ?? true);
  const [userId, setUserId] = useState<string | null>(store?.userId ?? null);
  const [term, setTerm] = useState('');
  const [error, setError] = useState<string | null>(null);

  const search = useQuery({
    queryKey: ['admin', 'users', 'search', term],
    queryFn: ({ signal }) => adminRepository.users({ q: term }, signal),
    enabled: !store && term.trim().length >= 2,
  });

  const save = useMutation({
    mutationFn: () => {
      const body = {
        displayName: profile.displayName.trim(),
        description: profile.description?.trim() ?? '',
        address: profile.address?.trim() ?? '',
        city: profile.city?.trim() ?? '',
        website: profile.website?.trim() ?? '',
        phone: profile.phone?.trim() ?? '',
        openingHours: profile.openingHours?.trim() ?? '',
        deliveryPolicy: profile.deliveryPolicy?.trim() ?? '',
      };
      return store
        ? api.put(`/admin/stores/${store.userId}`, { ...body, isActive })
        : api.post('/admin/stores', { userId, ...body });
    },
    onSuccess: () => {
      void queryClient.invalidateQueries({ queryKey: storesKey });
      onClose();
    },
    // Mesajul serverului e mai util decât unul generic: „contul e deja
    // magazin", „utilizator negăsit" etc.
    onError: (cause) => setError(messageOf(cause) ?? t('commonGenericError')),
  });

  function submit() {
    if (!userId) {
      setError(t('adminStoreUserRequired'));
      return;
    }
    if (profile.displayName.trim().length < 2) {
      setError(t('adminStoreNameRequired'));
      return;
    }
    setError(null);
    save.mutate();
  }

  return (
    <div className="fixed inset-0 z-50 flex items-end justify-center min-[560px]:items-center">
      <button
        aria-label={t('commonCancel')}
        onClick={onClose}
        className="absolute inset-0 bg-black/50"
      />

      <div className="relative max-h-[85dvh] w-full max-w-[460px] overflow-y-auto rounded-t-[20px] bg-card p-5 min-[560px]:rounded-[20px]">
        <h2 className="mb-4 font-display text-lg font-bold">
          {t(store ? 'adminStoresEdit' : 'adminStoresAdd')}
        </h2>

        {!store && (
          <div className="mb-4">
            <Field
              label={t('adminStoresPickUser')}
              name="store-user"
              value={term}
              autoFocus
              onChange={(event) => {
                setTerm(event.target.value);
                setUserId(null);
              }}
            />
            {search.data && search.data.length > 0 && !userId && (
              <ul className="mt-2 max-h-48 overflow-y-auto rounded-[12px] border border-border">
                {search.data.map((candidate) => (
                  <li key={candidate.id}>
                    <button
                      onClick={() => {
                        setUserId(candidate.id);
                        setTerm(candidate.email);
                      }}
                      className="block w-full px-3 py-2 text-left text-sm hover:bg-muted"
                    >
                      {candidate.name ?? candidate.username ?? candidate.email}
                      <span className="block text-xs text-muted-foreground">{candidate.email}</span>
                    </button>
                  </li>
                ))}
              </ul>
            )}
          </div>
        )}

        {FIELDS.map((field) => (
          <div key={field.key} className="mb-3">
            {field.rows ? (
              <label className="flex flex-col gap-1.5">
                <span className="text-sm font-medium text-muted-foreground">
                  {t(field.labelKey)}
                </span>
                <textarea
                  rows={field.rows}
                  value={(profile[field.key] as string | null) ?? ''}
                  onChange={(event) =>
                    setProfile((current) => ({ ...current, [field.key]: event.target.value }))
                  }
                  className="w-full resize-y rounded-[16px] bg-muted px-4 py-3.5 text-foreground focus:outline-none"
                />
              </label>
            ) : (
              <Field
                label={t(field.labelKey)}
                name={String(field.key)}
                value={(profile[field.key] as string | null) ?? ''}
                onChange={(event) =>
                  setProfile((current) => ({ ...current, [field.key]: event.target.value }))
                }
              />
            )}
          </div>
        ))}

        {store && (
          <div className="mb-3">
            <Switch checked={isActive} onChange={setIsActive} label={t('adminStoreActive')} />
            <p className="mt-1 text-sm text-muted-foreground">{t('adminStoreActiveHint')}</p>
          </div>
        )}

        {error && <p className="mb-3 text-sm text-destructive">{error}</p>}

        <div className="flex justify-end gap-2">
          <Button variant="text" onClick={onClose} disabled={save.isPending}>
            {t('commonCancel')}
          </Button>
          <Button onClick={submit} loading={save.isPending}>
            {t('commonSave')}
          </Button>
        </div>
      </div>
    </div>
  );
}

function messageOf(cause: unknown): string | null {
  const data = cause instanceof ApiError ? (cause.data as { message?: unknown } | null) : null;
  const message = data?.message;
  if (Array.isArray(message)) return message.join(', ');
  if (typeof message === 'string' && message.trim()) return message;
  return null;
}
