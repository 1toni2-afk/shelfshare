import { Module } from '@nestjs/common';
import { SlidingWindowLimiterService } from './sliding-window-limiter.service';

@Module({
  providers: [SlidingWindowLimiterService],
  exports: [SlidingWindowLimiterService],
})
export class RateLimitModule {}
