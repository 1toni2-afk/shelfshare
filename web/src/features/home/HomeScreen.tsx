import { useMemo } from 'react';
import { useQuery } from '@tanstack/react-query';
import { useTranslation } from 'react-i18next';
import { Bell, Flame, Heart, Navigation, Sparkles } from 'lucide-react';
import { booksKeys, booksRepository } from '@/features/books/booksRepository';
import { BookCard } from '@/features/books/BookCard';
import { BookGrid, useBookGridColumns } from '@/features/books/BookGrid';
import { BookRail } from '@/features/books/BookRail';
import { ErrorNotice, Spinner } from '@/components/ui';
import { useAuth } from '@/features/auth/AuthProvider';
import { HeaderAction, ScreenHeader } from '@/components/layout/ScreenHeader';
import { notificationsKeys, notificationsRepository } from '@/features/notifications/notificationsRepository';
import { TypewriterText } from '@/components/ui/TypewriterText';
import { buildGreetings } from './greetings';
import { OnboardingTodoCard } from './OnboardingTodoCard';
import { PendingSwapBanner } from './PendingSwapBanner';
import type { UserBook } from '@/types/models';

const PAGE_SIZE = 20;

/**
 * Câte RÂNDURI de grilă intră înaintea fiecărei secțiuni tematice.
 * `kHomeSectionSlots` din home_controller.dart. Feedul nu e „secțiuni sus,
 * grilă jos": secțiunile sunt INTERCALATE între rândurile de anunțuri recente,
 * ca să rupă monotonia grilei.
 */
const SECTION_SLOTS = [2, 3, 3];

/** `kNearbyRadiusKm` din home_controller.dart - apare in titlul sectiunii. */
const NEARBY_RADIUS_KM = 100;

