import { useState } from 'react';
import { useTranslation } from 'react-i18next';
import { CloseButton, Spinner } from '@/components/ui';
import { cn } from '@/lib/utils/cn';

export type ReportReason =
  | 'SPAM'
  | 'SCAM'
  | 'INAPPROPRIATE'
  | 'HARASSMENT'
  | 'OTHER'
  | 'ABUSIVE_LANGUAGE'
  | 'FALSE_CONTENT'
  | 'FAKE_PROFILE';

/**
 * Ce motive se oferă, după țintă. Aceeași împărțire ca REPORT_REASONS_BY_TARGET
 * din backend, care o și validează: o pereche greșită motiv/țintă e respinsă,
 * deci lista nu e doar cosmetică.
 */
const REASONS: Record<'user' | 'content', ReportReason[]> = {
  user: ['HARASSMENT', 'SCAM', 'FAKE_PROFILE', 'OTHER'],
  content: ['SPAM', 'ABUSIVE_LANGUAGE', 'FALSE_CONTENT', 'INAPPROPRIATE', 'OTHER'],
};

const LABEL_KEYS: Record<ReportReason, string> = {
  SPAM: 'reportReasonSpam',
  SCAM: 'reportReasonScam',
  INAPPROPRIATE: 'reportReasonInappropriate',
  HARASSMENT: 'reportReasonHarassment',
  OTHER: 'reportReasonOther',
  ABUSIVE_LANGUAGE: 'reportReasonAbusiveLanguage',
  FALSE_CONTENT: 'reportReasonFalseContent',
  FAKE_PROFILE: 'reportReasonFakeProfile',
};

/** Port al `ReportReasonDialog` din Flutter: alegi motivul și trimiți. */
export function ReportReasonDialog({
  target,
  title,
  onSubmit,
  onClose,
}: {
  target: 'user' | 'content';
  title?: string;
  /** Închiderea rămâne în grija apelantului, după ce trimiterea reușește. */
  onSubmit: (reason: ReportReason) => Promise<void>;
  onClose: () => void;
}) {
  const { t } = useTranslation();
  const reasons = REASONS[target];
  const [reason, setReason] = useState<ReportReason>(reasons[0]);
  const [sending, setSending] = useState(false);

  async function submit() {
    setSending(true);
    try {
      await onSubmit(reason);
    } finally {
      setSending(false);
    }
  }

  return (
    <div role="dialog" aria-modal className="fixed inset-0 z-50 flex items-center justify-center p-5">
      <button aria-label={t('commonClose')} onClick={onClose} className="absolute inset-0 bg-black/50" />
      <div className="relative w-full max-w-[420px] rounded-[20px] bg-card p-5">
        <div className="flex items-center gap-3">
          <h2 className="flex-1 font-display text-lg font-bold">{title ?? t('reportDialogTitle')}</h2>
          <CloseButton onClick={onClose} />
        </div>

        <div className="mt-3 flex flex-col">
          {reasons.map((value) => (
            <label
              key={value}
              className={cn(
                'flex cursor-pointer items-center gap-3 rounded-[12px] px-3 py-2.5 hover:bg-muted',
                reason === value && 'bg-muted',
              )}
            >
              <input
                type="radio"
                name="report-reason"
                value={value}
                checked={reason === value}
                onChange={() => setReason(value)}
                className="accent-[var(--ss-accent)]"
              />
              {t(LABEL_KEYS[value])}
            </label>
          ))}
        </div>

        <div className="mt-4 flex justify-end gap-2">
          <button
            onClick={onClose}
            className="rounded-[12px] px-4 py-2.5 text-sm font-medium hover:bg-muted"
          >
            {t('commonCancel')}
          </button>
          <button
            onClick={() => void submit()}
            disabled={sending}
            className="flex items-center gap-2 rounded-[12px] bg-primary px-4 py-2.5 text-sm font-bold text-primary-foreground disabled:opacity-60"
          >
            {sending && <Spinner size={16} />}
            {t('commonSubmit')}
          </button>
        </div>
      </div>
    </div>
  );
}
