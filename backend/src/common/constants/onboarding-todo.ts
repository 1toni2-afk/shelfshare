/**
 * Pașii din lista „Primii pași" arătată pe Home celor abia veniți.
 *
 * Sursa adevărului pentru UI e `enum OnboardingTodo` din frontend
 * (features/profile/application/onboarding_todo_controller.dart); lista de
 * aici există doar ca să nu ajungă în coloană orice text trimis de un client.
 * Ordinea nu contează - afișarea o decide frontendul.
 */
export const ONBOARDING_TODO_STEPS = [
  'tutorial',
  'bookMatch',
  'import',
  'shortcuts',
] as const;

export type OnboardingTodoStep = (typeof ONBOARDING_TODO_STEPS)[number];

export function isOnboardingTodoStep(value: string): value is OnboardingTodoStep {
  return (ONBOARDING_TODO_STEPS as readonly string[]).includes(value);
}
