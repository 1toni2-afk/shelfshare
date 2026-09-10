import {
  ArrayMaxSize,
  ArrayNotEmpty,
  IsArray,
  IsString,
} from 'class-validator';

/// Scoaterea mai multor cărți din raft dintr-o singură apăsare.
export class BatchRemoveShelfDto {
  @IsArray()
  @ArrayNotEmpty()
  @ArrayMaxSize(200)
  @IsString({ each: true })
  bookIds!: string[];
}
