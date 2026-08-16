import { HttpService } from '@nestjs/axios';
import { Injectable, Logger } from '@nestjs/common';
import { firstValueFrom } from 'rxjs';

export type MeetingPointCategory = 'library' | 'cafe' | 'mall';

export interface PlaceResult {
  displayName: string;
  lat: number;
  lng: number;
  category?: MeetingPointCategory;
}

interface OverpassElement {
  lat: number;
  lon: number;
  tags?: { name?: string; amenity?: string; shop?: string };
}

@Injectable()
export class PlacesService {
  private readonly logger = new Logger(PlacesService.name);

  // Cache simplu în memorie pentru căutările de locații. Nominatim e lent și
  // limitat la ~1 cerere/secundă per IP - fără cache, fiecare tastare (chiar
  // și re-tastarea aceluiași oraș) mai lovește o dată API-ul, de unde senzația
  // de „super greoi". TTL scurt fiindcă rezultatele nu se schimbă des; capăt
  // de dimensiune ca să nu crească la nesfârșit.
  private readonly searchCache = new Map<
    string,
    { at: number; results: PlaceResult[] }
  >();
  private static readonly CACHE_TTL_MS = 10 * 60 * 1000;
  private static readonly CACHE_MAX = 500;

  constructor(private http: HttpService) {}

  /**
   * Căutare de locații prin Nominatim (OpenStreetMap) - gratuit, fără cheie
   * API. Politica lor de utilizare cere un User-Agent care identifică
   * aplicația și un volum rezonabil de cereri (suficient pentru căutare
   * live cu debounce dintr-un chat, nu pentru trafic de producție masiv).
   */
  async search(query: string): Promise<PlaceResult[]> {
    const normalized = query.trim().toLowerCase();
    if (normalized.length < 3) return [];

    const cached = this.searchCache.get(normalized);
    if (cached && Date.now() - cached.at < PlacesService.CACHE_TTL_MS) {
      return cached.results;
    }

    try {
      const url = 'https://nominatim.openstreetmap.org/search';
      const { data } = await firstValueFrom(
        this.http.get<{ display_name: string; lat: string; lon: string }[]>(
          url,
          {
            params: {
              q: query,
              format: 'json',
              limit: 8,
              countrycodes: 'ro',
            },
            headers: {
              'User-Agent': 'ShelfShare/1.0 (aplicatie schimb de carti)',
            },
            // Autocomplete: mai bine eșuăm repede decât să lăsăm câmpul să se
            // învârtă până la timeout-ul global (8s). Overpass (meeting-points)
            // are nevoie de mai mult, de aceea îl scurtăm doar aici, per cerere.
            timeout: 5000,
          },
        ),
      );

      const results = data.map((item) => ({
        displayName: item.display_name,
        lat: parseFloat(item.lat),
        lng: parseFloat(item.lon),
      }));
      this.cacheSearch(normalized, results);
      return results;
    } catch (error) {
      this.logger.warn(`Căutare locație eșuată pentru "${query}": ${error}`);
      return [];
    }
  }

  private cacheSearch(key: string, results: PlaceResult[]) {
    // Curățare grosolană când umple: ștergem prima (cea mai veche) intrare.
    // Map păstrează ordinea de inserare, deci e suficient pentru un cap simplu.
    if (this.searchCache.size >= PlacesService.CACHE_MAX) {
      const oldest = this.searchCache.keys().next().value as string | undefined;
      if (oldest !== undefined) this.searchCache.delete(oldest);
    }
    this.searchCache.set(key, { at: Date.now(), results });
  }

  /**
   * Sugestii de locuri publice, potrivite pentru o întâlnire de schimb de
   * cărți (biblioteci, cafenele, mall-uri), lângă un punct dat. Nominatim
   * (folosit la `search`) e un geocoder de adrese, nu un motor de căutare
   * "ce e în jur pe categorie" - pentru asta e nevoie de Overpass API, care
   * interoghează direct datele OpenStreetMap după tag-uri (amenity/shop),
   * tot gratuit și fără cheie.
   */
  async findMeetingPoints(lat: number, lng: number): Promise<PlaceResult[]> {
    const radiusMeters = 2000;
    const query = `[out:json][timeout:10];(
      node["amenity"="library"](around:${radiusMeters},${lat},${lng});
      node["amenity"="cafe"](around:${radiusMeters},${lat},${lng});
      node["shop"="mall"](around:${radiusMeters},${lat},${lng});
    );out center 30;`;

    try {
      const { data } = await firstValueFrom(
        this.http.post<{ elements: OverpassElement[] }>(
          'https://overpass-api.de/api/interpreter',
          `data=${encodeURIComponent(query)}`,
          {
            headers: {
              'Content-Type': 'application/x-www-form-urlencoded',
              'User-Agent': 'ShelfShare/1.0 (aplicatie schimb de carti)',
            },
          },
        ),
      );

      return data.elements
        .filter((el) => el.tags?.name)
        .map((el) => ({
          displayName: el.tags!.name!,
          lat: el.lat,
          lng: el.lon,
          category: this.categoryOf(el.tags!),
        }))
        .sort(
          (a, b) =>
            this.distance(lat, lng, a.lat, a.lng) -
            this.distance(lat, lng, b.lat, b.lng),
        )
        .slice(0, 15);
    } catch (error) {
      this.logger.warn(
        `Căutare puncte de întâlnire eșuată pentru (${lat}, ${lng}): ${error}`,
      );
      return [];
    }
  }

  private categoryOf(tags: {
    amenity?: string;
    shop?: string;
  }): MeetingPointCategory {
    if (tags.amenity === 'library') return 'library';
    if (tags.amenity === 'cafe') return 'cafe';
    return 'mall';
  }

  private distance(
    lat1: number,
    lng1: number,
    lat2: number,
    lng2: number,
  ): number {
    const dLat = lat2 - lat1;
    const dLng = lng2 - lng1;
    return dLat * dLat + dLng * dLng;
  }
}
