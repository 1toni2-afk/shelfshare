import { useEffect } from 'react';
import { useQuery } from '@tanstack/react-query';
import { useNavigate } from 'react-router-dom';
import { useTranslation } from 'react-i18next';
import { ScreenHeader } from '@/components/layout/ScreenHeader';
import { MapContainer, Marker, Tooltip, useMap } from 'react-leaflet';
import L from 'leaflet';
import { maplibreGL } from '@maplibre/maplibre-gl-leaflet';
import { setWorkerUrl } from 'maplibre-gl';
import maplibreWorkerUrl from 'maplibre-gl/dist/maplibre-gl-worker.mjs?worker&url';
import { mapRepository, workKeys } from './workRepository';
import { ErrorNotice, Spinner } from '@/components/ui';
import { useTheme } from '@/lib/theme/themeStore';
import 'leaflet/dist/leaflet.css';
import 'maplibre-gl/dist/maplibre-gl.css';

/** Centrul geografic al României și zoom-ul care încadrează toată țara. */
const ROMANIA_CENTER: [number, number] = [45.9432, 24.9668];
const INITIAL_ZOOM = 6.3;

/**
 * Harta de bază vine de la OpenFreeMap: open source, gratuit, fără cheie API
 * și fără limită de cereri, pe date OpenStreetMap.
 *
 * NU CartoDB: din 2026 întoarce o placă „API KEY REQUIRED" pentru orice
 * cerere venită de pe un site (după Referer) - de pe server, fără Referer,
 * pare în continuare să meargă, deci defectul nu se vede din curl.
 * NU tile.openstreetmap.org: politica lor descurajează folosirea directă în
 * aplicații și nu are stil întunecat.
 *
 * OpenFreeMap servește doar plăci VECTORIALE, deci le desenează MapLibre GL,
 * pus ca strat în Leaflet - marcajele orașelor rămân Leaflet, neschimbate.
 *
 * Stilul urmează tema: „dark" pe întuneric, altfel o hartă luminoasă pe un UI
 * închis bate brutal la ochi.
 */
const MAP_STYLES = {
  light: 'https://tiles.openfreemap.org/styles/positron',
  dark: 'https://tiles.openfreemap.org/styles/dark',
};

// MapLibre 6 își caută workerul relativ la propriul fișier (import.meta.url),
// iar Vite mută fișierul acela - și la pre-bundling în dev, și la build -
// deci harta rămânea goală cu „Worker failed to load". `?worker&url` pune
// Vite să împacheteze singur workerul (cu tot cu modulul comun) și ne dă URL-ul.
setWorkerUrl(maplibreWorkerUrl);

const MAP_ATTRIBUTION =
  '<a href="https://openfreemap.org" target="_blank" rel="noopener">OpenFreeMap</a> ' +
  '&copy; <a href="https://www.openmaptiles.org/" target="_blank" rel="noopener">OpenMapTiles</a> ' +
  '&copy; <a href="https://www.openstreetmap.org/copyright" target="_blank" rel="noopener">OpenStreetMap</a>';

export function BooksMapScreen() {
  const { t } = useTranslation();
  const { dark } = useTheme();
  const navigate = useNavigate();

  const cities = useQuery({
    queryKey: workKeys.mapCities(),
    queryFn: ({ signal }) => mapRepository.cities(signal),
  });

  if (cities.isPending) {
    return (
      <div className="flex min-h-dvh items-center justify-center text-accent">
        <Spinner size={28} />
      </div>
    );
  }

  if (cities.isError) {
    return (
      <div className="mx-auto max-w-2xl p-6">
        <ErrorNotice message={t('mapLoadError')} onRetry={() => void cities.refetch()} />
      </div>
    );
  }

  return (
    <div className="flex h-[calc(100dvh-4rem)] flex-col">
      <ScreenHeader title={t('mapTitle')} back />

      {cities.data.length === 0 ? (
        <p className="flex flex-1 items-center justify-center text-muted-foreground">
          {t('mapEmpty')}
        </p>
      ) : (
        <div className="min-h-0 flex-1">
          {/*
            `key={dark}`: schimbarea temei trebuie să remonteze harta, altfel
            Leaflet păstrează stratul de plăci vechi - stilul întunecat ar
            rămâne peste tema luminoasă până la un reload.
          */}
          <MapContainer
            key={String(dark)}
            center={ROMANIA_CENTER}
            zoom={INITIAL_ZOOM}
            // Plafonul îl dădea înainte stratul de plăci raster; stratul
            // MapLibre nu-l comunică lui Leaflet, iar fără el zoom-ul n-ar
            // avea limită.
            maxZoom={18}
            scrollWheelZoom
            className="h-full w-full"
          >
            <VectorBaseMap style={dark ? MAP_STYLES.dark : MAP_STYLES.light} />

            {cities.data.map((city) => (
              <Marker
                key={city.city}
                position={[city.lat, city.lng]}
                icon={cityIcon(city.count)}
                eventHandlers={{
                  // Clic pe oraș = răsfoire filtrată pe orașul acela. Harta e
                  // un mod de a intra în catalog, nu o destinație în sine.
                  click: () => void navigate(`/browse?city=${encodeURIComponent(city.city)}`),
                }}
              >
                <Tooltip direction="top" offset={[0, -8]}>
                  {city.city} · {t('mapCityBooksCount', { count: city.count })}
                </Tooltip>
              </Marker>
            ))}
          </MapContainer>
        </div>
      )}
    </div>
  );
}

/**
 * Stratul MapLibre ca layer Leaflet. react-leaflet nu are o componentă pentru
 * el, deci îl adăugăm manual pe harta din context și îl scoatem la demontare.
 */
function VectorBaseMap({ style }: { style: string }) {
  const map = useMap();

  useEffect(() => {
    const layer = maplibreGL({ style, attributionControl: false });
    layer.addTo(map);
    map.attributionControl.addAttribution(MAP_ATTRIBUTION);
    return () => {
      map.attributionControl.removeAttribution(MAP_ATTRIBUTION);
      layer.remove();
    };
  }, [map, style]);

  return null;
}

/**
 * Marcaj propriu, nu cel implicit al Leaflet.
 *
 * Două motive: iconița implicită se încarcă dintr-un PNG al bibliotecii, a
 * cărui cale se rupe la bundling (problema clasică „marker invizibil" cu
 * Leaflet + bundlere), iar noi vrem oricum să arătăm NUMĂRUL de cărți direct
 * pe hartă, nu doar o pioneză.
 *
 * Dimensiunea crește cu numărul, plafonată: fără plafon, un oraș cu mii de
 * cărți ar acoperi jumătate de țară.
 */
function cityIcon(count: number): L.DivIcon {
  const size = Math.min(56, 28 + Math.log10(count + 1) * 14);
  return L.divIcon({
    className: '',
    html: `<div style="
      width:${size}px;height:${size}px;
      display:flex;align-items:center;justify-content:center;
      border-radius:9999px;
      background:var(--ss-accent);color:var(--ss-accent-foreground);
      font-weight:700;font-size:${Math.max(11, size / 3.4)}px;
      box-shadow:0 2px 8px rgba(0,0,0,.35);
      border:2px solid var(--ss-card);
    ">${count}</div>`,
    iconSize: [size, size],
    iconAnchor: [size / 2, size / 2],
  });
}
