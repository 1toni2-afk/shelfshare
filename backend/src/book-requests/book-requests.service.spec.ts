import { Test, TestingModule } from '@nestjs/testing';
import { BadRequestException, NotFoundException } from '@nestjs/common';
import { BookRequestStatus, NotificationType } from '@prisma/client';
import { BookRequestsService } from './book-requests.service';
import { PrismaService } from '../prisma/prisma.service';
import { NotificationsService } from '../notifications/notifications.service';
import { BooksService } from '../books/books.service';
import { BookLookupService } from '../books/book-lookup.service';
import type { ExternalBookResult } from '../books/types/external-book-result';

const externalResult = (
  overrides: Partial<ExternalBookResult> = {},
): ExternalBookResult => ({
  isbn: null,
  title: 'Stăpânul Inelelor',
  author: 'J.R.R. Tolkien',
  description: null,
  coverUrl: null,
  publisher: null,
  publishedYear: null,
  pageCount: null,
  language: null,
  genre: null,
  subjects: [],
  source: 'google_books',
  ...overrides,
});

describe('BookRequestsService', () => {
  let service: BookRequestsService;
  let prisma: {
    bookRequest: Record<string, jest.Mock>;
    book: Record<string, jest.Mock>;
    $queryRaw: jest.Mock;
  };
  let books: { searchCatalog: jest.Mock };
  let lookup: { searchByTitle: jest.Mock; lookupByIsbn: jest.Mock };
  let notifications: { create: jest.Mock };

  beforeEach(async () => {
    prisma = {
      bookRequest: {
        findUnique: jest.fn().mockResolvedValue(null),
        findFirst: jest.fn().mockResolvedValue(null),
        findMany: jest.fn().mockResolvedValue([]),
        count: jest.fn().mockResolvedValue(0),
        create: jest.fn().mockImplementation(({ data }) => ({
          id: 'req-1',
          attempts: 0,
          book: null,
          ...data,
        })),
        update: jest.fn().mockImplementation(({ data }) => ({
          id: 'req-1',
          book: null,
          ...data,
        })),
        updateMany: jest.fn().mockResolvedValue({ count: 1 }),
      },
      book: {
        findUnique: jest.fn().mockResolvedValue(null),
        findFirst: jest.fn().mockResolvedValue(null),
        create: jest
          .fn()
          .mockImplementation(({ data }) => ({ id: 'book-1', ...data })),
      },
      $queryRaw: jest.fn().mockResolvedValue([]),
    };
    // Implicit: nici catalogul, nici providerii externi nu găsesc nimic -
    // fix situația în care userul ajunge la formular.
    books = { searchCatalog: jest.fn().mockResolvedValue([]) };
    lookup = {
      searchByTitle: jest.fn().mockResolvedValue([]),
      lookupByIsbn: jest.fn().mockResolvedValue(null),
    };
    notifications = { create: jest.fn().mockResolvedValue(null) };

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        BookRequestsService,
        { provide: PrismaService, useValue: prisma },
        { provide: NotificationsService, useValue: notifications },
        { provide: BooksService, useValue: books },
        { provide: BookLookupService, useValue: lookup },
      ],
    }).compile();

    service = module.get(BookRequestsService);
  });

  describe('normalizeKey', () => {
    it('face aceeasi cheie indiferent de diacritice si spatii', () => {
      expect(BookRequestsService.normalizeKey('Stăpânul  Inelelor', 'Tolkien')).toBe(
        BookRequestsService.normalizeKey('stapanul inelelor', 'TOLKIEN'),
      );
    });

    it('separa titlul de autor, ca doua carti cu acelasi titlu sa nu se ciocneasca', () => {
      expect(BookRequestsService.normalizeKey('Idiotul', 'Dostoievski')).not.toBe(
        BookRequestsService.normalizeKey('Idiotul', 'Altcineva'),
      );
    });
  });

  describe('create', () => {
    it('creeaza cererea cand nu gaseste cartea nicaieri', async () => {
      const result = await service.create('user-1', { title: 'Carte lipsă' });

      expect(result.status).toBe('pending');
      expect(prisma.bookRequest.create).toHaveBeenCalledWith(
        expect.objectContaining({
          data: expect.objectContaining({
            userId: 'user-1',
            title: 'Carte lipsă',
            normalizedKey: 'carte lipsa',
          }),
        }),
      );
    });

    it('nu creeaza nimic daca titlul structurat se gaseste in catalog', async () => {
      books.searchCatalog.mockResolvedValue([
        externalResult({ source: 'catalog', bookId: 'book-9' }),
      ]);
      prisma.book.findUnique.mockResolvedValue({ id: 'book-9' });

      const result = await service.create('user-1', {
        title: 'Stăpânul Inelelor',
        author: 'J.R.R. Tolkien',
      });

      expect(result.status).toBe('found');
      expect(result.book).toEqual({ id: 'book-9' });
      expect(prisma.bookRequest.create).not.toHaveBeenCalled();
    });

    it('reactiveaza cererea existenta in loc sa creeze un duplicat', async () => {
      prisma.bookRequest.findUnique.mockResolvedValue({
        id: 'req-7',
        status: BookRequestStatus.CANCELLED,
        attempts: 5,
        note: null,
        isbn: null,
      });

      const result = await service.create('user-1', { title: 'Carte lipsă' });

      expect(result.status).toBe('pending');
      expect(prisma.bookRequest.create).not.toHaveBeenCalled();
      expect(prisma.bookRequest.update).toHaveBeenCalledWith(
        expect.objectContaining({
          where: { id: 'req-7' },
          data: expect.objectContaining({
            status: BookRequestStatus.PENDING,
            attempts: 0,
          }),
        }),
      );
    });

    it('respinge cand userul are deja prea multe cereri in asteptare', async () => {
      prisma.bookRequest.count.mockResolvedValue(20);

      await expect(
        service.create('user-1', { title: 'Carte lipsă' }),
      ).rejects.toThrow(BadRequestException);
    });
  });

  describe('resolvePendingRequests', () => {
    const pending = {
      id: 'req-1',
      userId: 'user-1',
      title: 'Stăpânul Inelelor',
      author: 'J.R.R. Tolkien',
      isbn: null,
      attempts: 0,
      normalizedKey: 'stapanul inelelor|j r r tolkien',
      status: BookRequestStatus.PENDING,
    };

    beforeEach(() => {
      prisma.$queryRaw.mockResolvedValue([{ ...pending, demand: 3 }]);
    });

    it('adauga cartea in catalog si anunta toti solicitantii', async () => {
      lookup.searchByTitle.mockResolvedValue([externalResult()]);
      prisma.bookRequest.findMany.mockResolvedValue([
        { id: 'req-1', userId: 'user-1', title: 'Stăpânul Inelelor' },
        { id: 'req-2', userId: 'user-2', title: 'Stapanul inelelor' },
      ]);

      await service.resolvePendingRequests();

      expect(prisma.book.create).toHaveBeenCalled();
      expect(prisma.bookRequest.updateMany).toHaveBeenCalledWith(
        expect.objectContaining({
          data: expect.objectContaining({
            status: BookRequestStatus.FULFILLED,
            bookId: 'book-1',
            resolvedSource: 'google_books',
          }),
        }),
      );
      expect(notifications.create).toHaveBeenCalledTimes(2);
      expect(notifications.create).toHaveBeenCalledWith(
        'user-2',
        NotificationType.BOOK_REQUEST_FOUND,
        expect.stringContaining('Stapanul inelelor'),
        expect.objectContaining({ bookId: 'book-1' }),
      );
    });

    it('refuza un rezultat extern cu alt titlu decat cel cerut', async () => {
      lookup.searchByTitle.mockResolvedValue([
        externalResult({ title: 'Hobbitul' }),
      ]);

      await service.resolvePendingRequests();

      expect(prisma.book.create).not.toHaveBeenCalled();
      expect(notifications.create).not.toHaveBeenCalled();
      expect(prisma.bookRequest.update).toHaveBeenCalledWith(
        expect.objectContaining({
          data: expect.objectContaining({ attempts: 1 }),
        }),
      );
    });

    it('refuza un rezultat cu titlul cerut dar cu alt autor', async () => {
      lookup.searchByTitle.mockResolvedValue([
        externalResult({ author: 'Cineva Altcineva' }),
      ]);

      await service.resolvePendingRequests();

      expect(prisma.book.create).not.toHaveBeenCalled();
    });

    it('trece cererea in NOT_FOUND dupa 3 incercari', async () => {
      prisma.$queryRaw.mockResolvedValue([
        { ...pending, attempts: 2, demand: 1 },
      ]);

      await service.resolvePendingRequests();

      expect(prisma.bookRequest.update).toHaveBeenCalledWith(
        expect.objectContaining({
          data: expect.objectContaining({
            attempts: 3,
            status: BookRequestStatus.NOT_FOUND,
          }),
        }),
      );
    });

    it('ramane PENDING inaintea plafonului', async () => {
      prisma.$queryRaw.mockResolvedValue([
        { ...pending, attempts: 1, demand: 1 },
      ]);

      await service.resolvePendingRequests();

      expect(prisma.bookRequest.update).toHaveBeenCalledWith(
        expect.objectContaining({
          data: expect.objectContaining({
            attempts: 2,
            status: BookRequestStatus.PENDING,
          }),
        }),
      );
    });

    it('refoloseste cartea existenta pe ISBN in loc sa creeze un duplicat', async () => {
      lookup.searchByTitle.mockResolvedValue([
        externalResult({ isbn: '978-973-46-1079-2' }),
      ]);
      prisma.book.findUnique.mockResolvedValue({ id: 'book-existent' });
      prisma.bookRequest.findMany.mockResolvedValue([
        { id: 'req-1', userId: 'user-1', title: 'Stăpânul Inelelor' },
      ]);

      await service.resolvePendingRequests();

      expect(prisma.book.findUnique).toHaveBeenCalledWith({
        where: { isbn: '9789734610792' },
      });
      expect(prisma.book.create).not.toHaveBeenCalled();
      expect(prisma.bookRequest.updateMany).toHaveBeenCalledWith(
        expect.objectContaining({
          data: expect.objectContaining({ bookId: 'book-existent' }),
        }),
      );
    });
  });

  describe('resolveFromWorker', () => {
    it('marcheaza cartea gasita de un magazin drept curata', async () => {
      prisma.bookRequest.findUnique.mockResolvedValue({
        id: 'req-1',
        normalizedKey: 'carte lipsa',
      });
      prisma.bookRequest.findMany.mockResolvedValue([
        { id: 'req-1', userId: 'user-1', title: 'Carte lipsă' },
      ]);

      const result = await service.resolveFromWorker({
        requestId: 'req-1',
        source: 'libris',
        curated: true,
        book: { title: 'Carte lipsă', author: 'Autor' },
      });

      expect(result).toEqual({
        status: 'fulfilled',
        bookId: 'book-1',
        notified: 1,
      });
      expect(prisma.book.create).toHaveBeenCalledWith(
        expect.objectContaining({
          data: expect.objectContaining({ curatedAt: expect.any(Date) }),
        }),
      );
    });

    it('doar numara incercarea cand magazinul nu a gasit nimic', async () => {
      prisma.bookRequest.findUnique.mockResolvedValue({
        id: 'req-1',
        normalizedKey: 'carte lipsa',
        attempts: 2,
      });

      const result = await service.resolveFromWorker({
        requestId: 'req-1',
        source: 'libris',
      });

      expect(result).toEqual({ status: 'not_found' });
      expect(prisma.book.create).not.toHaveBeenCalled();
      expect(prisma.bookRequest.update).toHaveBeenCalledWith(
        expect.objectContaining({
          data: expect.objectContaining({ attempts: 3 }),
        }),
      );
    });

    it('respinge un requestId inexistent', async () => {
      prisma.bookRequest.findUnique.mockResolvedValue(null);

      await expect(
        service.resolveFromWorker({ requestId: 'nope', source: 'libris' }),
      ).rejects.toThrow(NotFoundException);
    });
  });

  describe('cancel', () => {
    it('nu lasa un user sa anuleze cererea altuia', async () => {
      prisma.bookRequest.findUnique.mockResolvedValue({
        id: 'req-1',
        userId: 'altcineva',
      });

      await expect(service.cancel('user-1', 'req-1')).rejects.toThrow(
        NotFoundException,
      );
    });
  });
});
