import { ArrayMaxSize, IsArray, IsString } from 'class-validator';

/// Cap la 100 - un card grid tipic (browse/discover) nu are nevoie de mai
/// multe id-uri deodată, iar un array nelimitat ar fi un vector de abuz.
export class GetListingScoresDto {
  @IsArray()
  @ArrayMaxSize(100)
  @IsString({ each: true })
  userBookIds: string[];
}
