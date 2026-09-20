import { defineConfig, loadEnv } from 'vite';
import react from '@vitejs/plugin-react';
import tailwindcss from '@tailwindcss/vite';
import path from 'node:path';
import fs from 'node:fs';
import { createRequire } from 'node:module';
import type { Plugin } from 'vite';
import pkg from './package.json' with { type: 'json' };

/**
 * Servește în DEV paginile publice plain-HTML (centrul de siguranță, întrebări
 * frecvente, despre dezvoltator, confidențialitate, termeni).
 *
 * În producție le servește beta-server.js din aceeași hartă. Fără pluginul
 * ăsta, în dev orice rută necunoscută primește index.html, deci
 * StaticPageScreen ar primi shell-ul aplicației în loc de pagină și ar desena
 * un ecran gol - un bug care apare DOAR pe mașina de dezvoltare, exact genul
 * care se descoperă târziu.
 */
function staticPagesPlugin(): Plugin {
  const require = createRequire(import.meta.url);
  const { STATIC_HTML_PAGES } = require('../scripts/static-pages.js') as {
    STATIC_HTML_PAGES: Record<string, string>;
  };

  return {
    name: 'shelfshare-static-pages',
    configureServer(server) {
      server.middlewares.use((req, res, next) => {
        const url = (req.url ?? '').split('?')[0];
        const file = STATIC_HTML_PAGES[url];
        if (!file || !fs.existsSync(file)) return next();
        res.setHeader('Content-Type', 'text/html; charset=utf-8');
        res.end(fs.readFileSync(file));
      });
    },
  };
}

// Oglindește ApiConfig din frontend/lib/core/network/api_client.dart: în
// release cădem pe producție, nu pe localhost. Un build fără variabila setată
// ajungea altfel cu "localhost:3000" compilat în bundle, adică fiecare cerere
// de pe telefon lovea telefonul însuși - vezi comentariul din api_client.dart.
const DEFAULT_API = {
  development: 'http://localhost:3000',
  production: 'https://api.shelfshare.ro',
} as const;

export default defineConfig(({ mode }) => {
  const env = loadEnv(mode, process.cwd(), '');
  const apiBaseUrl =
    env.VITE_API_BASE_URL ||
    (mode === 'production' ? DEFAULT_API.production : DEFAULT_API.development);

  return {
    plugins: [react(), tailwindcss(), staticPagesPlugin()],
    resolve: {
      alias: { '@': path.resolve(__dirname, 'src') },
    },
    define: {
      // Injectat la build, nu citit din process.env la runtime: bundle-ul
      // ajunge și în APK-ul Capacitor, unde nu există niciun server care să
      // livreze variabile de mediu.
      __API_BASE_URL__: JSON.stringify(apiBaseUrl),
      __BUILD_TIME__: JSON.stringify(new Date().toISOString()),
      __APP_VERSION__: JSON.stringify(pkg.version),
    },
    server: {
      port: 5173,
      // Nu proxiem /api: aplicația vorbește cu backendul pe origine completă,
      // exact ca pe producție, deci CORS-ul e exersat și în dev.
      strictPort: true,
    },
    build: {
      outDir: 'dist',
      sourcemap: true,
      // Chunk-uri manuale pe librăriile grele, ca prima încărcare să nu aducă
      // hărți/chart-uri de care ecranul de login n-are nevoie. Echivalentul
      // „tiers"-elor de import amânat din app_router.dart.
      rollupOptions: {
        output: {
          manualChunks: {
            'react-vendor': ['react', 'react-dom', 'react-router-dom'],
            'query-vendor': ['@tanstack/react-query'],
            'i18n-vendor': ['i18next', 'react-i18next', 'i18next-icu', 'intl-messageformat'],
          },
        },
      },
    },
  };
});
