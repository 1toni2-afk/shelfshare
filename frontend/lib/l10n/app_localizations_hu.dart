// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Hungarian (`hu`).
class AppLocalizationsHu extends AppLocalizations {
  AppLocalizationsHu([String locale = 'hu']) : super(locale);

  @override
  String get navHome => 'Kezdőlap';

  @override
  String get navSearch => 'Keresés';

  @override
  String get navLibrary => 'Könyvtár';

  @override
  String get navChat => 'Chat';

  @override
  String get navProfile => 'Profil';

  @override
  String get commonCancel => 'Mégse';

  @override
  String get commonSubmit => 'Küldés';

  @override
  String get commonSave => 'Mentés';

  @override
  String get commonSeeAll => 'Összes megtekintése';

  @override
  String get commonUnknownUser => 'Felhasználó';

  @override
  String get commonAbout => 'Bemutatkozás';

  @override
  String get commonRating => 'Értékelés';

  @override
  String get commonBooksExchanged => 'Elcserélt könyvek';

  @override
  String get commonRetry => 'Próbáld újra';

  @override
  String get commonDone => 'Kész';

  @override
  String get commonClose => 'Bezárás';

  @override
  String get commonDelete => 'Törlés';

  @override
  String get commonConfirm => 'Megerősítés';

  @override
  String get continueWithGoogle => 'Folytatás Google-lal';

  @override
  String get reportDialogTitle => 'Bejelentés';

  @override
  String get trustScoreTitle => 'Megbízhatósági pontszám';

  @override
  String get trustScoreSubtitle =>
      'Az alkalmazásban végzett tevékenység alapján számolva - nem személyazonosság-ellenőrzés';

  @override
  String get trustScoreEmailVerified => 'Email megerősítve';

  @override
  String trustScoreCompletedRate(int percent) {
    return '$percent% teljesített csere';
  }

  @override
  String trustScoreRespondsIn(String time) {
    return 'Válaszidő ~$time';
  }

  @override
  String get trustScoreLastActiveToday => 'Ma aktív volt';

  @override
  String trustScoreLastActiveDays(int days) {
    return '$days napja aktív';
  }

  @override
  String trustScoreResponseRate(int percent) {
    return '$percent% válaszarány';
  }

  @override
  String trustScoreAverageSwapTime(String time) {
    return 'Egy csere ~$time alatt zárul le';
  }

  @override
  String memberSinceDays(int days) {
    return 'Tag $days napja';
  }

  @override
  String memberSinceMonths(int months) {
    return 'Tag $months hónapja';
  }

  @override
  String memberSinceYears(int years) {
    return 'Tag $years éve';
  }

  @override
  String durationMinutes(int minutes) {
    return '$minutes perc';
  }

  @override
  String durationHours(int hours) {
    return '$hoursó';
  }

  @override
  String durationDays(int days) {
    return '$days nap';
  }

  @override
  String priceLei(String amount) {
    return '$amount lej';
  }

  @override
  String get commonEmailLabel => 'Email';

  @override
  String get commonEmailInvalid => 'Érvénytelen email';

  @override
  String get commonOr => 'vagy';

  @override
  String get commonRequired => 'Kötelező';

  @override
  String get commonContinue => 'Folytatás';

  @override
  String get loginWelcomeBack => 'Üdvözlünk újra';

  @override
  String get authPasswordLabel => 'Jelszó';

  @override
  String get authEnterPasswordError => 'Add meg a jelszót';

  @override
  String get authMinEightChars => 'Legalább 8 karakter';

  @override
  String get authForgotPasswordLink => 'Elfelejtetted a jelszavad?';

  @override
  String get authLoginSubmit => 'Bejelentkezés';

  @override
  String get authNoAccount => 'Nincs még fiókod? ';

  @override
  String get authCreateOne => 'Hozz létre egyet';

  @override
  String get authGoogleFailed =>
      'A Google-bejelentkezés sikertelen. Próbáld újra.';

  @override
  String get supportContactButton =>
      'Nem tudsz bejelentkezni? Lépj kapcsolatba velünk';

  @override
  String get supportDialogTitle => 'Kapcsolatfelvétel a support csapattal';

  @override
  String get supportDialogSubtitle =>
      'Mondd el, mi a probléma, és emailben válaszolunk.';

  @override
  String get supportNameLabel => 'Név';

  @override
  String get supportPhoneLabel => 'Telefon (opcionális)';

  @override
  String get supportMessageLabel => 'Üzeneted';

  @override
  String get supportCaptchaAnswerLabel => 'A válaszod';

  @override
  String get supportSubmit => 'Üzenet küldése';

  @override
  String get supportSuccessMessage =>
      'Üzenet elküldve! Hamarosan válaszolunk emailben.';

  @override
  String get supportGenericError =>
      'Nem sikerült elküldeni az üzenetet. Próbáld újra.';

  @override
  String get authRegisterTitle => 'Fiók létrehozása';

  @override
  String get authRegisterSubtitle => 'Csatlakozz a ShelfShare közösséghez';

  @override
  String get authReferralCodeLabel => 'Meghívó kód (opcionális)';

  @override
  String get verifyCodeTooShort => 'A kódnak 6 számjegyűnek kell lennie';

  @override
  String get verifySuccessSnackbar => 'Fiók sikeresen megerősítve!';

  @override
  String get verifyInvalidOrExpired => 'Érvénytelen vagy lejárt kód.';

  @override
  String get verifyResendSnackbar => 'Elküldtük újra a kódot, ha szükséges.';

  @override
  String get verifyEmailHeading => 'Erősítsd meg az email címed';

  @override
  String verifySentTo(String email) {
    return 'Elküldtünk egy megerősítő kódot ide: $email';
  }

  @override
  String get verifyConfirmButton => 'Megerősítés';

  @override
  String get verifyResending => 'Újraküldés...';

  @override
  String get verifyResendPrompt => 'Nem kaptad meg a kódot? Küldd újra';

  @override
  String get forgotPasswordTitle => 'Jelszó visszaállítása';

  @override
  String get forgotPasswordSubtitle =>
      'Küldünk egy visszaállító kódot emailben.';

  @override
  String get forgotPasswordSubmit => 'Kód küldése';

  @override
  String get forgotPasswordCodeHeading => 'Add meg az emailben kapott kódot';

  @override
  String forgotPasswordCodeSentTo(String email) {
    return 'Küldtünk egy visszaállító kódot erre a címre: $email';
  }

  @override
  String get resetPasswordTitle => 'Új jelszó beállítása';

  @override
  String get resetPasswordSubtitle => 'Válassz új jelszót a fiókodhoz';

