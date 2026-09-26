import { useState } from 'react';
import { useTranslation } from 'react-i18next';
import {
  CreditCard,
  Flag,
  MapPin,
  MessageCircle,
  Shield,
  ShieldAlert,
} from 'lucide-react';
import { cn } from '@/lib/utils/cn';
import { staticPageUrl } from '@/lib/staticPages';

/**
 * Panoul din dreapta al chatului pe desktop, cât timp nu e deschisă nicio
 * conversație. Port al `_ChatSafetyPage` din conversations_list_screen.dart.
 */
export function ChatSafetyPane() {
  const { t, i18n } = useTranslation();

  return (
    <div className="mx-auto w-full max-w-[620px] px-6 py-8">
      <div className="flex items-center gap-3.5">
        <span className="flex size-11 shrink-0 items-center justify-center rounded-[12px] bg-accent/15 text-accent">
          <MessageCircle size={24} />
        </span>
        <h2 className="min-w-0 font-display text-2xl font-bold">{t('chatSafetyHeadline')}</h2>
      </div>

      <p className="mt-4 leading-relaxed text-muted-foreground">{t('chatSafetyIntro')}</p>

      <ul className="mt-6 flex flex-col gap-5">
        <SafetyItem
          icon={<ShieldAlert size={20} />}
          title={t('chatSafetyPersonalTitle')}
          body={t('chatSafetyPersonalBody')}
        />
        <SafetyItem
          icon={<CreditCard size={20} />}
          title={t('chatSafetyPaymentTitle')}
          body={t('chatSafetyPaymentBody')}
        />
        <SafetyItem
          icon={<MapPin size={20} />}
          title={t('chatSafetyMeetupTitle')}
          body={t('chatSafetyMeetupBody')}
        />
        <SafetyItem
          icon={<Flag size={20} />}
          title={t('chatSafetyReportTitle')}
          body={t('chatSafetyReportBody')}
        />
      </ul>

      <SafetyQuiz />

      <a
        href={staticPageUrl('safety-center', i18n.language)}
        target="_blank"
        rel="noreferrer"
        className="mt-6 inline-flex items-center gap-2 rounded-[12px] border border-border px-4 py-2.5 text-sm font-medium hover:bg-muted"
      >
        <Shield size={18} />
        {t('chatSafetyOpenCenter')}
      </a>

      <p className="mt-4 text-sm text-muted-foreground">{t('chatSafetyHint')}</p>
    </div>
  );
}

export function SafetyItem({
  icon,
  title,
  body,
}: {
  icon: React.ReactNode;
  title: string;
  body: string;
}) {
  return (
    <li className="flex gap-3">
      <span className="mt-0.5 shrink-0 text-accent">{icon}</span>
      <span className="min-w-0">
        <span className="block font-semibold">{title}</span>
        <span className="block text-sm leading-relaxed text-muted-foreground">{body}</span>
      </span>
    </li>
  );
}

/**
 * Testul de siguranță. Sfaturile scrise le citește puțină lume; aceleași reguli
 * sub formă de întrebare se rețin, fiindcă întâi alegi, apoi vezi de ce.
 *
 * Totul e local (fără rețea, fără scor salvat): scopul e să se citească
 * explicațiile, nu să se țină o statistică.
 */
