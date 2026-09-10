import { Injectable } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { HttpService } from '@nestjs/axios';
import { lastValueFrom } from 'rxjs';

@Injectable()
export class TranslateRequestHandler {
  constructor(
    private config: ConfigService,
    private http: HttpService,
  ) {}

  async translate(text: string): Promise<string> {
    const host = this.config.get<string>('LIBRETRANSLATE_HOST') ?? 'localhost';
    const port = this.config.get<number>('LIBRETRANSLATE_PORT') ?? 5000;
    const url = `http://${host}:${port}/translate`;

    // Raspunsul e tipat pe generic-ul lui post<T>, nu castuit dupa aceea:
    // altfel `data` ramane `any` si accesul la .translatedText trece
    // neverificat - exact ce semnala no-unsafe-member-access. Campul e optional
    // pentru ca un LibreTranslate care raspunde cu eroare nu il trimite deloc.
    const response = await lastValueFrom(
      this.http.post<{ translatedText?: string }>(url, {
        q: text,
        source: 'ro',
        target: 'en',
        format: 'text',
      }),
    );

    return response.data.translatedText ?? text;
  }
}
