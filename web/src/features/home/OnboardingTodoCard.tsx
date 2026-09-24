import { useNavigate } from 'react-router-dom';
import { useTranslation } from 'react-i18next';
import {
  CheckCircle2,
  ChevronRight,
  Circle,
  Compass,
  Layers,
  PlayCircle,
  SlidersHorizontal,
  Upload,
  X,
} from 'lucide-react';
import {
  ONBOARDING_TODOS,
  useDismissOnboardingTodo,
  useOnboardingTodo,
  type OnboardingTodo,
} from './onboardingTodo';
import { useOpenShortcutsEditor } from '@/components/layout/AppShell';
import { cn } from '@/lib/utils/cn';

/**
 * „Descoperă ShelfShare" - lista de bifat a celui abia venit, sus în feed,
 * deasupra cărților. Port al `_OnboardingTodoCard` din home_screen.dart.
 *
 * Wizard-ul de onboarding întreabă cine e omul și ce-i place; lista asta îi
 * spune ce are de FĂCUT ca aplicația să-i fie utilă: turul scurt, o rundă de
 * Book Match, importul bibliotecii, scurtăturile.
 *
 * Nu se bifează manual: fiecare pas se marchează din locul unde s-a întâmplat
 * fapta. Dispare singură când s-au făcut toate sau când e ascunsă de la „×".
 */
export function OnboardingTodoCard() {
  const { t } = useTranslation();
  const navigate = useNavigate();
  const openShortcutsEditor = useOpenShortcutsEditor();
  const { done, visible } = useOnboardingTodo();
  const dismiss = useDismissOnboardingTodo();

  if (!visible) return null;

  function open(todo: OnboardingTodo) {
    switch (todo) {
      case 'tutorial':
        void navigate('/tutorial');
        return;
      case 'bookMatch':
        void navigate('/book-match');
        return;
      case 'import':
        void navigate('/import');
        return;
      case 'shortcuts':
        // Direct editarea scurtăturilor: e aceeași acțiune ca creionul din
        // meniu, dar merge la fel și pe telefon, unde meniul e un panou pe
        // care userul ar trebui întâi să-l deschidă.
        openShortcutsEditor();
    }
  }

  return (
    <div className="mb-3 rounded-[12px] border border-accent/35 bg-card pb-2 pl-4 pr-2 pt-3">
      <div className="flex items-start gap-2.5">
        <Compass size={18} className="mt-0.5 shrink-0 text-accent" />

        {/* Titlul, contorul și subtitlul într-o coloană elastică, nu pe un rând
            cu spațiu între: „Descoperă ShelfShare" plus „3 din 4" trec de
            lățimea unui telefon îngust, iar pe un rând ar da overflow. */}
        <div className="min-w-0 flex-1">
          <div className="flex flex-wrap items-center gap-x-2.5">
            <span className="text-sm font-bold">{t('todoTitle')}</span>
            <span className="text-xs text-muted-foreground">
              {t('todoProgress', { done: done.size, total: ONBOARDING_TODOS.length })}
            </span>
          </div>
          <p className="mt-0.5 text-xs text-muted-foreground">{t('todoSubtitle')}</p>
        </div>

        <button
          onClick={() => dismiss.mutate()}
          title={t('todoDismiss')}
          aria-label={t('todoDismiss')}
          className="shrink-0 rounded-md p-1.5 text-muted-foreground hover:bg-muted hover:text-foreground"
        >
          <X size={18} />
        </button>
      </div>

      <div className="mt-1">
        {ONBOARDING_TODOS.map((todo) => (
          <TodoRow key={todo} todo={todo} done={done.has(todo)} onClick={() => open(todo)} />
        ))}
      </div>
    </div>
  );
}

const ICONS: Record<OnboardingTodo, typeof Compass> = {
  tutorial: PlayCircle,
  bookMatch: Layers,
  import: Upload,
  shortcuts: SlidersHorizontal,
};

const LABELS: Record<OnboardingTodo, string> = {
  tutorial: 'todoTutorial',
  bookMatch: 'todoBookMatch',
  import: 'todoImport',
  shortcuts: 'todoShortcuts',
};

function TodoRow({
  todo,
  done,
  onClick,
}: {
  todo: OnboardingTodo;
  done: boolean;
  onClick: () => void;
}) {
  const { t } = useTranslation();
  const Icon = ICONS[todo];

  return (
    <button
      // Un pas bifat rămâne apăsabil: „vezi tutorialul" e ceva ce omul poate
      // vrea să revadă, iar scurtăturile se mai schimbă.
      onClick={onClick}
      className="flex w-full items-center gap-3 rounded-lg px-1 py-2 text-left hover:bg-muted"
    >
      {done ? (
        <CheckCircle2 size={18} className="shrink-0 text-success" />
      ) : (
        <Circle size={18} className="shrink-0 text-muted-foreground" />
      )}
      <Icon size={18} className="shrink-0 text-muted-foreground" />
      <span
        className={cn(
          'min-w-0 flex-1 truncate text-sm',
          done && 'text-muted-foreground line-through decoration-[var(--ss-muted-foreground)]',
        )}
      >
        {t(LABELS[todo])}
      </span>
      <ChevronRight size={18} className="shrink-0 text-muted-foreground" />
    </button>
  );
}
