import { Injectable } from '@nestjs/common';
import { TranslateRequestHandler } from './translate-request.handler';

@Injectable()
export class TranslateResponseHandler {
  constructor(private translateRequest: TranslateRequestHandler) {}

  async handle(userMessage: string, context?: Record<string, string>): Promise<string> {
    if (!userMessage || userMessage.trim().length === 0) {
      return '';
    }
    // Simplu: traduce doar textul primit; contextul poate fi extins mai târziu
    // (ex. păstrarea unor porțiuni fixe nedeplite).
    const textToTranslate = userMessage.trim();
    return this.translateRequest.translate(textToTranslate);
  }
}
