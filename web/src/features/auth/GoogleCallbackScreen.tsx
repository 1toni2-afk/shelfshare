import { useEffect, useRef } from 'react';
import { useNavigate, useSearchParams } from 'react-router-dom';
import { FullScreenLoader } from '@/components/ui';
import { useAuth } from './AuthProvider';

/**
 * Ecran tranzitoriu: aici ajunge browserul după ce backendul redirecționează
 * înapoi din fluxul Google OAuth, cu un COD de schimb în query string - nu cu
 * token-uri. Codul se preschimbă pe token-uri reale printr-un apel API
 * separat, deci token-urile nu trec niciodată prin URL-ul browserului (unde
 * ar ajunge în istoric, în Referer și în logurile oricărui proxy).
 */
export function GoogleCallbackScreen() {
  const [params] = useSearchParams();
  const navigate = useNavigate();
  const { completeExternalLogin } = useAuth();

  // StrictMode montează de două ori în dev. Codul e de unică folosință: a doua
  // preschimbare ar eșua, iar userul ar fi trimis la login deși prima reușise.
  const started = useRef(false);

  useEffect(() => {
    if (started.current) return;
    started.current = true;

    const code = params.get('code');
    if (!code) {
      void navigate('/login', { replace: true });
      return;
    }

    void completeExternalLogin(code).then(() => {
      // `replace`, nu push: altfel butonul de back al browserului readuce
      // userul pe callback-ul cu un cod deja consumat.
      void navigate('/', { replace: true });
    });
  }, [params, completeExternalLogin, navigate]);

  return <FullScreenLoader />;
}
