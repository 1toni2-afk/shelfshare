import { useEffect, useState, type ReactNode } from 'react';
import { Link } from 'react-router-dom';
import { useTranslation } from 'react-i18next';
import {
  BookOpen,
  History,
  Images,
  MapPin,
  Play,
  Rss,
  ShieldCheck,
  Sparkles,
  Trophy,
  Users,
  X,
} from 'lucide-react';

/**
 * Funcțiile aplicației, fiecare cu un „See Demo" care deschide o captură de
 * ecran peste pagină - în același dialog estompat ca poarta de cont, ca omul
 * să vadă cum arată de fapt ecranul înainte să-și facă cont.
 *
 * Capturile stau în `public/demo/<id>.webp` (vezi README-ul de acolo) și se
 * fac pe conturile de demo create de backend/prisma/seed-demo.ts. O captură
 * lipsă nu strică nimic: dialogul arată doar descrierea.
 */
type FeatureId =
  | 'collections'
  | 'matches'
  | 'nearby'
  | 'groups'
  | 'leaderboard'
  | 'history'
  | 'shelf'
  | 'trade'
  | 'feed';

interface Feature {
  id: FeatureId;
  icon: ReactNode;
  title: string;
  text: string;
}

export function LandingFeatures() {
  const { t } = useTranslation();
  const [demo, setDemo] = useState<Feature | null>(null);

  const features: Feature[] = [
    {
      id: 'collections',
      icon: <Images size={20} />,
      title: t('landingFeatureCollectionsTitle', 'Colecții'),
      text: t(
        'landingFeatureCollectionsText',
        'Îți grupezi cărțile cum vrei tu - „De citit vara asta", „Clasici rusești", „De dat mai departe". Fiecare colecție are copertă proprie și o poți face publică, ca prietenii să vadă ce ai pus deoparte.',
      ),
    },
    {
      id: 'matches',
      icon: <Sparkles size={20} />,
      title: t('landingFeatureMatchesTitle', 'Potriviri de schimb inteligente'),
      text: t(
        'landingFeatureMatchesText',
        'Aplicația caută singură oamenii care au cărți de pe lista ta de dorințe și, în același timp, vor ceva de pe raftul tău. Vezi potrivirea gata făcută și propui schimbul dintr-un click.',
      ),
    },
    {
      id: 'nearby',
      icon: <MapPin size={20} />,
      title: t('landingFeatureNearbyTitle', 'Cărți din apropiere'),
      text: t(
        'landingFeatureNearbyText',
        'Toate anunțurile puse pe hartă, cu distanța până la ele. Găsești cărțile din orașul tău și le iei în aceeași zi, fără curier.',
      ),
    },
    {
      id: 'groups',
      icon: <Users size={20} />,
      title: t('landingFeatureGroupsTitle', 'Grupuri'),
      text: t(
        'landingFeatureGroupsText',
        'Cluburi de lectură cu discuție proprie și cartea lunii. Intri în cele publice sau îți faci unul privat cu prietenii.',
      ),
    },
    {
      id: 'leaderboard',
      icon: <Trophy size={20} />,
      title: t('landingFeatureLeaderboardTitle', 'Clasament și statistici'),
      text: t(
        'landingFeatureLeaderboardText',
        'Cine a dat cele mai multe cărți mai departe, pe lună și de la început, plus cărțile, autorii și genurile care circulă cel mai mult în comunitate. Fiecare schimb încheiat îți aduce puncte și insigne.',
      ),
    },
    {
      id: 'history',
      icon: <History size={20} />,
      title: t('landingFeatureHistoryTitle', 'Istoria cărții'),
      text: t(
        'landingFeatureHistoryText',
        'Fiecare exemplar își păstrează drumul: prin mâinile cui a trecut, în ce orașe și când. Cartea primită vine cu povestea ei.',
      ),
    },
    {
      id: 'shelf',
      icon: <BookOpen size={20} />,
      title: t('landingFeatureShelfTitle', 'Raftul meu, cu progresul lecturii'),
      text: t(
        'landingFeatureShelfText',
        'Rafturile tale - citite, în curs, de citit - cu pagina la care ai rămas și procentul din carte. Le adaugi scanând ISBN-ul sau le imporți din Goodreads.',
      ),
    },
    {
      id: 'trade',
      icon: <ShieldCheck size={20} />,
      title: t('landingFeatureTradeTitle', 'Sistem de schimb sigur și avansat'),
      text: t(
        'landingFeatureTradeText',
        'Tot drumul unui schimb, de la propunere la predare: oferte de preț, contraoferte, număr de telefon verificat, confirmare de ambele părți, rezervarea cărții cât durează schimbul și recenzii la final.',
      ),
    },
    {
      id: 'feed',
      icon: <Rss size={20} />,
      title: t('landingFeatureFeedTitle', 'Feed'),
      text: t(
        'landingFeatureFeedText',
        'Ce au mai pus pe raft, ce au terminat de citit și ce au schimbat cititorii pe care îi urmărești - de obicei de aici apar cărțile bune înainte să le ia altcineva.',
      ),
    },
  ];

  return (
    <section className="mt-14">
      <h2 className="font-display text-2xl font-bold">
        {t('landingFeaturesTitle', 'Ce poți face în ShelfShare')}
      </h2>
      <p className="mt-2 max-w-[70ch] text-muted-foreground">
        {t(
          'landingFeaturesIntro',
          'Mai mult decât un loc de anunțuri. Apasă pe „See Demo" ca să vezi cum arată fiecare ecran.',
        )}
      </p>

      <div className="mt-6 grid gap-4 min-[700px]:grid-cols-2 min-[1100px]:grid-cols-3">
        {features.map((feature, index) => (
          <div
            key={feature.id}
            className="flex flex-col rounded-[16px] border border-border bg-card p-5"
          >
            <div className="flex items-center gap-2.5">
              <span className="inline-flex rounded-lg bg-accent/15 p-2 text-accent">
                {feature.icon}
              </span>
              <h3 className="font-display text-lg font-bold">
                <span className="text-muted-foreground">{index + 1}.</span> {feature.title}
              </h3>
            </div>
            <p className="mt-2.5 flex-1 text-sm leading-relaxed text-muted-foreground">
              {feature.text}
            </p>
            <button
              onClick={() => setDemo(feature)}
              className="mt-4 inline-flex items-center gap-1.5 self-start rounded-full border border-border px-4 py-2 text-sm font-bold text-accent hover:bg-muted"
            >
              <Play size={14} />
              {t('landingFeatureSeeDemo', 'See Demo')}
            </button>
          </div>
        ))}

        <div className="flex flex-col justify-center rounded-[16px] border border-dashed border-border p-5">
          <h3 className="font-display text-lg font-bold">
            {t('landingFeaturesMoreTitle', 'Și multe altele…')}
          </h3>
          <p className="mt-2.5 text-sm leading-relaxed text-muted-foreground">
            {t(
              'landingFeaturesMoreText',
              'Book Match, lista de dorințe cu notificări, licitații, căutări salvate, chat, cartea lunii și încă multe - toate într-un singur cont gratuit.',
            )}
          </p>
        </div>
      </div>

      {demo && <FeatureDemoDialog feature={demo} onClose={() => setDemo(null)} />}
    </section>
  );
}