function SafetyQuiz() {
  const { t } = useTranslation();
  const [started, setStarted] = useState(false);
  const [index, setIndex] = useState(0);
  const [selected, setSelected] = useState<number | null>(null);
  const [score, setScore] = useState(0);
  const [done, setDone] = useState(false);

  /**
   * Întrebările se construiesc la fiecare randare, nu o dată la pornire: limba
   * se schimbă din Setări fără reîncărcare, iar o listă statică ar rămâne în
   * limba de la primul build.
   *
   * Răspunsul corect NU e mereu pe aceeași poziție - altfel testul s-ar rezolva
   * din reflex, nu din citit.
   */
  const questions = [1, 2, 3, 4, 5].map((n, position) => ({
    text: t(`chatQuizQ${n}`),
    options: [t(`chatQuizQ${n}A`), t(`chatQuizQ${n}B`), t(`chatQuizQ${n}C`)],
    correctIndex: [1, 2, 0, 1, 2][position],
    explanation: t(`chatQuizQ${n}Explain`),
  }));

  const total = questions.length;

  return (
    <section className="mt-6 rounded-[16px] border border-border bg-card p-4">
      {!started ? (
        <>
          <p className="flex items-center gap-2 font-semibold">
            <Shield size={18} className="text-accent" />
            {t('chatQuizTitle')}
          </p>
          <p className="mt-2 text-sm text-muted-foreground">{t('chatQuizIntro')}</p>
          <button
            onClick={() => setStarted(true)}
            className="mt-3 rounded-[12px] bg-primary px-5 py-2.5 text-sm font-bold text-primary-foreground hover:brightness-110"
          >
            {t('chatQuizStart')}
          </button>
        </>
      ) : done ? (
        <>
          <p className="font-semibold">{t('chatQuizScore', { score, total })}</p>
          <p className="mt-2 text-sm text-muted-foreground">
            {score === total
              ? t('chatQuizResultPerfect')
              : score * 5 >= total * 3
                ? t('chatQuizResultGood')
                : t('chatQuizResultPoor')}
          </p>
        </>
      ) : (
        <QuizQuestion
          question={questions[index]}
          index={index}
          total={total}
          selected={selected}
          onAnswer={(choice) => {
            setSelected(choice);
            if (choice === questions[index].correctIndex) setScore((current) => current + 1);
          }}
          onNext={() => {
            if (index + 1 >= total) {
              setDone(true);
              return;
            }
            setIndex((current) => current + 1);
            setSelected(null);
          }}
        />
      )}
    </section>
  );
}

function QuizQuestion({
  question,
  index,
  total,
  selected,
  onAnswer,
  onNext,
}: {
  question: { text: string; options: string[]; correctIndex: number; explanation: string };
  index: number;
  total: number;
  selected: number | null;
  onAnswer: (choice: number) => void;
  onNext: () => void;
}) {
  const { t } = useTranslation();
  const answered = selected !== null;
  const isCorrect = selected === question.correctIndex;

  return (
    <>
      <p className="text-xs text-muted-foreground">
        {t('chatQuizProgress', { current: index + 1, total })}
      </p>
      <p className="mt-1 font-semibold">{question.text}</p>

      <div className="mt-3 flex flex-col gap-2">
        {question.options.map((option, position) => (
          <button
            key={option}
            disabled={answered}
            onClick={() => onAnswer(position)}
            className={cn(
              'rounded-[12px] border px-4 py-2.5 text-left text-sm transition',
              !answered && 'border-border hover:bg-muted',
              answered && position === question.correctIndex && 'border-success bg-success/10',
              answered &&
                position === selected &&
                position !== question.correctIndex &&
                'border-destructive bg-destructive/10',
              answered &&
                position !== question.correctIndex &&
                position !== selected &&
                'border-border opacity-60',
            )}
          >
            {option}
          </button>
        ))}
      </div>

      {answered && (
        <>
          <p className={cn('mt-3 font-semibold', isCorrect ? 'text-success' : 'text-destructive')}>
            {t(isCorrect ? 'chatQuizCorrect' : 'chatQuizWrong')}
          </p>
          <p className="mt-1 text-sm text-muted-foreground">{question.explanation}</p>
          <button
            onClick={onNext}
            className="mt-3 rounded-[12px] bg-primary px-5 py-2.5 text-sm font-bold text-primary-foreground hover:brightness-110"
          >
            {t(index + 1 >= total ? 'chatQuizSeeResult' : 'chatQuizNext')}
          </button>
        </>
      )}
    </>
  );
}
