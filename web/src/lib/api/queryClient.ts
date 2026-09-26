import { QueryClient } from '@tanstack/react-query';
import { ApiError } from './client';

export const queryClient = new QueryClient({
  defaultOptions: {
    queries: {
      // 30s: destul cât navigarea înainte-înapoi între ecrane să nu refacă
      // aceleași cereri, dar nu atât încât un anunț editat să pară neschimbat.
      staleTime: 30_000,
      // Refetch la revenirea în tab e util pe web, dar pe mobil (Capacitor)
      // fiecare aducere din background ar declanșa un val de cereri. Îl lăsăm
      // pe seama ecranelor care chiar au nevoie de date proaspete.
      refetchOnWindowFocus: false,
      retry(failureCount, error) {
        // 4xx nu se repară prin reîncercare: 401 e deja tratat de client prin
        // refresh, iar 403/404 vor da același răspuns de fiecare dată. Doar
        // erorile de rețea și 5xx merită o a doua șansă.
        if (error instanceof ApiError && error.status !== null && error.status < 500) {
          return false;
        }
        return failureCount < 2;
      },
    },
    mutations: {
      retry: false,
    },
  },
});
