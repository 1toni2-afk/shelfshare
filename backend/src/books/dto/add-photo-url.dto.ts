import { IsUrl } from 'class-validator';

export class AddPhotoUrlDto {
  @IsUrl({ protocols: ['http', 'https'], require_protocol: true })
  url: string;
}
