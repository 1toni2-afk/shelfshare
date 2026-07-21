import { HttpService } from '@nestjs/axios';
import { Injectable, Logger } from '@nestjs/common';
import { firstValueFrom } from 'rxjs';

export interface PlaceResult {
  displayName: string;
  lat: number;
  lng: number;
}

@Injectable()
export class PlacesService {
  private readonly logger = new Logger(PlacesService.name);

  constructor(private http: HttpService) {}

  /**
   * Căutare de locații prin Nominatim (OpenStreetMap) - gratuit, fără cheie
   * API. Politica lor de utilizare cere un User-Agent care identifică
   * aplicația și un volum rezonabil de cereri (suficient pentru căutare
   * live cu debounce dintr-un chat, nu pentru trafic de producție masiv).
   */
  async search(query: string): Promise<PlaceResult[]> {
    if (query.trim().length < 3) return [];

    try {
      const url = 'https://nominatim.openstreetmap.org/search';
      const { data } = await firstValueFrom(
        this.http.get<
          { display_name: string; lat: string; lon: string }[]
        >(url, {
          params: {
            q: query,
            format: 'json',
            limit: 8,
            countrycodes: 'ro',
          },
          headers: {
            'User-Agent': 'ShelfShare/1.0 (aplicatie schimb de carti)',
          },
        }),
      );

      return data.map((item) => ({
        displayName: item.display_name,
        lat: parseFloat(item.lat),
        lng: parseFloat(item.lon),
      }));
    } catch (error) {
      this.logger.warn(`Căutare locație eșuată pentru "${query}": ${error}`);
      return [];
    }
  }
}
