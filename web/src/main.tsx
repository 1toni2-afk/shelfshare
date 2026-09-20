import { StrictMode, useEffect } from 'react';
import { createRoot } from 'react-dom/client';
import { QueryClientProvider } from '@tanstack/react-query';
import { RouterProvider } from 'react-router-dom';
import { queryClient } from '@/lib/api/queryClient';
import { AuthProvider } from '@/features/auth/AuthProvider';
import { ToastProvider } from '@/components/ui/Toast';
import { router } from '@/app/router';
import { i18nReady } from '@/lib/i18n';
import '@/styles/index.css';

const container = document.getElementById('root');
if (!container) throw new Error('#root lipsește din index.html');

/**
 * Scoate din pagină conținutul pre-randat de scripts/beta-server.js, odată ce
 * aplicația a desenat primul cadru.
 *
 * Blocul acela (#seo-content) e varianta de text pur a paginii publice, pusă
 * în HTML pentru crawlere și pentru cine n-are JavaScript. Lăsat pe loc după
 * montarea aplicației, ar rămâne al doilea exemplar al aceleiași pagini,
 * dedesubt.
 *
 * Se șterge, NU se ascunde cu `display:none`: un text ascuns pe care îl vede
 * doar robotul e exact ce caută motoarele de căutare când penalizează
 * conținutul „doar pentru crawlere". Aici pagina chiar se înlocuiește cu
 * versiunea interactivă a aceluiași conținut.
 *
 * Într-un efect, nu imediat după `render`: randarea în React 19 nu e garantat
 * sincronă, deci ștergerea de îndată ar putea lăsa o clipă ecranul complet
 * gol, între dispariția textului și apariția aplicației. Efectele rulează
 * după ce DOM-ul e deja actualizat.
 */
function RemovePrerenderedContent() {
  useEffect(() => {
    document.getElementById('seo-content')?.remove();
  }, []);
  return null;
}

// Montăm DUPĂ ce s-a încărcat fișierul de limbă. Fără așteptarea asta, primul
// render prinde i18next neinițializat și afișează cheile brute
// („authLoginSubmit" în loc de „Conectare") pentru o fracțiune de secundă, la
// fiecare încărcare de pagină.
void i18nReady.then(() => {
  createRoot(container).render(
    <StrictMode>
      {/*
        QueryClientProvider e DEASUPRA lui AuthProvider, nu invers: la logout și
        la schimbarea de cont, AuthProvider golește cache-ul (queryClient.clear),
        deci are nevoie de el prin context. Fără ordinea asta, un al doilea login
        pe același browser afișa pentru o clipă biblioteca contului anterior.
      */}
      <QueryClientProvider client={queryClient}>
        <ToastProvider>
          <AuthProvider>
            <RemovePrerenderedContent />
            <RouterProvider router={router} />
          </AuthProvider>
        </ToastProvider>
      </QueryClientProvider>
    </StrictMode>,
  );
});
