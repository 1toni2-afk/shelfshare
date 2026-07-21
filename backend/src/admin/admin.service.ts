import { Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { FeedbackService } from '../feedback/feedback.service';

@Injectable()
export class AdminService {
  constructor(
    private prisma: PrismaService,
    private feedback: FeedbackService,
  ) {}

  async getStats() {
    const [
      totalUsers,
      verifiedUsers,
      totalBooks,
      totalUserBooks,
      totalExchanges,
      completedExchanges,
      pendingExchanges,
    ] = await Promise.all([
      this.prisma.user.count(),
      this.prisma.user.count({ where: { isEmailVerified: true } }),
      this.prisma.book.count(),
      this.prisma.userBook.count(),
      this.prisma.exchangeRequest.count(),
      this.prisma.exchangeRequest.count({ where: { status: 'COMPLETED' } }),
      this.prisma.exchangeRequest.count({ where: { status: 'PENDING' } }),
    ]);

    return {
      users: { total: totalUsers, verified: verifiedUsers },
      books: { totalInCatalog: totalBooks, totalListings: totalUserBooks },
      exchanges: {
        total: totalExchanges,
        completed: completedExchanges,
        pending: pendingExchanges,
      },
    };
  }

  // Numărul total de utilizatori vine deja din getStats() - nu-l mai
  // numărăm o a doua oară aici doar ca să-l afișăm într-un titlu.
  async getUsers(limit = 50, offset = 0) {
    const items = await this.prisma.user.findMany({
      select: {
        id: true,
        email: true,
        name: true,
        city: true,
        isEmailVerified: true,
        isBanned: true,
        isAdmin: true,
        rating: true,
        booksExchangedCount: true,
        createdAt: true,
      },
      orderBy: { createdAt: 'desc' },
      take: limit,
      skip: offset,
    });

    return { items, limit, offset };
  }

  async banUser(userId: string) {
    const user = await this.prisma.user.findUnique({ where: { id: userId } });
    if (!user) {
      throw new NotFoundException('Utilizator negăsit');
    }

    return this.prisma.user.update({
      where: { id: userId },
      data: { isBanned: true, refreshTokenHash: null },
      select: { id: true, email: true, isBanned: true },
    });
  }

  async unbanUser(userId: string) {
    const user = await this.prisma.user.findUnique({ where: { id: userId } });
    if (!user) {
      throw new NotFoundException('Utilizator negăsit');
    }

    return this.prisma.user.update({
      where: { id: userId },
      data: { isBanned: false },
      select: { id: true, email: true, isBanned: true },
    });
  }

  async deleteUser(userId: string) {
    const user = await this.prisma.user.findUnique({ where: { id: userId } });
    if (!user) {
      throw new NotFoundException('Utilizator negăsit');
    }

    await this.prisma.user.delete({ where: { id: userId } });
    return { message: 'Utilizator șters' };
  }

  async deleteBook(bookId: string) {
    const book = await this.prisma.book.findUnique({ where: { id: bookId } });
    if (!book) {
      throw new NotFoundException('Cartea nu a fost găsită');
    }

    await this.prisma.book.delete({ where: { id: bookId } });
    return { message: 'Carte ștearsă din catalog' };
  }

  async deleteUserBook(userBookId: string) {
    const userBook = await this.prisma.userBook.findUnique({
      where: { id: userBookId },
    });
    if (!userBook) {
      throw new NotFoundException('Anunțul nu a fost găsit');
    }

    await this.prisma.userBook.delete({ where: { id: userBookId } });
    return { message: 'Anunț șters' };
  }

  getInactiveListingsReport() {
    return this.prisma.userBook.findMany({
      where: {
        exchangeRequestsReceived: { none: {} },
      },
      include: {
        book: { select: { title: true, author: true } },
        user: { select: { email: true, name: true } },
      },
      orderBy: { createdAt: 'asc' },
      take: 100,
    });
  }

  getUserReports() {
    return this.prisma.report.findMany({
      include: {
        reporter: { select: { id: true, email: true, name: true } },
        reportedUser: { select: { id: true, email: true, name: true } },
        userBook: { include: { book: { select: { title: true } } } },
      },
      orderBy: { createdAt: 'desc' },
      take: 100,
    });
  }

  getFeedback() {
    return this.feedback.getAll();
  }
}
