import {
  BadRequestException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import type {
  CreateStoreDto,
  StoreProfileFieldsDto,
  UpdateStoreDto,
} from './dto/upsert-store.dto';

/**
 * Conturile de anticariat/librărie.
 *
 * Un magazin NU e un tip separat de cont: e un User obișnuit pe care un
 * super-admin l-a marcat ca magazin. Așa, tot ce există deja (autentificare,
 * anunțuri, chat, schimburi, ștergerea contului) funcționează nemodificat, iar
 * noi adăugăm doar identitatea comercială (StoreProfile) și dreptul de a-și
 * importa stocul.
 *
 * `User.isStore` și existența profilului se scriu mereu împreună, de aici -
 * nicăieri altundeva în cod nu se atinge vreunul din ele singur.
 */
@Injectable()
export class StoresService {
  constructor(private prisma: PrismaService) {}

  /** Toate conturile de magazin, active sau suspendate, pentru panoul de admin. */
  async list() {
    const profiles = await this.prisma.storeProfile.findMany({
      include: {
        user: {
          select: {
            id: true,
            name: true,
            username: true,
            email: true,
            isStore: true,
            profileImage: true,
          },
        },
      },
      orderBy: { displayName: 'asc' },
    });

    // Câte anunțuri are fiecare, ca panoul să arate dintr-o privire dacă
    // importul a intrat. Un singur groupBy, nu un count per magazin.
    const counts = await this.prisma.userBook.groupBy({
      by: ['userId'],
      where: {
        userId: { in: profiles.map((p) => p.userId) },
        deletedAt: null,
      },
      _count: { _all: true },
    });
    const countByUser = new Map(counts.map((c) => [c.userId, c._count._all]));

    return profiles.map((profile) => ({
      ...this.toPublic(profile),
      user: profile.user,
      isActive: profile.user.isStore,
      listingsCount: countByUser.get(profile.userId) ?? 0,
    }));
  }

  async create(dto: CreateStoreDto) {
    const user = await this.prisma.user.findUnique({
      where: { id: dto.userId },
    });
    if (!user) {
      throw new NotFoundException('Utilizator negăsit');
    }
    const existing = await this.prisma.storeProfile.findUnique({
      where: { userId: dto.userId },
    });
    if (existing) {
      throw new BadRequestException('Contul e deja marcat ca magazin');
    }

    const [, profile] = await this.prisma.$transaction([
      this.prisma.user.update({
        where: { id: dto.userId },
        // Numele comercial ajunge și pe cont: peste tot unde apare un
        // proprietar (carduri de anunț, chat, profil) se citește `User.name`,
        // iar un join către StoreProfile în fiecare din locurile alea ar fi
        // plătit de toți userii pentru câteva zeci de conturi. Aici e singurul
        // loc care le scrie, deci nu se pot dezsincroniza.
        data: { isStore: true, name: this.fields(dto).displayName },
      }),
      this.prisma.storeProfile.create({
        data: { userId: dto.userId, ...this.fields(dto) },
      }),
    ]);

    return this.toPublic(profile);
  }

  async update(userId: string, dto: UpdateStoreDto) {
    await this.getProfileOrThrow(userId);

    const [, profile] = await this.prisma.$transaction([
      this.prisma.user.update({
        where: { id: userId },
        data: {
          isStore: dto.isActive ?? true,
          name: this.fields(dto).displayName,
        },
      }),
      this.prisma.storeProfile.update({
        where: { userId },
        data: this.fields(dto),
      }),
    ]);

    return this.toPublic(profile);
  }

  /**
   * Retragerea statutului de magazin. Anunțurile importate rămân ale userului
   * (sunt cărți reale, pe care le poate gestiona mai departe manual) - ștergem
   * doar identitatea comercială.
   */
  async remove(userId: string) {
    await this.getProfileOrThrow(userId);
    await this.prisma.$transaction([
      this.prisma.user.update({
        where: { id: userId },
        data: { isStore: false },
      }),
      this.prisma.storeProfile.delete({ where: { userId } }),
    ]);
    return { removed: true };
  }

  /** Profilul public al unui magazin, sau `null` pentru un user obișnuit. */
  async getPublicProfile(userId: string) {
    const profile = await this.prisma.storeProfile.findUnique({
      where: { userId },
    });
    if (!profile) return null;
    return this.toPublic(profile);
  }

  /**
   * Verificarea făcută înainte de un import „în numele magazinului X".
   *
   * Contul trebuie să existe ȘI să fie activ ca magazin: un magazin suspendat
   * (`isStore = false`, profil păstrat) nu mai primește stoc nou, altfel
   * suspendarea n-ar însemna nimic.
   */
  async assertActiveStore(userId: string) {
    const user = await this.prisma.user.findUnique({
      where: { id: userId },
      select: { id: true, isStore: true },
    });
    if (!user) {
      throw new NotFoundException('Contul de magazin nu a fost găsit');
    }
    if (!user.isStore) {
      throw new ForbiddenException('Contul nu este un magazin activ');
    }
    return user.id;
  }

  private async getProfileOrThrow(userId: string) {
    const profile = await this.prisma.storeProfile.findUnique({
      where: { userId },
    });
    if (!profile) {
      throw new NotFoundException('Contul nu este marcat ca magazin');
    }
    return profile;
  }

  /**
   * Textele goale trimise de formular („") devin NULL, nu string gol: altfel
   * profilul ar afișa un rând de adresă vid în loc să-l sară.
   */
  private fields(dto: StoreProfileFieldsDto) {
    const clean = (value: string | undefined) => value?.trim() || null;
    return {
      displayName: dto.displayName.trim(),
      description: clean(dto.description),
      address: clean(dto.address),
      city: clean(dto.city),
      website: clean(dto.website),
      phone: clean(dto.phone),
      openingHours: clean(dto.openingHours),
      deliveryPolicy: clean(dto.deliveryPolicy),
    };
  }

  private toPublic(profile: {
    userId: string;
    displayName: string;
    description: string | null;
    address: string | null;
    city: string | null;
    website: string | null;
    phone: string | null;
    openingHours: string | null;
    deliveryPolicy: string | null;
  }) {
    return {
      userId: profile.userId,
      displayName: profile.displayName,
      description: profile.description,
      address: profile.address,
      city: profile.city,
      website: profile.website,
      phone: profile.phone,
      openingHours: profile.openingHours,
      deliveryPolicy: profile.deliveryPolicy,
    };
  }
}