  @override
  String get resetPasswordNewLabel => 'Új jelszó';

  @override
  String get resetPasswordSubmit => 'Jelszó beállítása';

  @override
  String get resetPasswordSuccessHeading => 'Jelszó megváltoztatva';

  @override
  String get resetPasswordSuccessBody =>
      'A jelszavad frissítve lett. Most már bejelentkezhetsz.';

  @override
  String get resetPasswordGoToLogin => 'Bejelentkezés';

  @override
  String get resetPasswordGenericError =>
      'Nem sikerült visszaállítani a jelszót. Próbáld újra.';

  @override
  String get authConfirmPasswordLabel => 'Jelszó megerősítése';

  @override
  String get authPasswordMismatch => 'A jelszavak nem egyeznek';

  @override
  String get onboardingTitle => 'Már majdnem kész!';

  @override
  String get onboardingSubtitle => 'Mondd el, hogyan lássanak téged mások';

  @override
  String get onboardingFirstName => 'Keresztnév';

  @override
  String get onboardingLastName => 'Vezetéknév';

  @override
  String get onboardingUsername => 'Felhasználónév';

  @override
  String get onboardingUsernameFormatError =>
      '3-20 karakter: betűk, számok vagy aláhúzás';

  @override
  String get onboardingGenericError => 'Hiba történt. Próbáld újra.';

  @override
  String get onboardingNameVisibleSwitch =>
      'Legyen a nevem nyilvánosan látható';

  @override
  String get onboardingUsernameAlwaysVisible =>
      'A felhasználóneved mindig látható marad';

  @override
  String get profileTitle => 'Profilom';

  @override
  String get profileCopyLink => 'Link másolása';

  @override
  String get profileLoadError => 'Nem sikerült betölteni a profilt.';

  @override
  String get profileAboutMe => 'Bemutatkozás';

  @override
  String get profileBadgesTitle => 'Jelvények';

  @override
  String get profileMyExchanges => 'Cseréim';

  @override
  String get profileSafetyCenter => 'Biztonsági központ';

  @override
  String get profileHelpCenter => 'Gyakori kérdések';

  @override
  String get profileLeaderboard => 'Ranglista';

  @override
  String get profileSendFeedback => 'Visszajelzés küldése';

  @override
  String get profileEditProfile => 'Profil szerkesztése';

  @override
  String get profileAdminPanel => 'Admin felület';

  @override
  String get profileLogout => 'Kijelentkezés';

  @override
  String get profileLanguage => 'Nyelv';

  @override
  String get profileDarkModeSection => 'Sötét mód';

  @override
  String get profileThemeSystem => 'Automatikus (rendszer)';

  @override
  String get profileThemeLight => 'Világos';

  @override
  String get profileThemeDark => 'Sötét';

  @override
  String get profileQrTooltip => 'QR-kód';

  @override
  String get profileQrDialogTitle => 'A QR-kódod';

  @override
  String get profileQrDialogBody =>
      'Aki beolvassa ezt a kódot, megnyithatja a profilodat.';

  @override
  String get profileReferralTitle => 'A meghívó kódod';

  @override
  String get profileReferralSubtitle =>
      'Oszd meg a barátaiddal, hogy megtaláljanak a ShelfShare-en';

  @override
  String profileReferralCountLabel(int count) {
    return '$count meghívott barát';
  }

  @override
  String get profileReferralCopied => 'Kód a vágólapra másolva';

  @override
  String get profileFeedbackHint => 'Mit szeretnél elmondani nekünk?';

  @override
  String get profileFeedbackThanks => 'Köszönjük a visszajelzést!';

  @override
  String get profileFeedbackError => 'Nem sikerült elküldeni a visszajelzést';

  @override
  String get profileUsernameLabel => 'Felhasználónév';

  @override
  String get profileCityLabel => 'Város';

  @override
  String get profileNoCity => 'Nincs város';

  @override
  String get profileShowAcquisitionHistory =>
      'Beszerzési előzmények megjelenítése a profilon';

  @override
  String get profileShowAcquisitionHistorySubtitle =>
      'Könyvek, amelyeket cserével vagy vásárlással szereztél az alkalmazásban';

  @override
  String get profileSaveError => 'Nem sikerült menteni a profilt.';

  @override
  String get commonSendMessage => 'Üzenet küldése';

  @override
  String get publicProfileTitle => 'Profil';

  @override
  String get publicProfileFollowUpdateError =>
      'Nem sikerült frissíteni a követést';

  @override
  String get publicProfileMessageError =>
      'Nem sikerült elindítani a beszélgetést.';

  @override
  String publicProfileMemberSince(int year) {
    return 'Tag $year óta';
  }

  @override
  String publicProfileFollowersFollowing(int followers, int following) {
    return '$followers követő · $following követett';
  }

  @override
  String get publicProfileUnfollow => 'Ne kövesd tovább';

  @override
  String get publicProfileFollow => 'Kövesd';

  @override
  String get publicProfileReadingStats => 'Olvasási statisztikák';

  @override
  String get publicProfileBooksListed => 'Listázott könyvek';

  @override
  String get publicProfileTotalPages => 'Összes oldal';

  @override
  String get publicProfileFavoriteGenre => 'Kedvenc műfaj';

  @override
  String get publicProfileBooksShared => 'Megosztott könyvek';

  @override
  String get publicProfileBooksReceived => 'Kapott könyvek';

  @override
  String get publicProfileLongestBook => 'Leghosszabb könyv';

  @override
  String publicProfileListedBooksCount(int count) {
    return 'Listázott könyvek ($count)';
  }

  @override
  String get publicProfileAcquisitionHistory =>
      'Az alkalmazásban szerzett könyvek előzményei';

  @override
  String get publicProfileNoAcquisitions =>
      'Még nincs befejezett csere vagy vásárlás.';

  @override
  String publicProfileReviewsCount(int count) {
    return 'Értékelések ($count)';
  }

  @override
  String get leaderboardEmpty => 'Még nincs aktív város.';

  @override
  String get leaderboardUnknownCity => 'Ismeretlen';

  @override
  String leaderboardExchangesCount(int count) {
    return '$count csere';
  }

  @override
  String get leaderboardLoadError => 'Nem sikerült betölteni a ranglistát.';

  @override
  String get leaderboardTabCity => 'Városok szerint';

  @override
  String get leaderboardTabNational => 'Országos';

  @override
  String get leaderboardTabTopReaders => 'Olvasók';

  @override
  String leaderboardPagesCount(int count) {
    return '$count oldal';
  }

  @override
  String get profileGlobalStats => 'Globális statisztikák';

  @override
  String get profileMyBookshelf => 'A polcom';

