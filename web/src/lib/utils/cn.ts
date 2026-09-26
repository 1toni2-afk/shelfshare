import { clsx, type ClassValue } from 'clsx';
import { twMerge } from 'tailwind-merge';

/** Compune clase Tailwind rezolvand conflictele (ultima castiga). */
export function cn(...inputs: ClassValue[]): string {
  return twMerge(clsx(inputs));
}
