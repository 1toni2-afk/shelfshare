import { Module } from '@nestjs/common';
import { APP_GUARD } from '@nestjs/core';
import { ConfigModule } from '@nestjs/config';
import { ScheduleModule } from '@nestjs/schedule';
import { ThrottlerModule } from '@nestjs/throttler';
import { AppController } from './app.controller';
import { HttpThrottlerGuard } from './common/guards/http-throttler.guard';
import { AppService } from './app.service';
import { PrismaModule } from './prisma/prisma.module';
import { ActivityLogModule } from './activity-log/activity-log.module';
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
import { CollectionsModule } from './collections/collections.module';
import { GroupsModule } from './groups/groups.module';
import { AccountDeletionModule } from './account-deletion/account-deletion.module';
import { PreRegistrationModule } from './pre-registration/pre-registration.module';
import { RealtimeModule } from './common/realtime/realtime.module';
import { BookMatchModule } from './book-match/book-match.module';
import { AdminChatModule } from './admin-chat/admin-chat.module';
import { SavedSearchesModule } from './saved-searches/saved-searches.module';
import { BookOfMonthModule } from './book-of-month/book-of-month.module';
import { ReadingProgressModule } from './reading-progress/reading-progress.module';
import { ReviewsModule } from './reviews/reviews.module';
import { ReportsModule } from './reports/reports.module';

@Module({
  imports: [
    // Global: se raporteaza din patru module fara legatura intre ele.
    ReportsModule,
    ConfigModule.forRoot({ isGlobal: true }),
    ScheduleModule.forRoot(),
    // Default rate limit applied to every route unless overridden with
    // @Throttle(...) or opted out with @SkipThrottle() on a controller/route.
    ThrottlerModule.forRoot([{ name: 'default', ttl: 60_000, limit: 120 }]),
    RealtimeModule,
    PrismaModule,
    ActivityLogModule,
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
    CollectionsModule,
    GroupsModule,
    AccountDeletionModule,
    PreRegistrationModule,
    BookMatchModule,
    AdminChatModule,
    SavedSearchesModule,
    BookOfMonthModule,
    ReadingProgressModule,
    ReviewsModule,
  ],
  controllers: [AppController],
  providers: [AppService, { provide: APP_GUARD, useClass: HttpThrottlerGuard }],
})
export class AppModule {}
