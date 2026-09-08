import { IsUrl } from 'class-validator';

export class AddPhotoUrlDto {
  /// `require_tld: false` - pozele deja urcate ajung înapoi aici ca URL
  /// public de storage, iar în mediile de test acela e `http://localhost:
  /// 59000/...`. Cu TLD obligatoriu (implicit în validator.js), re-listarea
  /// unei cărți cu coperta preluată din anunțul vechi pica pe „url must be a
  /// URL address" fix la publish.
  @IsUrl({
    protocols: ['http', 'https'],
    require_protocol: true,
    require_tld: false,
  })
  url: string;
}
