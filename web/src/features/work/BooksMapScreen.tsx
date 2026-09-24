import { useQuery } from '@tanstack/react-query';
import { useNavigate } from 'react-router-dom';
import { useTranslation } from 'react-i18next';
import { ScreenHeader } from '@/components/layout/ScreenHeader';
import { MapContainer, Marker, TileLayer, Tooltip } from 'react-leaflet';
import L from 'leaflet';
import { mapRepository, workKeys } from './workRepository';
import { ErrorNotice, Spinner } from '@/components/ui';
import { useTheme } from '@/lib/theme/themeStore';
import 'leaflet/dist/leaflet.css';

/** Centrul geografic al României și zoom-ul care încadrează toată țara. */
const ROMANIA_CENTER: [number, number] = [45.9432, 24.9668];
const INITIAL_ZOOM = 6.3;

/**
 * Plăcile vin de la CartoDB, NU de la tile.openstreetmap.org.
 *
 * OSM descurajează explicit folosirea directă în producție (politica lor de
 * trafic/User-Agent) și poate degrada silențios plăcile. CartoDB servește
 * aceleași date OpenStreetMap, gratuit, fără cheie API și cu CORS permisiv.
 *
 * Stilul urmează tema: „Dark Matter" pe întuneric, altfel o hartă luminoasă pe
 * un UI închis bate brutal la ochi.
 */
const TILES = {
  light: 'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png',
  dark: 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png',
};

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
            scrollWheelZoom
            className="h-full w-full"
          >
            <TileLayer
              url={dark ? TILES.dark : TILES.light}
              subdomains={['a', 'b', 'c', 'd']}
              maxZoom={20}
              attribution='&copy; OpenStreetMap contributors &copy; CARTO'
            />

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