  @override
  String get bookshelfTitle => 'A polcom';

  @override
  String get bookshelfTabReading => 'Olvasom';

  @override
  String get bookshelfTabWantToRead => 'Szeretném olvasni';

  @override
  String get bookshelfTabFinished => 'Elolvasva';

  @override
  String get bookshelfTabShared => 'Megosztva';

  @override
  String get bookshelfEmpty => 'Még nincs itt egyetlen könyv sem.';

  @override
  String get bookshelfLoadError => 'Nem sikerült betölteni a polcot.';

  @override
  String get bookshelfImportTooltip =>
      'Importálás Goodreads-ből vagy StoryGraph-ból';

  @override
  String get bookshelfImportGoodreads => 'Importálás Goodreads-ből (CSV)';

  @override
  String get bookshelfImportStoryGraph => 'Importálás StoryGraph-ból (CSV)';

  @override
  String bookshelfImportSummary(int imported, int skipped) {
    return '$imported könyv importálva, $skipped kihagyva';
  }

  @override
  String get bookshelfImportError =>
      'Nem sikerült importálni a fájlt. Ellenőrizd, hogy érvényes CSV export-e.';

  @override
  String get bookDetailShelfSectionTitle => 'Add hozzá a polcodhoz';

  @override
  String gamificationLevel(int level) {
    return '$level. szint';
  }

  @override
  String gamificationXp(int xp) {
    return '$xp XP';
  }

  @override
  String gamificationXpToNextLevel(int xp) {
    return '$xp XP a következő szintig';
  }

  @override
  String gamificationStreak(int days) {
    return '$days napos sorozat';
  }

  @override
  String gamificationLongestStreak(int days) {
    return 'Rekord: $days nap';
  }

  @override
  String get profileMonthlyChallenges => 'Havi kihívások';

  @override
  String get monthlyChallengesTitle => 'Havi kihívások';

  @override
  String get profileReadingChallenge => 'Olvasási kihívás';

  @override
  String readingChallengeTitle(int year) {
    return '$year-es olvasási kihívás';
  }

  @override
  String get readingChallengeNoGoal =>
      'Még nem állítottál be célt erre az évre.';

  @override
  String readingChallengeProgress(int progress, int goal) {
    return '$progress/$goal könyv elolvasva';
  }

  @override
  String get readingChallengeSetGoal => 'Cél beállítása';

  @override
  String get readingChallengeGoalLabel =>
      'Hány könyvet szeretnél elolvasni idén?';

  @override
  String get profileActivityFeed => 'Legutóbbi tevékenység';

  @override
  String get activityFeedTitle => 'Legutóbbi tevékenység';

  @override
  String get activityFeedEmpty =>
      'Még nincs esemény - kövess másokat, hogy lásd, mit olvasnak.';

  @override
  String get activityFeedLoadError => 'Nem sikerült betölteni a tevékenységet.';

  @override
  String activityNewListing(String name) {
    return '$name új könyvet listázott';
  }

  @override
  String activityFinishedBook(String name) {
    return '$name befejezte az olvasást';
  }

  @override
  String activityCompletedExchange(String name) {
    return '$name lezárt egy cserét';
  }

  @override
  String get bookDetailShelfRemove => 'Eltávolítás a polcról';

  @override
  String get publicProfileBookshelfTitle => 'Könyvespolc';

  @override
  String get globalStatsTitle => 'Globális statisztikák';

  @override
  String get globalStatsTabMostShared => 'Legtöbbet megosztott';

  @override
  String get globalStatsTabTrending => 'Felkapott';

  @override
  String get globalStatsTabPopularAuthors => 'Népszerű szerzők';

  @override
  String get globalStatsEmpty => 'Még nincs adat.';

  @override
  String get globalStatsLoadError => 'Nem sikerült betölteni a statisztikákat.';

  @override
  String globalStatsTransferCount(int count) {
    return '$count csere/eladás';
  }

  @override
  String globalStatsViewCount(int count) {
    return '$count megtekintés (14 nap)';
  }

  @override
  String get profileFavoriteSellers => 'Kedvenc eladók';

  @override
  String get favoriteSellersTitle => 'Kedvenc eladók';

  @override
  String get favoriteSellersEmpty => 'Még nem követsz senkit.';

  @override
  String get favoriteSellersLoadError => 'Nem sikerült betölteni a listát.';

  @override
  String get publicProfileTopGenres => 'Kedvenc műfajok';

  @override
  String get impactStatsTitle => 'Hatás';

  @override
  String get impactStatsTotalValue => 'Elcserélt összérték';

  @override
  String get impactStatsMoneySaved => 'Megtakarított pénz';

  @override
  String get impactStatsCo2Saved => 'Megtakarított CO₂ (becsült)';

  @override
  String impactStatsCo2Value(String kg) {
    return '$kg kg';
  }

  @override
  String homeGreeting(String name) {
    return 'Szia, $name!';
  }

  @override
  String get homeWelcome => 'Üdvözlünk!';

  @override
  String get homeLoadError => 'Nem sikerült betölteni a könyveket.';

  @override
  String get homeEmpty => 'Még nincsenek elérhető könyvek.';

  @override
  String get homeCategories => 'Kategóriák';

  @override
  String get homeRecentlyAdded => 'Nemrég hozzáadva';

  @override
  String get homeMostViewed => 'Legtöbbet megtekintett';

  @override
  String get homeNearYou => 'A városodban';

  @override
  String get homeNearYouToday => 'Ma, a közeledben';

  @override
  String get homeRecommendedForYou => 'Neked ajánljuk';

  @override
  String get homeHiddenGems => 'Rejtett kincsek';

  @override
  String get homeCompleteYourCollection => 'Egészítsd ki a gyűjteményed';

  @override
  String get homeSimilarTaste => 'Hasonló ízlés';

  @override
  String get profileSmartMatches => 'Csereajánlatok';

  @override
  String get smartMatchesTitle => 'Csereajánlatok';

  @override
  String get smartMatchesEmpty =>
      'Még nincs egyezés - adj hozzá könyveket a kívánságlistádhoz és listázz elérhető könyveket.';

  @override
  String get smartMatchesLoadError => 'Nem sikerült betölteni az egyezéseket.';

  @override
  String get smartMatchesTheyHave => 'Megvan neki, amit szeretnél';

  @override
  String get smartMatchesTheyWant => 'Szeretné, ami megvan neked';

  @override
  String get homeUpcomingBooks => 'Hamarosan megjelenő könyvek';

  @override
  String get homeActiveMembers => 'Aktív tagok';

  @override
  String get browseTitle => 'Könyvek keresése';

  @override
  String get browseMapTooltip => 'Közeli könyvek térképe';

