import { useCallback } from 'react';
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { api } from '@/lib/api/client';
import { useAuth } from '@/features/auth/AuthProvider';

/**
 * Pașii din lista „Descoperă ShelfShare" arătată pe Home celor abia veniți.
 *
 * Port al `enum OnboardingTodo` din onboarding_todo_controller.dart. Ordinea de
 * aici e ordinea de AFIȘARE; validarea valorilor o face backendul, din
 * common/constants/onboarding-todo.ts (aceleași patru nume).
 */
export const ONBOARDING_TODOS = ['tutorial', 'bookMatch', 'import', 'shortcuts'] as const;

export type OnboardingTodo = (typeof ONBOARDING_TODOS)[number];

export interface OnboardingTodoState {
  /** Numele pașilor bifați. Text, nu enum: un pas scos din aplicație nu
   *  trebuie să facă parsarea să crape pe un client vechi. */
  done: string[];
  dismissed: boolean;
}

const EMPTY: OnboardingTodoState = { done: [], dismissed: false };

export const onboardingTodoKey = ['profile', 'onboarding-todo'] as const;

export const onboardingTodoRepository = {
  get(signal?: AbortSignal): Promise<OnboardingTodoState> {
    return api.get<OnboardingTodoState>('/profile/me/onboarding-todo', { signal });
  },

  /**
   * Scriere parțială: `done` se REUNEȘTE pe server cu ce e deja bifat, iar
   * `dismissed` omis lasă valoarea neschimbată. Așa o bifă trimisă de pe
   * telefon nu șterge una pusă de pe laptop cu o clipă înainte.
   */
  save(input: { done?: OnboardingTodo[]; dismissed?: boolean }): Promise<OnboardingTodoState> {
    return api.post<OnboardingTodoState>('/profile/me/onboarding-todo', {
      done: input.done ?? [],
      ...(input.dismissed === undefined ? {} : { dismissed: input.dismissed }),
    });
  },
};

/**
 * Starea listei. Ține de CONT, nu de dispozitiv: pașii descriu ce a făcut omul
 * în aplicație (a văzut turul, și-a importat biblioteca), iar asta nu se uită
 * fiindcă s-a logat de pe alt aparat. Cache-ul se golește la login/logout
 * (`queryClient.clear()` din AuthProvider), deci nu poate rămâne pe ecran
 * lista altcuiva.
 */
export function useOnboardingTodo() {
  const { user } = useAuth();
  const query = useQuery({
    queryKey: onboardingTodoKey,
    queryFn: ({ signal }) => onboardingTodoRepository.get(signal),
    enabled: !!user,
    // Patru bife pe cont; nu merită reîncărcată la fiecare focus.
    staleTime: 5 * 60 * 1000,
  });

  const state = query.data ?? EMPTY;
  const done = new Set(state.done);
  const allDone = ONBOARDING_TODOS.every((todo) => done.has(todo));

  return {
    done,
    dismissed: state.dismissed,
    /**
     * Cât timp nu s-a terminat citirea nu arătăm nimic - altfel cineva care a
     * făcut demult toți pașii ar vedea cardul plin de căsuțe goale la fiecare
     * pornire.
     */
    visible: query.isSuccess && !state.dismissed && !allDone,
  };
}

/**
 * Bifează un pas. Se apelează din locul unde s-a întâmplat fapta (o rundă de
 * Book Match, un import reușit, o scurtătură schimbată) - nu cerem userului să
 * bifeze el, altfel lista ar minți.
 *
 * Best-effort: reuniunea o face serverul, deci un apel repetat e inofensiv, iar
 * o cerere picată se reia la următoarea faptă. Nu blocăm nimic pe ea.
 */
export function useCompleteOnboardingTodo() {
  const queryClient = useQueryClient();

  const mutation = useMutation({
    mutationFn: (todo: OnboardingTodo) => onboardingTodoRepository.save({ done: [todo] }),
    onSuccess: (next) => queryClient.setQueryData(onboardingTodoKey, next),
  });

  const { mutate } = mutation;
  return useCallback(
    (todo: OnboardingTodo) => {
      const current = queryClient.getQueryData<OnboardingTodoState>(onboardingTodoKey);
      // Dacă știm deja că e bifat, nu mai deranjăm serverul. Dacă nu știm
      // (lista n-a fost citită în sesiunea asta), trimitem oricum: e idempotent.
      if (current?.done.includes(todo)) return;
      mutate(todo);
    },
    [mutate, queryClient],
  );
}

/** „Ascunde" - lista nu mai apare pe Home, dar bifele rămân. */
export function useDismissOnboardingTodo() {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: () => onboardingTodoRepository.save({ dismissed: true }),
    // Optimist: cardul dispare la click, nu după dus-întors cu serverul.
    onMutate: () => {
      const previous = queryClient.getQueryData<OnboardingTodoState>(onboardingTodoKey);
      queryClient.setQueryData<OnboardingTodoState>(onboardingTodoKey, {
        done: previous?.done ?? [],
        dismissed: true,
      });
      return { previous };
    },
    onError: (_error, _variables, context) => {
      if (context?.previous) queryClient.setQueryData(onboardingTodoKey, context.previous);
    },
    onSuccess: (next) => queryClient.setQueryData(onboardingTodoKey, next),
  });
}
