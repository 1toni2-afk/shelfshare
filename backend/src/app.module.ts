import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { AppController } from './app.controller';
import { AppService } from './app.service';
import { PrismaModule } from './prisma/prisma.module';
import { AuthModule } from './auth/auth.module';
import { ProfileModule } from './profile/profile.module';
import { StorageModule } from './storage/storage.module';
import { BooksModule } from './books/books.module';
import { ExchangesModule } from './exchanges/exchanges.module';
import { ChatModule } from './chat/chat.module';
import { NotificationsModule } from './notifications/notifications.module';
import { WishlistModule } from './wishlist/wishlist.module';
import { AdminModule } from './admin/admin.module';
import { UpcomingReleasesModule } from './upcoming-releases/upcoming-releases.module';
import { SafetyModule } from './safety/safety.module';
import { OffersModule } from './offers/offers.module';
import { PlacesModule } from './places/places.module';
import { FollowModule } from './follow/follow.module';
import { FeedbackModule } from './feedback/feedback.module';
import { SupportModule } from './support/support.module';
import { BookshelfModule } from './bookshelf/bookshelf.module';
import { AuctionsModule } from './auctions/auctions.module';

@Module({
  imports: [
    ConfigModule.forRoot({ isGlobal: true }),
    PrismaModule,
    AuthModule,
    ProfileModule,
    StorageModule,
    BooksModule,
    ExchangesModule,
    ChatModule,
    NotificationsModule,
    WishlistModule,
    AdminModule,
    UpcomingReleasesModule,
    SafetyModule,
    OffersModule,
    PlacesModule,
    FollowModule,
    FeedbackModule,
    SupportModule,
    BookshelfModule,
    AuctionsModule,
  ],
  controllers: [AppController],
  providers: [AppService],
})
export class AppModule {}
