import { useEffect, useState } from 'react';
import { useTranslation } from 'react-i18next';
import QRCode from 'qrcode';

/**
 * Codul QR al unui profil. Port al `ProfileQrDialog` + `ScannableQr`.
 *
 * Fundalul e alb și modulele negre EXPLICIT, nu din temă: pe tema întunecată
 * un QR desenat în culorile paletei ajunge cu contrast inversat și niciun
 * telefon nu-l mai citește.
 */
export function ProfileQrDialog({ userId, onClose }: { userId: string; onClose: () => void }) {
  const { t } = useTranslation();
  const [svg, setSvg] = useState<string | null>(null);

  useEffect(() => {
    const link = `${window.location.origin}/users/${userId}`;
    let cancelled = false;
    void QRCode.toString(link, {
      type: 'svg',
      margin: 0,
      width: 200,
      color: { dark: '#000000', light: '#FFFFFF' },
    }).then((markup) => {
      if (!cancelled) setSvg(markup);
    });
    return () => {
      cancelled = true;
    };
  }, [userId]);

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-5">
      <button
        aria-label={t('commonClose')}
        onClick={onClose}
        className="absolute inset-0 bg-black/50"
      />
      <div className="relative w-full max-w-[360px] rounded-[20px] bg-card p-5 text-center">
        <h2 className="font-display text-lg font-bold">{t('profileQrDialogTitle')}</h2>
        <p className="mt-1 text-sm text-muted-foreground">{t('profileQrDialogBody')}</p>

        <div className="mx-auto mt-4 w-fit rounded-[12px] bg-white p-3">
          {svg ? (
            // Markup generat local de `qrcode`, nu conținut de la user - nu
            // trece prin nicio intrare externă.
            <div
              className="size-[200px]"
              // eslint-disable-next-line react/no-danger
              dangerouslySetInnerHTML={{ __html: svg }}
            />
          ) : (
            <div className="size-[200px]" />
          )}
        </div>

        <button
          onClick={onClose}
          className="mt-4 rounded-[12px] px-4 py-2.5 text-sm font-semibold text-accent hover:bg-muted"
        >
          {t('commonClose')}
        </button>
      </div>
    </div>
  );
}
