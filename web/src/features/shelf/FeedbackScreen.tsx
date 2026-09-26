import { useRef, useState, type FormEvent } from 'react';
import { useMutation } from '@tanstack/react-query';
import { useTranslation } from 'react-i18next';
import { ScreenHeader } from '@/components/layout/ScreenHeader';
import { ImagePlus, X } from 'lucide-react';
import { feedbackRepository } from './shelfRepository';
import { Button } from '@/components/ui';
import { useToast } from '@/components/ui/Toast';

export function FeedbackScreen() {
  const { t } = useTranslation();
  const toast = useToast();
  const fileInput = useRef<HTMLInputElement>(null);

  const [message, setMessage] = useState('');
  const [photo, setPhoto] = useState<File | null>(null);
  const [preview, setPreview] = useState<string | null>(null);

  const send = useMutation({
    mutationFn: () => feedbackRepository.send(message.trim(), photo ?? undefined),
    onSuccess: () => {
      toast.show(t('profileFeedbackThanks'));
      setMessage('');
      clearPhoto();
    },
    onError: () => toast.show(t('profileFeedbackError'), 'danger'),
  });

  function pickPhoto(file: File | undefined) {
    if (!file) return;
    setPhoto(file);
    // `createObjectURL`, nu FileReader: nu citește fișierul în memorie, doar
    // creează o referință. Se eliberează explicit mai jos.
    setPreview((current) => {
      if (current) URL.revokeObjectURL(current);
      return URL.createObjectURL(file);
    });
  }

  function clearPhoto() {
    setPhoto(null);
    setPreview((current) => {
      if (current) URL.revokeObjectURL(current);
      return null;
    });
  }

  function onSubmit(event: FormEvent) {
    event.preventDefault();
    if (!message.trim()) return;
    send.mutate();
  }

  const header = <ScreenHeader title={t('profileSendFeedback')} back />;

  return (
    <div className="mx-auto w-full max-w-[560px] px-5 pb-16 pt-2 min-[900px]:px-8">
      {header}
      <p className="mb-6 text-muted-foreground">{t('feedbackPageIntro')}</p>

      <form onSubmit={onSubmit} className="flex flex-col gap-4">
        <textarea
          value={message}
          onChange={(event) => setMessage(event.target.value)}
          rows={6}
          placeholder={t('profileFeedbackHint')}
          aria-label={t('profileFeedbackHint')}
          className="w-full resize-y rounded-[16px] bg-muted px-4 py-4 text-foreground placeholder:text-muted-foreground focus:outline-none"
        />

        <input
          ref={fileInput}
          type="file"
          accept="image/*"
          hidden
          onChange={(event) => {
            pickPhoto(event.target.files?.[0]);
            event.target.value = '';
          }}
        />

        {preview ? (
          <div className="relative w-fit">
            <img src={preview} alt="" className="max-h-48 rounded-[12px] border border-border" />
            <button
              type="button"
              onClick={clearPhoto}
              aria-label={t('profileFeedbackRemovePhoto')}
              className="absolute right-1.5 top-1.5 rounded-full bg-card/90 p-1.5 text-danger-text shadow"
            >
              <X size={14} />
            </button>
          </div>
        ) : (
          <Button type="button" variant="outline" onClick={() => fileInput.current?.click()}>
            <ImagePlus size={18} />
            {t('profileFeedbackAddPhoto')}
          </Button>
        )}

        <Button type="submit" loading={send.isPending} disabled={!message.trim()} fullWidth>
          {t('commonSubmit')}
        </Button>
      </form>
    </div>
  );
}