  @override
  String get browseSearchHint => 'Keresés cím szerint';

  @override
  String get browseEmpty => 'Nem található könyv.';

  @override
  String get filtersTitle => 'Szűrők';

  @override
  String get filtersAuthor => 'Szerző';

  @override
  String get filtersGenre => 'Műfaj';

  @override
  String get filtersLanguage => 'Nyelv';

  @override
  String get filtersAnyCity => 'Bármelyik város';

  @override
  String get filtersCondition => 'Állapot';

  @override
  String get filtersAnyCondition => 'Bármilyen állapot';

  @override
  String get filtersListingType => 'Hirdetés típusa';

  @override
  String get filtersListingTypeSwap => 'Csere';

  @override
  String get filtersListingTypeSale => 'Eladás';

  @override
  String get filtersListingTypeAuction => 'Árverés';

  @override
  String get filtersNearbyOnly => 'Csak a közelben';

  @override
  String get filtersNearbyOnlyHintOff =>
      'Rendezés és szűrés a városodtól mért valós távolság szerint';

  @override
  String filtersNearbyOnlyHintOn(int km) {
    return 'Legfeljebb $km km a városodtól';
  }

  @override
  String filtersDistanceKm(int km) {
    return '$km km';
  }

  @override
  String get filtersReset => 'Visszaállítás';

  @override
  String get filtersApply => 'Szűrők alkalmazása';

  @override
  String get commonYes => 'Igen';

  @override
  String get commonNo => 'Nem';

  @override
  String get commonGiveUp => 'Mégse';

  @override
  String get libraryTitle => 'Könyvtáram';

  @override
  String get libraryViewAsList => 'Listanézet';

  @override
  String get libraryViewAsGrid => 'Rácsnézet';

  @override
  String get libraryExportCsv => 'Exportálás CSV-be';

  @override
  String get libraryBulkAdd => 'Több könyv hozzáadása (szkennelés)';

  @override
  String get libraryImportCsv => 'Hirdetések importálása CSV-ből';

  @override
  String libraryImportSummary(int created, int failed) {
    return '$created hirdetés létrehozva, $failed sikertelen';
  }

  @override
  String get libraryImportError =>
      'Nem sikerült importálni a fájlt. Ellenőrizd, hogy érvényes CSV-e.';

  @override
  String get libraryEmpty => 'Még nincs könyved a könyvtáradban.';

  @override
  String get libraryLoadError => 'Nem sikerült betölteni a könyvtárat.';

  @override
  String get libraryAvailable => 'Elérhető';

  @override
  String get libraryUnavailable => 'Nem elérhető';

  @override
  String get libraryDeleteConfirmTitle => 'Törlöd a könyvet?';

  @override
  String libraryDeleteConfirmBody(String title) {
    return '„$title” eltávolításra kerül a könyvtáradból.';
  }

  @override
  String get libraryAvailableForSwap => 'Elérhető cserére';

  @override
  String get libraryDeleteBook => 'Könyv törlése';

  @override
  String get libraryEditListing => 'Hirdetés szerkesztése';

  @override
  String get libraryEditListingTitle => 'Hirdetés szerkesztése';

  @override
  String get libraryEditListingSuccess => 'A hirdetés frissítve.';

  @override
  String get csvHeaderTitle => 'Cím';

  @override
  String get csvHeaderAvailableForSwap => 'Elérhető cserére';

  @override
  String get csvHeaderForSale => 'Eladó';

  @override
  String get csvHeaderPrice => 'Ár';

  @override
  String get addBookTitle => 'Könyv hozzáadása';

  @override
  String get addBookSearchHint => 'Cím vagy ISBN';

  @override
  String get addBookSearchButton => 'Keresés';

  @override
  String get addBookSearchFailed => 'A keresés sikertelen. Próbáld újra.';

  @override
  String get addBookSearchPrompt => 'Keress egy könyvet cím vagy ISBN alapján.';

  @override
  String get addBookManualEntry => 'Kézi hozzáadás';

  @override
  String get addBookNotFoundManual => 'Nem találod a könyvet? Add hozzá kézzel';

  @override
  String get addBookChange => 'Módosítás';

  @override
  String get addBookTitleLabel => 'Cím';

  @override
  String get addBookSearchInstead => 'Keresés inkább';

  @override
  String get addBookLanguageOptional => 'Nyelv (opcionális)';

  @override
  String get addBookEditionOptional => 'Kiadás (opcionális)';

  @override
  String get addBookHardcoverSwitch => 'Keménytáblás kiadás';

  @override
  String get addBookForSaleSwitch => 'Eladó';

  @override
  String get addBookForSaleHint =>
      'A cserén kívül fix áron is eladhatod a könyvet';

  @override
  String get addBookPriceLabel => 'Ár (lej)';

  @override
  String get addBookNonNegotiable => 'Fix ár, nem alkudható';

  @override
  String get addBookNonNegotiableHint => 'A vevők nem tehetnek ajánlatot';

  @override
  String get addBookAuctionSwitch => 'Árverés indítása';

  @override
  String get addBookAuctionHint =>
      'A vevők licitálnak, a legmagasabb ajánlat nyer a végén';

  @override
  String get addBookAuctionStartingPrice => 'Kikiáltási ár';

  @override
  String get addBookAuctionReservePrice => 'Minimálár (opcionális)';

  @override
  String get addBookAuctionReservePriceHint =>
      'A legalacsonyabb ár, ami alatt nem adod el';

  @override
  String get addBookAuctionBuyNowPrice =>
      '\"Azonnal megveszem\" ár (opcionális)';

  @override
  String get addBookAuctionBuyNowPriceHint =>
      'Csak az első licit előtt elérhető';

  @override
  String get addBookAuctionDuration => 'Árverés időtartama';

  @override
  String get addBookAuctionDuration24h => '24 óra';

  @override
  String get addBookAuctionDuration3d => '3 nap';

  @override
  String get addBookAuctionDuration7d => '7 nap';

  @override
  String get addBookPhotosLabelRequired =>
      'Fotók a könyvről (kötelező, legalább 1)';

  @override
  String get addBookPhotosLabelOptional => 'Fotók a könyvről (opcionális)';

  @override
  String get addBookSubmit => 'Hozzáadás a könyvtárhoz';

  @override
  String get addBookTitleRequired => 'A cím megadása kötelező';

  @override
  String get addBookInvalidPrice => 'Adj meg egy érvényes árat';

  @override
  String get addBookNeedPhoto =>
      'Adj hozzá legalább egy fotót a könyvről, mielőtt eladásra kínálod';

  @override
  String get addBookSuccess => 'A könyv hozzáadva a könyvtáradhoz';