/**
 * Captura de ecran a unei funcții, peste pagina estompată - același tipar ca
 * dialogul din GuestGate, doar mai lat, ca imaginea să se poată citi.
 */
function FeatureDemoDialog({ feature, onClose }: { feature: Feature; onClose: () => void }) {
  const { t } = useTranslation();
  const [imageFailed, setImageFailed] = useState(false);

  useEffect(() => {
    const onKey = (event: KeyboardEvent) => {
      if (event.key === 'Escape') onClose();
    };
    window.addEventListener('keydown', onKey);
    return () => window.removeEventListener('keydown', onKey);
  }, [onClose]);

  return (
    <div
      role="dialog"
      aria-modal="true"
      aria-label={feature.title}
      className="fixed inset-0 z-[60] flex items-end justify-center min-[560px]:items-center min-[560px]:p-6"
    >
      <button
        aria-label={t('commonClose', 'Închide')}
        onClick={onClose}
        className="absolute inset-0 bg-background/70 backdrop-blur-md"
      />

      <div className="relative flex max-h-[92dvh] w-full max-w-[880px] flex-col overflow-hidden rounded-t-[20px] border border-border bg-card shadow-xl min-[560px]:rounded-[20px]">
        <button
          onClick={onClose}
          aria-label={t('commonClose', 'Închide')}
          className="absolute right-3 top-3 z-10 rounded-full bg-card/80 p-2 text-muted-foreground hover:bg-muted"
        >
          <X size={18} />
        </button>

        {!imageFailed && (
          <div className="min-h-0 flex-1 overflow-auto bg-muted">
            <img
              src={`/demo/${feature.id}.webp`}
              alt={feature.title}
              onError={() => setImageFailed(true)}
              className="mx-auto block h-auto w-full"
            />
          </div>
        )}

        <div className="shrink-0 p-5 min-[560px]:p-6">
          <div className="flex items-center gap-2.5 pr-10">
            <span className="inline-flex rounded-lg bg-accent/15 p-2 text-accent">
              {feature.icon}
            </span>
            <h2 className="font-display text-xl font-bold">{feature.title}</h2>
          </div>
          <p className="mt-2 text-sm leading-relaxed text-muted-foreground">{feature.text}</p>

          <div className="mt-5 flex flex-col gap-2 min-[560px]:flex-row">
            <Link
              to="/register"
              onClick={onClose}
              className="rounded-[12px] bg-primary px-6 py-3 text-center text-[15px] font-bold text-primary-foreground hover:brightness-110"
            >
              {t('guestGateRegister', 'Creează cont gratuit')}
            </Link>
            <Link
              to="/login"
              onClick={onClose}
              className="rounded-[12px] border border-border px-6 py-3 text-center text-[15px] font-bold text-foreground hover:bg-muted"
            >
              {t('guestGateLogin', 'Am deja cont')}
            </Link>
          </div>
        </div>
      </div>
    </div>
  );
}
