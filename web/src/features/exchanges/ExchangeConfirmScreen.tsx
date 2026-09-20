import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { useNavigate, useParams } from 'react-router-dom';
import { useTranslation } from 'react-i18next';
import { ScreenHeader } from '@/components/layout/ScreenHeader';
import { CheckCircle2 } from 'lucide-react';
import { exchangeKeys, exchangesRepository } from './exchangesRepository';
import { BookCover } from '@/components/ui/BookCover';
import { Button, ErrorNotice, Spinner } from '@/components/ui';
import { useToast } from '@/components/ui/Toast';

/**
 * Confirmarea finală a unui schimb, pe un ecran separat.
 *
 * E o acțiune ireversibilă - cartea trece efectiv la noul proprietar - de
 * aceea are pagina ei, cu ambele cărți afișate, în loc de un buton într-o
 * listă unde se poate apăsa din greșeală.
 */
export function ExchangeConfirmScreen() {
  const { id = '' } = useParams();
  const { t } = useTranslation();
  const navigate = useNavigate();
  const queryClient = useQueryClient();
  const toast = useToast();

  const exchange = useQuery({
    queryKey: exchangeKeys.detail(id),
    queryFn: ({ signal }) => exchangesRepository.detail(id, signal),
    enabled: !!id,
  });

  const confirm = useMutation({
    mutationFn: () => exchangesRepository.markDone(id),
    onSuccess: () => {
      void queryClient.invalidateQueries({ queryKey: exchangeKeys.all });
      toast.show(t('exchangeConfirmDone'));
      void navigate('/exchanges');
    },
    onError: () => toast.show(t('exchangeConfirmError'), 'danger'),
  });

  const header = <ScreenHeader title={t('exchangeConfirmTitle')} back="/exchanges" />;

  if (exchange.isPending) {
    return (
      <div className="flex min-h-dvh items-center justify-center text-accent">
        {header}
        <Spinner size={28} />
      </div>
    );
  }

  if (exchange.isError) {
    return (
      <div className="mx-auto max-w-2xl p-6">
        {header}
        <ErrorNotice message={t('exchangesLoadError')} onRetry={() => void exchange.refetch()} />
      </div>
    );
  }

  const data = exchange.data;

  return (
    <div className="mx-auto w-full max-w-[560px] px-5 pb-16 pt-2 min-[900px]:px-8">
      {header}
      <div className="mb-6 flex items-center justify-center gap-4 rounded-[16px] border border-border bg-card p-5">
        {data.offeredBook && (
          <div className="w-[80px]">
            <div className="aspect-[5/7] overflow-hidden rounded-[12px] bg-muted">
              <BookCover
                url={data.offeredBook.book.coverUrl}
                fallbackUrl={data.offeredBook.mainPhotoUrl}
                title={data.offeredBook.book.title}
              />
            </div>
            <p className="mt-2 line-clamp-2 text-center text-xs">
              {data.offeredBook.book.title}
            </p>
          </div>
        )}

        <CheckCircle2 size={24} className="shrink-0 text-success" />

        <div className="w-[80px]">
          <div className="aspect-[5/7] overflow-hidden rounded-[12px] bg-muted">
            <BookCover
              url={data.requestedBook.book.coverUrl}
              fallbackUrl={data.requestedBook.mainPhotoUrl}
              title={data.requestedBook.book.title}
            />
          </div>
          <p className="mt-2 line-clamp-2 text-center text-xs">
            {data.requestedBook.book.title}
          </p>
        </div>
      </div>

      <p className="mb-6 text-center text-muted-foreground">{t('exchangeConfirmQuestion')}</p>

      <Button onClick={() => confirm.mutate()} loading={confirm.isPending} fullWidth>
        {t('exchangeConfirmButton')}
      </Button>
    </div>
  );
}
