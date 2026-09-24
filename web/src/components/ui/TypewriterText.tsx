import { useEffect, useRef, useState } from 'react';

export interface TypewriterPhrase {
  text: string;
  /** Cât stă fraza completă pe ecran înainte să înceapă ștergerea, în ms. */
  holdMs: number;
}

const TYPING_MS = 70;
const DELETING_MS = 35;
const CURSOR_BLINK_MS = 500;

/**
 * Scrie frazele literă cu literă, le ține un timp, apoi le șterge și trece la
 * următoarea. Port al shared/widgets/typewriter_text.dart.
 *
 * Cursorul „_" clipește independent de tastare - dacă ar fi legat de ea, ar
 * îngheța cât timp fraza stă afișată.
 */
export function TypewriterText({
  phrases,
  className,
}: {
  phrases: TypewriterPhrase[];
  className?: string;
}) {
  const [shown, setShown] = useState('');
  const [cursorOn, setCursorOn] = useState(true);

  // Frazele se recreează la fiecare randare a părintelui (sunt construite din
  // `t()`), dar conținutul lor e stabil. Ținem o referință ca efectul de mai
  // jos să NU repornească animația la fiecare randare - altfel textul ar
  // rămâne blocat pe prima literă.
  const phrasesRef = useRef(phrases);
  phrasesRef.current = phrases;

  // Cheia conținutului: dacă se schimbă CHIAR frazele (ex. s-a încărcat
  // numele userului după primul cadru), repornim de la zero. Fără asta, fraza
  // nouă ar fi citită la poziția de tastare veche - de aici „Toni Mu_" blocat.
  const key = phrases.map((phrase) => phrase.text).join('|');

  useEffect(() => {
    const timer = window.setInterval(() => setCursorOn((on) => !on), CURSOR_BLINK_MS);
    return () => window.clearInterval(timer);
  }, []);

  useEffect(() => {
    if (phrasesRef.current.length === 0) return;

    let cancelled = false;
    let index = 0;

    const sleep = (ms: number) =>
      new Promise<void>((resolve) => window.setTimeout(resolve, ms));

    async function run() {
      while (!cancelled) {
        const phrase = phrasesRef.current[index % phrasesRef.current.length];

        for (let i = 1; i <= phrase.text.length; i++) {
          if (cancelled) return;
          setShown(phrase.text.slice(0, i));
          await sleep(TYPING_MS);
        }

        await sleep(phrase.holdMs);
        if (cancelled) return;

        for (let i = phrase.text.length; i >= 0; i--) {
          if (cancelled) return;
          setShown(phrase.text.slice(0, i));
          await sleep(DELETING_MS);
        }

        index++;
      }
    }

    void run();
    return () => {
      cancelled = true;
    };
  }, [key]);

  return (
    <span className={className}>
      {shown}
      {/* `opacity`, nu montare/demontare: un caracter care apare și dispare din
          DOM ar face titlul să-și schimbe lățimea la fiecare clipire. */}
      <span style={{ opacity: cursorOn ? 1 : 0 }}>_</span>
    </span>
  );
}
