import { Injectable, NotFoundException } from '@nestjs/common';
import { UsersService } from '../users/users.service';
import { UpdateProfileDto } from './dto/update-profile.dto';

@Injectable()
export class ProfileService {
  constructor(private users: UsersService) {}

  async getMyProfile(userId: string) {
    const user = await this.users.findById(userId);
    if (!user) {
      throw new NotFoundException('Utilizator negăsit');
    }

    return {
      id: user.id,
      email: user.email,
      name: user.name,
      city: user.city,
      bio: user.bio,
      profileImage: user.profileImage,
      rating: user.rating,
      booksExchangedCount: user.booksExchangedCount,
      isEmailVerified: user.isEmailVerified,
      createdAt: user.createdAt,
    };
  }

  async updateMyProfile(userId: string, dto: UpdateProfileDto) {
    const user = await this.users.update(userId, dto);

    return {
      id: user.id,
      email: user.email,
      name: user.name,
      city: user.city,
      bio: user.bio,
      profileImage: user.profileImage,
      rating: user.rating,
      booksExchangedCount: user.booksExchangedCount,
    };
  }

  async getPublicProfile(userId: string) {
    const user = await this.users.findById(userId);
    if (!user) {
      throw new NotFoundException('Utilizator negăsit');
    }

    return {
      id: user.id,
      name: user.name,
      city: user.city,
      bio: user.bio,
      profileImage: user.profileImage,
      rating: user.rating,
      booksExchangedCount: user.booksExchangedCount,
      memberSince: user.createdAt,
    };
  }
}
