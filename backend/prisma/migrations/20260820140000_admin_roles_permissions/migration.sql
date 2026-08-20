-- Admin Control Panel (Milestone 19), Phase 1: roluri de admin cu permisiuni
-- granulare, în plus față de users.isAdmin. Seed cu cele 4 roluri predefinite
-- + backfill: orice user cu isAdmin = true primește rolul SUPER_ADMIN, ca
-- nimeni să nu piardă acces la deploy.

-- CreateEnum
CREATE TYPE "AdminRoleName" AS ENUM ('SUPER_ADMIN', 'MODERATOR', 'CONTENT_MODERATOR', 'USER_SUPPORT', 'CUSTOM');

-- CreateTable
CREATE TABLE "admin_roles" (
    "id" TEXT NOT NULL DEFAULT gen_random_uuid()::text,
    "name" "AdminRoleName" NOT NULL,
    "label" TEXT NOT NULL,
    "permissions" TEXT[] NOT NULL DEFAULT ARRAY[]::TEXT[],
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "admin_roles_pkey" PRIMARY KEY ("id")
);

-- AlterTable
ALTER TABLE "users" ADD COLUMN "adminRoleId" TEXT;

-- AddForeignKey
ALTER TABLE "users" ADD CONSTRAINT "users_adminRoleId_fkey" FOREIGN KEY ("adminRoleId") REFERENCES "admin_roles"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- CreateIndex
CREATE INDEX "users_adminRoleId_idx" ON "users"("adminRoleId");

-- Seed the 4 built-in roles
INSERT INTO "admin_roles" ("id", "name", "label", "permissions", "updatedAt") VALUES
    (gen_random_uuid()::text, 'SUPER_ADMIN', 'Super Admin', ARRAY[
        'users.view','users.edit','users.suspend','users.ban','users.delete',
        'books.view','books.edit','books.hide','books.delete',
        'reports.view','reports.resolve','reports.dismiss',
        'exchanges.view','exchanges.manage',
        'admins.view','admins.create','admins.edit','admins.delete',
        'moderation.approve','moderation.review'
    ], CURRENT_TIMESTAMP),
    (gen_random_uuid()::text, 'MODERATOR', 'Moderator', ARRAY[
        'users.view','users.suspend','users.ban',
        'books.view','books.hide',
        'reports.view','reports.resolve','reports.dismiss',
        'exchanges.view',
        'moderation.review'
    ], CURRENT_TIMESTAMP),
    (gen_random_uuid()::text, 'CONTENT_MODERATOR', 'Content Moderator', ARRAY[
        'books.view','books.edit','books.hide',
        'reports.view','reports.resolve'
    ], CURRENT_TIMESTAMP),
    (gen_random_uuid()::text, 'USER_SUPPORT', 'User Support', ARRAY[
        'users.view','reports.view','exchanges.view'
    ], CURRENT_TIMESTAMP);

-- Backfill: existing admins (isAdmin = true) get SUPER_ADMIN, preserving
-- their current full access.
UPDATE "users"
SET "adminRoleId" = (SELECT "id" FROM "admin_roles" WHERE "name" = 'SUPER_ADMIN')
WHERE "isAdmin" = true;