  @override
  String get addBookGenericError =>
      'Nem sikerült hozzáadni a könyvet. Próbáld újra.';

  @override
  String get relistNeedPhoto =>
      'Adj hozzá legalább egy fotót, mielőtt eladásra kínálod';

  @override
  String get relistSuccess => 'A könyv hozzáadva a könyvtáradhoz';

  @override
  String get relistGenericError => 'Nem sikerült hozzáadni a könyvet.';

  @override
  String relistHeading(String title) {
    return '„$title” hozzáadása a könyvtáradhoz';
  }

  @override
  String get relistSubtitle =>
      'Írd le, milyen állapotban kaptad - ez a könyv előzményeihez kapcsolódik.';

  @override
  String get mapTitle => 'Közeli könyvek';

  @override
  String get mapLoadError => 'Nem sikerült betölteni a térképet.';

  @override
  String get mapEmpty => 'Egyik városban sincs még elérhető könyv.';

  @override
  String mapCityBooksCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count könyv',
      one: '$count könyv',
    );
    return '$_temp0';
  }

  @override
  String get bookDetailTitle => 'Könyv részletei';

  @override
  String get bookDetailReportTooltip => 'Hirdetés bejelentése';

  @override
  String bookDetailReportedFrom(String title) {
    return 'Bejelentve a(z) \"$title\" hirdetésről';
  }

  @override
  String get bookDetailReportSent => 'Bejelentés elküldve. Köszönjük!';

  @override
  String get bookDetailReportError => 'Nem sikerült elküldeni a bejelentést';

  @override
  String get bookDetailLoadError => 'Nem sikerült betölteni a könyvet.';

  @override
  String get bookDetailViewsTitle => 'Megtekintések';

  @override
  String get bookDetailViewsLoadError =>
      'Nem sikerült betölteni a megtekintési statisztikákat.';

  @override
  String bookDetailUniqueViews(int count) {
    return '$count egyedi megtekintés';
  }

  @override
  String bookDetailTotalViews(int count) {
    return '$count megtekintés összesen, az oldalfrissítésekkel együtt';
  }

  @override
  String get bookDetailHardcoverChip => 'Keménytáblás';

  @override
  String get bookDetailAvailableChip => 'Elérhető cserére';

  @override
  String bookDetailViewCount(int count) {
    return '$count megtekintés';
  }

  @override
  String get bookDetailDescriptionTitle => 'Leírás';

  @override
  String get bookDetailDetailsTitle => 'Részletek';

  @override
  String get bookDetailPublisherLabel => 'Kiadó';

  @override
  String get bookDetailYearLabel => 'Megjelenés éve';

  @override
  String get bookDetailPagesLabel => 'Oldalak';

  @override
  String get bookDetailOwnerTitle => 'Tulajdonos';

  @override
  String get bookDetailPhotosTitle => 'Fotók';

  @override
  String get bookDetailRequestExchange => 'Csere kérése';

  @override
  String get bookDetailUnavailableForExchange => 'Nem elérhető cserére';

  @override
  String get bookDetailMakeOffer => 'Ajánlat tétele';

  @override
  String get bookDetailHistoryTitle => 'A könyv előzményei';

  @override
  String get bookDetailHistorySubtitle =>
      'Hogyan járta be a könyv az alkalmazást, az egyes tulajdonosok fotóival.';

  @override
  String get bookDetailHistorySold => 'eladva';

  @override
  String get bookDetailHistoryExchanged => 'elcserélve';

  @override
  String bookDetailHistoryListedOn(String date) {
    return 'listázva ekkor: $date';
  }

  @override
  String bookDetailHistoryTransferredOn(String action, String date) {
    return ' · $action ekkor: $date';
  }

  @override
  String get bookDetailHistoryCurrentlyOwned => ' · jelenleg birtokolva';

  @override
  String get bookDetailSimilarBooksTitle => 'Hasonló könyvek';

  @override
  String bookDetailLibraryPriceLabel(String price) {
    return 'Könyvesbolt ár: $price';
  }

  @override
  String bookDetailRequestedTitle(String title) {
    return '„$title” kérése cserébe';
  }

  @override
  String get bookDetailNoBooksToOffer =>
      'Nincs felajánlható könyved - a kérést enélkül is elküldheted.';

  @override
  String get bookDetailOfferOneOfYourBooks =>
      'Ajánld fel az egyik könyvedet (opcionális)';

  @override
  String get bookDetailNoOffer => 'Nincs ajánlat';

  @override
  String get bookDetailMessageOptional => 'Üzenet (opcionális)';

  @override
  String get bookDetailSendRequest => 'Kérés küldése';

  @override
  String get bookDetailRequestSent => 'Cserekérés elküldve';

  @override
  String get bookDetailRequestError => 'Nem sikerült elküldeni a kérést.';

  @override
  String get bookDetailFirstExchangeTitle => 'Az első cseréd';

  @override
  String get bookDetailFirstExchangeBody =>
      'Néhány tanács az első csere előtt: találkozzatok nappal, nyilvános helyen, és ellenőrizd a könyv állapotát, mielőtt a cserét befejezettként megerősítenéd.';

  @override
  String get bookDetailUnderstood => 'Értem, folytatás';

  @override
  String bookDetailMakeOfferTitle(String title) {
    return 'Ajánlat tétele erre: „$title”';
  }

  @override
  String bookDetailAskingPrice(String price) {
    return 'Kért ár: $price';
  }

  @override
  String get bookDetailOfferAmountLabel => 'Ajánlott összeg';

  @override
  String get bookDetailSendOffer => 'Ajánlat küldése';

  @override
  String get bookDetailOfferSent => 'Ajánlat elküldve';

  @override
  String get bookDetailOfferError => 'Nem sikerült elküldeni az ajánlatot.';

  @override
  String get bookDetailInvalidAmount => 'Adj meg egy érvényes összeget';

  @override
  String get commonAddToLibrary => 'Add hozzá a könyvtáradhoz';

  @override
  String get commonAnonymousUser => 'egy felhasználó';

  @override
  String get exchangesTitle => 'Cseréim';

  @override
  String get exchangesTabReceived => 'Kapott cserék';

  @override
  String get exchangesTabSent => 'Küldött cserék';

  @override
  String get offersTabReceived => 'Kapott ajánlatok';

  @override
  String get offersTabSent => 'Küldött ajánlatok';

  @override
  String get exchangesEmptyReceived => 'Még nem kaptál cserekérést.';

  @override
  String get exchangesEmptySent => 'Még nem küldtél cserekérést.';

  @override
  String get exchangesLoadError => 'Nem sikerült betölteni a cseréket.';

  @override
  String exchangeRequestedBy(String name) {
    return 'Kérte: $name';
  }

  @override
  String exchangeFrom(String name) {
    return 'Tőle: $name';
  }

  @override
  String exchangeOffersBook(String title) {
    return 'Felajánlja: $title';
  }

  @override
  String exchangeOffersAmount(String amount) {
    return 'Felajánlja: $amount RON';
  }

  @override
  String get exchangeReject => 'Elutasítás';

  @override
  String get exchangeAccept => 'Elfogadás';

  @override
  String get exchangeCancelRequest => 'Kérés visszavonása';

  @override
  String get exchangeScheduleMeeting => 'Találkozó ütemezése';

  @override
  String get exchangeReschedule => 'Átütemezés';

  @override
  String get exchangeAddToCalendar => 'Hozzáadás a naptárhoz';

  @override
  String get exchangeQrCode => 'QR kód';

  @override
  String get exchangeMarkComplete => 'Megjelölés befejezettként';

  @override
  String get exchangeRated => 'Értékelve';

  @override
  String get exchangeRate => 'Értékelés';

  @override
  String get exchangeCalendarError => 'Nem sikerült megnyitni a naptárt.';

  @override
  String get exchangeRatingDialogTitle => 'Milyen volt a csere?';

  @override
  String get exchangeRatingOverall => 'Összesített';

  @override
  String get exchangeRatingCommunication => 'Kommunikáció';

  @override
  String get exchangeRatingPunctuality => 'Pontosság';

  @override
  String get exchangeRatingCondition => 'A kapott könyv állapota';

  @override
  String get exchangeReviewOptional => 'Értékelés (opcionális)';

  @override
  String get exchangeQrDialogTitle => 'Megerősítő QR kód';

  @override
  String get exchangeQrDialogBody =>
      'A másik résztvevő beolvassa ezt a kódot a találkozón, hogy megerősítse a cserét.';

  @override
  String get exchangeMeetingSheetTitle => 'Találkozó ütemezése';

  @override
  String get exchangePickDateTime => 'Válassz dátumot és időt';

  @override
  String get exchangeLocationLabel => 'Helyszín';

  @override
  String get exchangeMeetingSaveError => 'Nem sikerült menteni a találkozót.';

  @override
  String get offersEmptyReceived => 'Még nem kaptál árajánlatot.';

  @override
  String get offersEmptySent => 'Még nem küldtél árajánlatot.';

  @override
  String get offersLoadError => 'Nem sikerült betölteni az ajánlatokat.';

  @override
  String offerTo(String name) {
    return 'Neki: $name';
  }

  @override
  String offerAmountLine(String amount) {
    return 'Ajánlat: $amount';
  }

  @override
  String get offerCancel => 'Ajánlat visszavonása';

  @override
  String get exchangeConfirmTitle => 'Csere megerősítése';

  @override
  String get exchangeConfirmError => 'Nem sikerült megerősíteni a cserét.';

  @override
  String get exchangeConfirmDone => 'A csere befejezettként megjelölve!';

  @override
  String get exchangeConfirmQuestion =>
      'Megerősíted, hogy a könyvcsere befejeződött?';

  @override
  String get exchangeConfirmButton => 'Befejezés megerősítése';

  @override
  String get chatEmptyConversations => 'Még nincs egyetlen beszélgetésed sem.';

  @override
  String get chatStartConversation => 'Kezdj beszélgetést';

  @override
  String get chatPhotoPreview => '📷 Fotó';

  @override
  String get chatLocationPreview => '📍 Helyszín';

  @override
  String get chatLoadError => 'Nem sikerült betölteni a beszélgetéseket.';

  @override
  String get chatConversationFallbackTitle => 'Beszélgetés';

  @override
  String get chatUnblock => 'Feloldás';

  @override
  String get chatBlock => 'Letiltás';

  @override
  String get chatUserUnblocked => 'Felhasználó feloldva';

  @override
  String get chatUserBlocked => 'Felhasználó letiltva';

  @override
  String get chatBlockUpdateError => 'Nem sikerült frissíteni a letiltást';

  @override
  String get chatTyping => 'gépel...';

  @override
  String get chatBlockedNotice =>
      'Nem küldhetsz üzenetet ennek a felhasználónak - a beszélgetés le van tiltva.';

  @override
  String get chatShareLocationTooltip => 'Találkozó helyszínének küldése';

  @override
  String get chatMessageHint => 'Írj egy üzenetet...';

  @override
  String get chatSafetyBannerBody =>
      'Ne küldj pénzt előre, és nyilvános helyen találkozzatok a cseréhez. Ha valami gyanúsnak tűnik, jelentsd be vagy tiltsd le a felhasználót a fenti menüből.';

  @override
  String get chatSafetyBannerLearnMore => 'Tudj meg többet';

  @override
  String get chatEmptyMessages => 'Még nincs üzenet. Köszönj!';

  @override
  String get chatMapLabel => 'Térkép';

  @override
  String get chatCalendarLabel => 'Naptár';

  @override
  String chatMeetingAt(String date, String time) {
    return '$date, $time-kor';
  }

  @override
  String get chatSafetyAdvisorLabel => 'Biztonsági tanácsadó';

  @override
  String get chatSafetyAdvisorBody =>
      'Ügyelj a biztonsági irányelvek betartására a találkozón.';

  @override
  String get chatOfferActionError =>
      'Nem sikerült frissíteni az ajánlatot. Próbáld újra.';

  @override
  String chatOfferCardLabel(String amount, String bookTitle) {
    return '$amount lej · $bookTitle';
  }

  @override
  String get chatSearchPlaceHint =>
      'Keress egy címet vagy helyet (pl. X kávézó, Kolozsvár)';

  @override
  String get chatNoResults => 'Nincs találat.';

  @override
  String get chatSuggestedMeetingPoints =>
      'Ajánlott találkozási pontok a közelben';

  @override
  String get chatPickDate => 'Válassz dátumot';

  @override
  String get chatPickTime => 'Válassz időpontot';

  @override
  String get wishlistTitle => 'Kívánságlista';

  @override
  String get wishlistEmpty =>
      'Még nem adtál hozzá könyvet a kívánságlistádhoz.';

  @override
  String get wishlistLoadError => 'Nem sikerült betölteni a kívánságlistát.';

  @override
  String get notificationsTitle => 'Értesítések';

  @override
  String get notificationsMarkAllRead => 'Összes megjelölése olvasottként';

  @override
  String get notificationsEmpty => 'Nincs egyetlen értesítésed sem.';

  @override
  String get notificationsLoadError =>
      'Nem sikerült betölteni az értesítéseket.';

  @override
  String get timeJustNow => 'most';

  @override
  String timeMinutesAgo(int minutes) {
    return '$minutes perce';
  }

  @override
  String timeHoursAgo(int hours) {
    return '$hours órája';
  }

  @override
  String timeDaysAgo(int days) {
    return '$days napja';
  }

  @override
  String get safetyCenterTitle => 'Biztonsági központ';

  @override
  String get safetyCenterIntro =>
      'Néhány egyszerű szabály, hogy a ShelfShare-en zajló cserék kellemesek és biztonságosak legyenek.';

  @override
  String get safetyTip1Title => 'Találkozzatok nappal';

  @override
  String get safetyTip1Desc =>
      'Ütemezd a cserét egy természetes fényben zajló időpontra, lehetőleg délelőtt vagy délután.';

  @override
  String get safetyTip2Title => 'Válassz nyilvános helyet';

  @override
  String get safetyTip2Desc =>
      'Egy kávézó, könyvesbolt vagy bevásárlóközpont biztonságosabb, mint valakinek a magánlakása.';

  @override
  String get safetyTip3Title =>
      'Részesítsd előnyben a kamerával megfigyelt helyeket';

  @override
  String get safetyTip3Desc =>
      'A biztonsági kamerákkal felszerelt területek elrettentik a kellemetlen viselkedést.';

  @override
  String get safetyTip4Title => 'Ne oszd meg személyes adataidat';

  @override
  String get safetyTip4Desc =>
      'Nincs szükség a lakcímedre, személyi számodra vagy más érzékeny adatra a cseréhez.';

  @override
  String get safetyTip5Title =>
      'Ellenőrizd az értékelést és a megbízhatósági pontszámot';

  @override
  String get safetyTip5Desc =>
      'A befejezett cserék jó előzménye jó jel, mielőtt találkoznál valakivel.';

  @override
  String get safetyTip6Title => 'Egy valódi profilkép növeli a bizalmat';

  @override
  String get safetyTip6Desc =>
      'A fényképpel és teljes bemutatkozással rendelkező profilok nagyobb biztonságérzetet keltenek.';

  @override
  String get safetyTip7Title => 'Ellenőrizd a könyv állapotát a csere előtt';

  @override
  String get safetyTip7Desc =>
      'Hasonlítsd össze a könyvet a hirdetés leírásával, mielőtt befejezettként megerősítenéd a cserét.';

  @override
  String get safetyTip8Title => 'Jelents be minden gyanús viselkedést';

  @override
  String get safetyTip8Desc =>
      'Bejelentheted vagy letilthatod a felhasználót közvetlenül a profiljából vagy a beszélgetésből.';

  @override
  String get helpCenterTitle => 'Gyakori kérdések';

  @override
  String get helpFaq1Question => 'Hogyan működik a könyvcsere?';

  @override
  String get helpFaq1Answer =>
      'Kérsz egy könyvet valaki más hirdetéséből (te is felajánlhatsz cserébe egy könyvet), a tulajdonos elfogadja vagy elutasítja, majd chat-en keresztül megbeszélitek a találkozót. Miután a valóságban is lezajlott a csere, bármelyiktek megjelölheti befejezettként.';

  @override
  String get helpFaq2Question => 'Mi az a Megbízhatósági pontszám?';

  @override
  String get helpFaq2Answer =>
      'Egy 0-100 közötti, automatikusan számított mutató az alkalmazásban végzett tevékenység alapján: a fiók életkora, megerősített email, hány cserét fejeztél be, kapott értékelésed, milyen gyakran válaszolsz, és milyen ritkán mondasz le kéréseket. Nem személyazonosság-ellenőrzés, csak viselkedési jelzés.';

  @override
  String get helpFaq3Question => 'Hogyan számítjuk a „könyvesbolt” árat?';

  @override
  String get helpFaq3Answer =>
      'Amikor ISBN-nel adsz hozzá egy könyvet, megpróbáljuk megtalálni a listaárat a Google Booksön. A lefedettség részleges - nem minden könyvnek van ott elérhető ára, különösen a régebbi vagy román kiadásoknak.';

  @override
  String get helpFaq4Question => 'Mit jelent a „Fix ár, nem alkudható”?';

  @override
  String get helpFaq4Answer =>
      'Ha az eladó ezt bejelöli, a vevők többé nem küldhetnek árajánlatot - a könyv csak a feltüntetett áron vásárolható meg.';

  @override
  String get helpFaq5Question =>
      'Hogyan jelenthetek be vagy tilthatok le egy felhasználót?';

  @override
  String get helpFaq5Answer =>
      'A beszélgetés jobb felső sarkában lévő menüből, vagy egy hirdetés részletei oldaláról (zászló ikon). A letiltás mindkét irányban leállítja az üzeneteket.';

  @override
  String get helpFaq6Question =>
      'Mi történik a könyvvel, miután eladtam vagy elcseréltem?';

  @override
  String get helpFaq6Answer =>
      'A hirdetés véglegesen elérhetetlenné válik. Ha a könyvet átvevő személy tovább szeretné listázni, ezt megteheti a Cserék/Ajánlatok képernyőről (\"Add hozzá a könyvtáradhoz\") - a könyv előzménye nyomon követhető marad a részletek oldalán, minden tulajdonos fotóival.';

  @override
  String get helpFaq7Question =>
      'Miért nem jelenik meg egy könyv a Kategóriákban vagy a Hasonló könyvek között?';

  @override
  String get helpFaq7Answer =>
      'Egy könyv műfaja az Open Libraryből vagy a Google Booksből származik hozzáadáskor - néhány könyvnek nincs kitöltve a műfaja ezeken a külső forrásokon, különösen a kevésbé népszerű kiadásoknak.';

  @override
  String get helpCenterFooter =>
      'Nem találtad meg a választ? Bejelenthetsz egy problémát közvetlenül az érintett felhasználóval folytatott beszélgetésből.';

  @override
  String get adminLoadError => 'Nem sikerült betölteni az admin adatokat.';

  @override
  String get adminStatsTitle => 'Statisztikák';

  @override
  String get adminMarketplaceStatsTitle => 'Piactér statisztikák';

  @override
  String get adminMarketplaceGmv => 'Teljes forgalmazott érték';

  @override
  String get adminMarketplaceCompletedSales => 'Befejezett eladások';

  @override
  String get adminMarketplaceCompletedAuctions => 'Befejezett árverések';

  @override
  String get adminMarketplaceAvgPrice => 'Átlagos eladási ár';

  @override
  String get adminMarketplaceTopGenres => 'Top műfajok (aktív hirdetések)';

  @override
  String get adminActiveZonesTitle => 'Aktív zónák';

  @override
  String get adminActiveZonesDesc => 'Aktív hirdetések sűrűsége városonként';

  @override
  String get adminActiveZonesEmpty => 'Még nincs aktív hirdetés.';

  @override
  String adminUsersCount(int count) {
    return 'Felhasználók ($count)';
  }

  @override
  String adminInactiveListingsCount(int count) {
    return 'Kérés nélküli hirdetések ($count)';
  }

  @override
  String get adminInactiveListingsDesc =>
      'Cserére feltett könyvek, amelyekre még senki nem küldött kérést.';

  @override
  String get adminNoInactiveListings => 'Nincs inaktív hirdetés.';

  @override
  String adminUserReportsCount(int count) {
    return 'Felhasználói bejelentések ($count)';
  }

  @override
  String get adminNoReports => 'Nincs bejelentés.';

  @override
  String adminUpcomingReleasesCount(int count) {
    return 'Hamarosan megjelenő könyvek ($count)';
  }

  @override
  String get adminUpcomingReleasesDesc =>
      'A kezdőlapon jelenik meg, a \"Hamarosan megjelenő könyvek\" szekcióban.';

  @override
  String get adminNoUpcomingReleases =>
      'Még nincs hozzáadva hamarosan megjelenő könyv.';

  @override
  String adminFeedbackCount(int count) {
    return 'Kapott visszajelzés ($count)';
  }

  @override
  String get adminNoFeedback => 'Még nincs visszajelzés küldve.';

  @override
  String adminSupportRequestsCount(int count) {
    return 'Support üzenetek ($count)';
  }

  @override
  String get adminNoSupportRequests => 'Még nincs elküldött support üzenet.';

  @override
  String adminReportedBy(String name) {
    return 'Bejelentette: $name';
  }

  @override
  String get adminUnknownAuthor => 'Ismeretlen szerző';

  @override
  String get adminAuthorOptional => 'Szerző (opcionális)';

  @override
  String get adminCoverUrlOptional => 'Borító URL (opcionális)';

  @override
  String get adminPickReleaseDate => 'Válaszd ki a megjelenés dátumát';

  @override
  String adminReleaseDateLabel(String date) {
    return 'Megjelenés: $date';
  }

  @override
  String get adminAdd => 'Hozzáadás';

  @override
  String get adminTitleDateRequired => 'A cím és a megjelenés dátuma kötelező';

  @override
  String get adminAddBookError => 'Nem sikerült hozzáadni a könyvet';

  @override
  String get adminDeleteUserTitle => 'Törlöd a felhasználót?';

  @override
  String adminDeleteUserBody(String name) {
    return 'Ez véglegesen törli $name fiókját és minden hozzá tartozó adatot (könyvek, cserék, üzenetek). Nem vonható vissza.';
  }

  @override
  String get adminStatsUsersLabel => 'Felhasználók';

  @override
  String adminStatsUsersSubtitle(int count) {
    return 'ebből $count megerősített';
  }

  @override
  String get adminStatsBooksLabel => 'Könyvek a katalógusban';

  @override
  String adminStatsBooksSubtitle(int count) {
    return '$count listázott példány';
  }

  @override
  String get adminStatsExchangesLabel => 'Cserék';

  @override
  String adminStatsExchangesSubtitle(int completed, int pending) {
    return '$completed befejezett · $pending folyamatban';
  }

  @override
  String get auctionTitle => 'Árverés';

  @override
  String get auctionCurrentPrice => 'Jelenlegi ár';

  @override
  String get auctionBidsCount => 'licit';

  @override
  String get auctionReserveMet => 'A minimálár teljesült';

  @override
  String get auctionReserveNotMet => 'A minimálár még nem teljesült';

  @override
  String get auctionEndedWithWinner => 'Az árverés véget ért - valaki nyert';

  @override
  String get auctionEndedNoWinner => 'Az árverés győztes nélkül ért véget';

  @override
  String auctionBidAmountLabel(String amount) {
    return 'Licit (minimum $amount lej)';
  }

  @override
  String get auctionPlaceBid => 'Licitálok';

  @override
  String auctionBuyNowFor(String amount) {
    return 'Azonnal megveszem $amount lejért';
  }

  @override
  String get auctionBidHistory => 'Licitek története';

  @override
  String get auctionNoBidsYet => 'Még nincs licit';

  @override
  String get auctionWatch => 'Árverés követése';

  @override
  String get auctionBidPlaced => 'Licit leadva';

  @override
  String get auctionBoughtNow => 'Sikeres vásárlás';

  @override
  String get auctionGenericError => 'Hiba történt, próbáld újra';

  @override
  String get auctionEnded => 'Lezárult';

  @override
  String auctionEndsInDays(int days) {
    return '$days nap múlva zárul';
  }

  @override
  String auctionEndsInHours(int hours) {
    return '$hours óra múlva zárul';
  }

  @override
  String auctionEndsInMinutes(int minutes) {
    return '$minutes perc múlva zárul';
  }

  @override
  String get bulkAddTitle => 'Több könyv hozzáadása';

  @override
  String get bulkAddScanTooltip => 'Vonalkód szkennelése';

  @override
  String get bulkAddManualEntry => 'Manuális bevitel';

  @override
  String get bulkAddManualHint =>
      'Illessz be több ISBN-t, soronként egyet (vagy vesszővel elválasztva)';

  @override
  String get bulkAddManualPlaceholder => '9780439023481\n9780441172719';

  @override
  String get bulkAddAddIsbns => 'Hozzáadás a listához';

  @override
  String get bulkAddQueueEmpty =>
      'Még nincs hozzáadott könyv - szkennelj vagy adj meg egy ISBN-t.';

  @override
  String bulkAddSubmit(int count) {
    return '$count könyv hozzáadása';
  }

  @override
  String bulkAddResultSummary(int created, int failed) {
    return '$created könyv hozzáadva, $failed sikertelen';
  }

  @override
  String inventorySelectedCount(int count) {
    return '$count kiválasztva';
  }

  @override
  String get inventoryMarkUnavailable => 'Megjelölés nem elérhetőként';

  @override
  String get inventoryChangePriceTitle => 'Ár módosítása';

  @override
  String inventoryPriceChangedCount(int count) {
    return 'Ár módosítva $count hirdetésen';
  }

  @override
  String get inventoryDeleteConfirmTitle =>
      'Törlöd a kiválasztott hirdetéseket?';

  @override
  String inventoryDeleteConfirmBody(int count) {
    return 'Ez véglegesen törli $count hirdetést. Nem vonható vissza.';
  }

  @override
  String get inventoryBulkDone => 'Művelet alkalmazva';
}
