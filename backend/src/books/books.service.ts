import {
  BadRequestException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { StorageService } from '../storage/storage.service';
import { BookLookupService } from './book-lookup.service';
import { AddBookDto } from './dto/add-book.dto';
import { UpdateUserBookDto } from './dto/update-user-book.dto';

@Injectable()
export class BooksService {
  constructor(
    private prisma: PrismaService,
    private lookup: BookLookupService,
    private storage: StorageService,
  ) {}

  async searchExternal(query: string) {
    return this.lookup.searchByTitle(query);
  }

  async addToLibrary(userId: string, dto: AddBookDto) {
    const book = await this.findOrCreateBook(dto);

    return this.prisma.userBook.create({
      data: {
        userId,
        bookId: book.id,
        condition: dto.condition,
        language: dto.language,
        edition: dto.edition,
        isHardcover: dto.isHardcover ?? false,
      },
      include: { book: true },
    });
  }

  private async findOrCreateBook(dto: AddBookDto) {
    if (dto.isbn) {
      const cleanIsbn = dto.isbn.replace(/[-\s]/g, '');
      const existing = await this.prisma.book.findUnique({
        where: { isbn: cleanIsbn },
      });
      if (existing) return existing;

      const external = await this.lookup.lookupByIsbn(cleanIsbn);
      if (external) {
        return this.prisma.book.create({
          data: {
            isbn: cleanIsbn,
            title: external.title,
            author: external.author,
            description: external.description,
            coverUrl: external.coverUrl,
            publisher: external.publisher,
            publishedYear: external.publishedYear,
            pageCount: external.pageCount,
            language: external.language,
            source: external.source,
          },
        });
      }

      if (!dto.title) {
        throw new BadRequestException(
          'Nu am găsit cartea după ISBN. Completează manual titlul și autorul.',
        );
      }
      return this.prisma.book.create({
        data: {
          isbn: cleanIsbn,
          title: dto.title,
          author: dto.author,
          source: 'manual',
        },
      });
    }

    if (!dto.title) {
      throw new BadRequestException('Titlul este obligatoriu dacă nu dai ISBN');
    }
    return this.prisma.book.create({
      data: {
        title: dto.title,
        author: dto.author,
        source: 'manual',
      },
    });
  }

  async getMyLibrary(userId: string) {
    return this.prisma.userBook.findMany({
      where: { userId },
      include: { book: true },
      orderBy: { createdAt: 'desc' },
    });
  }

  async getUserBook(userBookId: string) {
    const userBook = await this.prisma.userBook.findUnique({
      where: { id: userBookId },
      include: { book: true },
    });
    if (!userBook) {
      throw new NotFoundException('Cartea nu a fost găsită în bibliotecă');
    }
    return userBook;
  }

  async updateUserBook(
    userId: string,
    userBookId: string,
    dto: UpdateUserBookDto,
  ) {
    const userBook = await this.getUserBook(userBookId);
    this.assertOwnership(userBook.userId, userId);

    return this.prisma.userBook.update({
      where: { id: userBookId },
      data: dto,
      include: { book: true },
    });
  }

  async deleteUserBook(userId: string, userBookId: string) {
    const userBook = await this.getUserBook(userBookId);
    this.assertOwnership(userBook.userId, userId);

    await Promise.all(userBook.photos.map((path) => this.storage.deleteImage(path)));

    await this.prisma.userBook.delete({ where: { id: userBookId } });
    return { message: 'Carte ștearsă din bibliotecă' };
  }

  async addPhoto(userId: string, userBookId: string, fileBuffer: Buffer) {
    const userBook = await this.getUserBook(userBookId);
    this.assertOwnership(userBook.userId, userId);

    const path = await this.storage.uploadImage(fileBuffer, 'user-books');

    const updated = await this.prisma.userBook.update({
      where: { id: userBookId },
      data: { photos: { push: path } },
      include: { book: true },
    });

    return { ...updated, photoUrl: this.storage.getPublicUrl(path) };
  }

  private assertOwnership(ownerId: string, requesterId: string) {
    if (ownerId !== requesterId) {
      throw new ForbiddenException('Nu poți modifica o carte care nu îți aparține');
    }
  }
}