export function HomeScreen() {
  const { t } = useTranslation();
  const { user } = useAuth();
  // Numărul de coloane e nevoie AICI, nu doar în grilă: din el se calculează
  // câte cărți intră într-un „rând", deci unde cad secțiunile tematice. Se
  // măsoară pe containerul feedului, care are exact lățimea grilelor.
  const [feedRef, columns] = useBookGridColumns();

  // Frazele se recalculeaza doar cand se schimba userul sau limba - nu la
  // fiecare randare, altfel efectul de mai jos ar reporni animatia continuu.
  const greetings = useMemo(
    () =>
      buildGreetings({
        t,
        now: new Date(),
        name: user?.name,
        birthdayMonth: user?.birthdayMonth,
        birthdayDay: user?.birthdayDay,
      }),
    [t, user?.name, user?.birthdayMonth, user?.birthdayDay],
  );

  const unreadNotifications = useQuery({
    queryKey: notificationsKeys.list(),
    queryFn: ({ signal }) => notificationsRepository.list(signal),
    select: (items) => items.filter((item) => !item.isRead).length,
    enabled: !!user,
  });

  const recent = useQuery({
    queryKey: booksKeys.browse({ sort: 'recent', limit: PAGE_SIZE }),
    queryFn: ({ signal }) =>
      booksRepository.browse({ sort: 'recent', limit: PAGE_SIZE }, signal),
  });

  const trending = useQuery({
    queryKey: booksKeys.browse({ sort: 'mostViewed', limit: PAGE_SIZE }),
    queryFn: ({ signal }) =>
      booksRepository.browse({ sort: 'mostViewed', limit: PAGE_SIZE }, signal),
  });

  const recommended = useQuery({
    queryKey: booksKeys.recommended(),
    queryFn: ({ signal }) => booksRepository.getRecommended(signal),
    // Recomandările au nevoie de un istoric; pentru un cont nou backendul
    // întoarce listă goală, iar secțiunea se ascunde singură.
    enabled: !!user,
  });

  const nearby = useQuery({
    queryKey: booksKeys.nearby(user?.city ?? ''),
    queryFn: ({ signal }) => booksRepository.getNearbyToday(user!.city!, signal),
    enabled: !!user?.city,
  });

  // Secțiunile GOALE se scot înainte de a împărți sloturile, ca „recomandate"
  // să urce pe locul doi când „aproape de tine" n-are nimic - altfel ar rămâne
  // un gol vizual în mijlocul feedului.
  const sections = [
    trending.data?.items?.length
      ? {
          key: 'trending',
          title: t('homeMostSearched'),
          items: trending.data.items,
          icon: <Flame size={22} />,
          tone: 'accent' as const,
          seeAllHref: '/browse',
        }
      : null,
    nearby.data?.length
      ? {
          key: 'nearby',
          title: t('homeNearbyTitle', { km: NEARBY_RADIUS_KM }),
          items: nearby.data,
          icon: <Navigation size={22} />,
          tone: 'primary' as const,
          seeAllHref: '/map',
        }
      : null,
    recommended.data?.length
      ? {
          key: 'recommended',
          title: t('homeRecommendedTitle'),
          items: recommended.data,
          icon: <Sparkles size={22} />,
          tone: 'accent' as const,
          seeAllHref: '/smart-matches',
        }
      : null,
  ].filter((section) => section !== null);

  // Bara rămâne aceeași cât se încarcă și dacă cererea a picat: în Flutter
  // `AppBar`-ul e al Scaffold-ului, nu al conținutului, deci salutul nu dispare
  // pentru că feedul n-a venit încă.
  const header = (
    <ScreenHeader
      title={<TypewriterText phrases={greetings} />}
      actionsInBrandBar
      actions={
        <>
          <HeaderAction
            to="/notifications"
            label={t('navNotifications')}
            badge={unreadNotifications.data}
          >
            <Bell size={22} />
          </HeaderAction>
          <HeaderAction to="/wishlist" label={t('wishlistTitle')}>
            <Heart size={22} />
          </HeaderAction>
        </>
      }
    />
  );

  if (recent.isPending) {
    return (
      <>
        {header}
        <div className="flex min-h-[60vh] items-center justify-center text-accent">
          <Spinner size={28} />
        </div>
      </>
    );
  }

  if (recent.isError) {
    return (
      <>
        {header}
        <div className="mx-auto max-w-2xl p-6">
          <ErrorNotice message={t('homeLoadError')} onRetry={() => void recent.refetch()} />
        </div>
      </>
    );
  }

  const books = recent.data.items;

  // Împărțirea propriu-zisă: fiecare secțiune primește câteva rânduri de grilă
  // înaintea ei, convertite în număr de cărți prin numărul de coloane.
  const blocks: Array<{ key: string; grid?: UserBook[]; section?: (typeof sections)[number] }> = [];
  let cursor = 0;
  sections.forEach((section, index) => {
    const rows = SECTION_SLOTS[index] ?? SECTION_SLOTS.at(-1)!;
    const take = Math.max(0, Math.min(rows * columns, books.length - cursor));
    if (take > 0) {
      blocks.push({ key: `grid-${index}`, grid: books.slice(cursor, cursor + take) });
      cursor += take;
    }
    blocks.push({ key: section.key, section });
  });
  if (cursor < books.length) {
    blocks.push({ key: 'grid-rest', grid: books.slice(cursor) });
  }

  return (
    <>
      {header}
      <div className="mx-auto w-full max-w-[1350px] px-4 pb-16 pt-2">
        {/* Lățimea se măsoară pe ACEST div, nu pe cel de deasupra: acolo
            `clientWidth` ar include padding-ul lateral, iar grila ar primi cu
            40-64px mai mult decât are de fapt. */}
        <div ref={feedRef}>
          <PendingSwapBanner />
          {/* Lista „Descoperă ShelfShare" apare și peste un feed gol (piață încă
              goală, sau filtre care n-au întors nimic): e exact momentul în care
              omul nou are cea mai mare nevoie să știe ce poate face. */}
          <OnboardingTodoCard />

          {books.length === 0 && sections.length === 0 ? (
            <p className="py-16 text-center text-muted-foreground">{t('homeEmpty')}</p>
          ) : (
            blocks.map((block, blockIndex) =>
              block.grid ? (
                <BookGrid key={block.key} columns={columns}>
                  {block.grid.map((item, index) => (
                    // `eager` doar pentru primul bloc: restul se încarcă la scroll.
                    <BookCard
                      key={item.id}
                      item={item}
                      eager={blockIndex === 0 && index < columns}
                    />
                  ))}
                </BookGrid>
              ) : (
                <BookRail
                  key={block.key}
                  title={block.section!.title}
                  items={block.section!.items}
                  icon={block.section!.icon}
                  tone={block.section!.tone}
                  seeAllHref={block.section!.seeAllHref}
                />
              ),
            )
          )}
        </div>
      </div>
    </>
  );
}
