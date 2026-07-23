-- Auctions (Milestone 3: Marketplace/Listing Types): a 4th listing type
-- alongside Swap/Fixed Price/Negotiable Price, with reserve price, buy now,
-- anti-sniping, anonymous bid history, and watch/outbid notifications.
CREATE TYPE "AuctionStatus" AS ENUM ('ACTIVE', 'ENDED', 'CANCELLED');

ALTER TYPE "NotificationType" ADD VALUE 'OUTBID';
ALTER TYPE "NotificationType" ADD VALUE 'AUCTION_WON';
ALTER TYPE "NotificationType" ADD VALUE 'AUCTION_ENDED';

ALTER TABLE "user_books" ADD COLUMN "isAuction" BOOLEAN NOT NULL DEFAULT false;

CREATE TABLE "auctions" (
    "id" TEXT NOT NULL,
    "userBookId" TEXT NOT NULL,
    "startingPrice" DECIMAL(10,2) NOT NULL,
    "reservePrice" DECIMAL(10,2),
    "buyNowPrice" DECIMAL(10,2),
    "currentPrice" DECIMAL(10,2) NOT NULL,
    "highestBidderId" TEXT,
    "endsAt" TIMESTAMP(3) NOT NULL,
    "status" "AuctionStatus" NOT NULL DEFAULT 'ACTIVE',
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "auctions_pkey" PRIMARY KEY ("id")
);

CREATE UNIQUE INDEX "auctions_userBookId_key" ON "auctions"("userBookId");

ALTER TABLE "auctions" ADD CONSTRAINT "auctions_userBookId_fkey" FOREIGN KEY ("userBookId") REFERENCES "user_books"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "auctions" ADD CONSTRAINT "auctions_highestBidderId_fkey" FOREIGN KEY ("highestBidderId") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;

CREATE TABLE "bids" (
    "id" TEXT NOT NULL,
    "auctionId" TEXT NOT NULL,
    "bidderId" TEXT NOT NULL,
    "amount" DECIMAL(10,2) NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "bids_pkey" PRIMARY KEY ("id")
);

ALTER TABLE "bids" ADD CONSTRAINT "bids_auctionId_fkey" FOREIGN KEY ("auctionId") REFERENCES "auctions"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "bids" ADD CONSTRAINT "bids_bidderId_fkey" FOREIGN KEY ("bidderId") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

CREATE TABLE "auction_watches" (
    "id" TEXT NOT NULL,
    "auctionId" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "auction_watches_pkey" PRIMARY KEY ("id")
);

CREATE UNIQUE INDEX "auction_watches_auctionId_userId_key" ON "auction_watches"("auctionId", "userId");

ALTER TABLE "auction_watches" ADD CONSTRAINT "auction_watches_auctionId_fkey" FOREIGN KEY ("auctionId") REFERENCES "auctions"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "auction_watches" ADD CONSTRAINT "auction_watches_userId_fkey" FOREIGN KEY ("userId") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;
