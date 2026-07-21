import { Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { CreateUpcomingReleaseDto } from './dto/create-upcoming-release.dto';
import { UpdateUpcomingReleaseDto } from './dto/update-upcoming-release.dto';

@Injectable()
export class UpcomingReleasesService {
  constructor(private prisma: PrismaService) {}

  list() {
    return this.prisma.upcomingRelease.findMany({
      orderBy: { releaseDate: 'asc' },
      take: 20,
    });
  }

  create(dto: CreateUpcomingReleaseDto) {
    return this.prisma.upcomingRelease.create({
      data: { ...dto, releaseDate: new Date(dto.releaseDate) },
    });
  }

  async update(id: string, dto: UpdateUpcomingReleaseDto) {
    await this.assertExists(id);
    return this.prisma.upcomingRelease.update({
      where: { id },
      data: {
        ...dto,
        releaseDate: dto.releaseDate ? new Date(dto.releaseDate) : undefined,
      },
    });
  }

  async delete(id: string) {
    await this.assertExists(id);
    await this.prisma.upcomingRelease.delete({ where: { id } });
    return { message: 'Lansare ștearsă' };
  }

  private async assertExists(id: string) {
    const release = await this.prisma.upcomingRelease.findUnique({
      where: { id },
    });
    if (!release) {
      throw new NotFoundException('Lansarea nu a fost găsită');
    }
  }
}
