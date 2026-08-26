import { Injectable } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { HttpService } from '@nestjs/axios';
import { lastValueFrom } from 'rxjs';
import type { AxiosResponse } from 'axios';

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

    const response = await lastValueFrom(
      this.http.post(url, {
        q: text,
        source: 'ro',
        target: 'en',
        format: 'text',
      }),
    );

    return (response?.data?.translatedText as string) ?? text;
  }
}
