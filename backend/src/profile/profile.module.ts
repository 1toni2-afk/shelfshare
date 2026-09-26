import { Module } from '@nestjs/common';
import { ProfileController } from './profile.controller';
import { ProfileService } from './profile.service';
import { FeedSocialService } from './feed-social.service';
import { UsersModule } from '../users/users.module';
import { BookshelfModule } from '../bookshelf/bookshelf.module';
import { StorageModule } from '../storage/storage.module';
import { StoresModule } from '../stores/stores.module';

@Module({
  imports: [UsersModule, BookshelfModule, StorageModule, StoresModule],
  controllers: [ProfileController],
  providers: [ProfileService, FeedSocialService],
})
export class ProfileModule {}
