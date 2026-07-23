import { ForbiddenException, Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { CreateCollectionDto } from './dto/create-collection.dto';
import { UpdateCollectionDto } from './dto/update-collection.dto';

const WITH_ITEMS = {
  items: { include: { book: true }, orderBy: { createdAt: 'desc' as const } },
  _count: { select: { items: true } },
};

@Injectable()
export class CollectionsService {
  constructor(private prisma: PrismaService) {}

  async createCollection(userId: string, dto: CreateCollectionDto) {
    return this.prisma.collection.create({
      data: { userId, name: dto.name, description: dto.description, isPublic: dto.isPublic ?? true },
      include: WITH_ITEMS,
    });
  }

  async getMyCollections(userId: string) {
    return this.prisma.collection.findMany({
      where: { userId },
      include: WITH_ITEMS,
      orderBy: { updatedAt: 'desc' },
    });
  }

  /** Colecțiile publice ale unui alt user - afișate pe profilul public. */
  async getPublicCollectionsForUser(userId: string) {
    return this.prisma.collection.findMany({
      where: { userId, isPublic: true },
      include: WITH_ITEMS,
      orderBy: { updatedAt: 'desc' },
    });
  }

  /** Nu dezvăluie existența unei colecții private altcuiva decât proprietarului - 404, nu 403. */
  async getCollection(id: string, requestingUserId?: string) {
    const collection = await this.prisma.collection.findUnique({ where: { id }, include: WITH_ITEMS });
    if (!collection || (!collection.isPublic && collection.userId !== requestingUserId)) {
      throw new NotFoundException('Colecția nu a fost găsită');
    }
    return collection;
  }

  async updateCollection(id: string, userId: string, dto: UpdateCollectionDto) {
    await this.assertOwner(id, userId);
    return this.prisma.collection.update({
      where: { id },
      data: { name: dto.name, description: dto.description, isPublic: dto.isPublic },
      include: WITH_ITEMS,
    });
  }

  async deleteCollection(id: string, userId: string) {
    await this.assertOwner(id, userId);
    await this.prisma.collection.delete({ where: { id } });
    return { message: 'Colecție ștearsă' };
  }

  async addBook(collectionId: string, userId: string, bookId: string) {
    await this.assertOwner(collectionId, userId);
    const book = await this.prisma.book.findUnique({ where: { id: bookId } });
    if (!book) {
      throw new NotFoundException('Cartea nu a fost găsită');
    }
    await this.prisma.collectionItem.upsert({
      where: { collectionId_bookId: { collectionId, bookId } },
      create: { collectionId, bookId },
      update: {},
    });
    return this.prisma.collection.update({
      where: { id: collectionId },
      data: { updatedAt: new Date() },
      include: WITH_ITEMS,
    });
  }

  async removeBook(collectionId: string, userId: string, bookId: string) {
    await this.assertOwner(collectionId, userId);
    await this.prisma.collectionItem
      .delete({ where: { collectionId_bookId: { collectionId, bookId } } })
      .catch(() => {});
    return this.prisma.collection.findUnique({ where: { id: collectionId }, include: WITH_ITEMS });
  }

  private async assertOwner(collectionId: string, userId: string) {
    const collection = await this.prisma.collection.findUnique({ where: { id: collectionId } });
    if (!collection) {
      throw new NotFoundException('Colecția nu a fost găsită');
    }
    if (collection.userId !== userId) {
      throw new ForbiddenException('Doar proprietarul poate modifica această colecție');
    }
  }
}
