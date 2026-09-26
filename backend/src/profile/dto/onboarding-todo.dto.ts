import { ArrayMaxSize, IsArray, IsBoolean, IsIn, IsOptional, IsString } from 'class-validator';
import { ONBOARDING_TODO_STEPS } from '../../common/constants/onboarding-todo';

/**
 * Scriere parțială și cumulativă: `done` se REUNEȘTE cu ce e deja bifat pe
 * cont, nu îl înlocuiește. Un pas bifat nu se mai poate debifa - nu există
 * bifare manuală, deci nici „m-am răzgândit"; iar semantica de reuniune e
 * exact ce-i trebuie migrării de pe dispozitiv pe cont, care trimite într-un
 * singur apel tot ce găsește în storage-ul local.
 */
export class OnboardingTodoDto {
  @IsOptional()
  @IsArray()
  @ArrayMaxSize(ONBOARDING_TODO_STEPS.length)
  @IsString({ each: true })
  @IsIn(ONBOARDING_TODO_STEPS as unknown as string[], { each: true })
  done?: string[];

  @IsOptional()
  @IsBoolean()
  dismissed?: boolean;
}
