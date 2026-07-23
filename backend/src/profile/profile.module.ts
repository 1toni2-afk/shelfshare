import { Module } from '@nestjs/common';
import { ProfileController } from './profile.controller';
import { ProfileService } from './profile.service';
import { UsersModule } from '../users/users.module';
import { BookshelfModule } from '../bookshelf/bookshelf.module';

@Module({
  imports: [UsersModule, BookshelfModule],
  controllers: [ProfileController],
  providers: [ProfileService],
})
export class ProfileModule {}
