import { BadRequestException, Injectable, NotFoundException } from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { NotificationsService } from '../notifications/notifications.service';
import { CreateSavedSearchDto } from './dto/create-saved-search.dto';

// Suficient pentru orice user real - o plasă de siguranță împotriva unei
// liste care ar crește nemărginit (fiecare căutare salvată e verificată la
// fiecare anunț nou, vezi notifyOnNewListing/notifyOnPriceSet mai jos).
const MAX_SAVED_SEARCHES_PER_USER = 20;

@Injectable()
export class SavedSearchesService {
  constructor(
    private prisma: PrismaService,
    private notifications: NotificationsService,
  ) {}

  async create(userId: string, dto: CreateSavedSearchDto) {
    const count = await this.prisma.savedSearch.count({ where: { userId } });
    if (count >= MAX_SAVED_SEARCHES_PER_USER) {
      throw new BadRequestException(
        `Poți avea cel mult ${MAX_SAVED_SEARCHES_PER_USER} căutări salvate`,
      );
    }

    return this.prisma.savedSearch.create({
      data: {
        userId,
        label: dto.label,
        genre: dto.genre,
        city: dto.city,
        maxPrice: dto.maxPrice,
      },
    });
  }

  getMine(userId: string) {
    return this.prisma.savedSearch.findMany({
      where: { userId },
      orderBy: { createdAt: 'desc' },
    });
  }

  async remove(userId: string, id: string) {
    const search = await this.prisma.savedSearch.findUnique({ where: { id } });
    if (!search || search.userId !== userId) {
      throw new NotFoundException('Căutarea salvată nu a fost găsită');
    }
    await this.prisma.savedSearch.delete({ where: { id } });
    return { message: 'Căutare salvată ștearsă' };
  }

  private genreCityFilter(genre: string | null, city: string | null): Prisma.SavedSearchWhereInput[] {
    return [
      genre ? { OR: [{ genre: null }, { genre }] } : { genre: null },
      city ? { OR: [{ city: null }, { city }] } : { city: null },
    ];
  }

  /**
   * Se apelează la crearea unui anunț nou (vezi addToLibrary în
   * books.service.ts), când prețul de vânzare încă nu e cunoscut - de asta
   * se potrivesc doar căutările fără maxPrice. Cele cu maxPrice își prind
   * potrivirea mai târziu, la notifyOnPriceSet, când anunțul chiar trece pe
   * vânzare.
   */
  async notifyOnNewListing(
    ownerId: string,
    bookId: string,
    bookTitle: string,
    genre: string | null,
    city: string | null,
  ) {
    const matches = await this.prisma.savedSearch.findMany({
      where: {
        userId: { not: ownerId },
        maxPrice: null,
        AND: this.genreCityFilter(genre, city),
      },
    });
    await this.notifyMatches(matches, bookId, bookTitle);
  }

  /** Se apelează când un anunț trece pe vânzare cu un preț - vezi updateUserBook. */
  async notifyOnPriceSet(
    ownerId: string,
    bookId: string,
    bookTitle: string,
    genre: string | null,
    city: string | null,
    salePrice: number,
  ) {
    const matches = await this.prisma.savedSearch.findMany({
      where: {
        userId: { not: ownerId },
        maxPrice: { gte: salePrice },
        AND: this.genreCityFilter(genre, city),
      },
    });
    await this.notifyMatches(matches, bookId, bookTitle);
  }

  private async notifyMatches(
    matches: { userId: string; label: string }[],
    bookId: string,
    bookTitle: string,
  ) {
    await Promise.all(
      matches.map((search) =>
        this.notifications
          .create(
            search.userId,
            'SAVED_SEARCH_MATCH',
            `Un anunț nou se potrivește cu căutarea ta salvată „${search.label}": „${bookTitle}"`,
            { bookId },
          )
          .catch(() => {}),
      ),
    );
  }
}
