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
  String get navSearch => 'Felfedezés';

  @override
  String get navLibrary => 'A polcom';

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
  String get commonEdit => 'Editează';

  @override
  String get commonShowMore => 'Vezi mai mult';

  @override
  String get commonShowLess => 'Vezi mai puțin';

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
  String get bookAvailableForSwapShort => 'Csere';

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
  String get surveyTitle => 'Mit szeretsz olvasni?';

  @override
  String get surveySubtitle =>
      'Néhány válasz alapján ajánlani tudunk hozzád illő könyveket, és szólunk, ha felkerül egy a kedvedre való.';

  @override
  String get surveyGenresQuestion => 'Mely műfajok vonzanak?';

  @override
  String get surveyGenresLoadError =>
      'Nem sikerült betölteni a műfajok listáját.';

  @override
  String get surveyAuthorsQuestion => 'Kedvenc szerzők (opcionális)';

  @override
  String get surveyAuthorsHint => 'Pl.: Mihail Sadoveanu, Ursula K. Le Guin';

  @override
  String get surveyPaceQuestion => 'Hány könyvet olvasol havonta?';

  @override
  String get surveySubmit => 'Mentés';

  @override
  String get surveySkip => 'Most kihagyom';

  @override
  String get surveySaveError =>
      'Nem sikerült elmenteni a válaszokat. Próbáld újra.';

  @override
  String get surveyChangeLaterHint =>
      'A válaszaidat bármikor módosíthatod a profilodban.';

  @override
  String surveyPaceOption(String pace) {
    return '$pace könyv havonta';
  }

  @override
  String get profilePhotoChoose => 'Válassz fényképet';

  @override
  String get profilePhotoRemove => 'Fénykép eltávolítása';

  @override
  String get profilePhotoError => 'Nem sikerült frissíteni a profilképet.';

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
  String get homeMostSearched => 'Legkeresettebb';

  @override
  String get homeSeeAll => 'Összes megtekintése';

  @override
  String homePendingSwapBanner(int count) {
    return '$count cserekérés vár rád';
  }

  @override
  String get homePendingSwapReview => 'Áttekintés';

  @override
  String get homeFeedEnd => 'Minden könyvet láttál';

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
  String get bookConditionNew => 'Új';

  @override
  String get bookConditionVeryGood => 'Nagyon jó';

  @override
  String get bookConditionGood => 'Jó';

  @override
  String get bookConditionAcceptable => 'Elfogadható';

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
  String get libraryTitle => 'A polcom';

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
  String libraryShelfSubtitle(int total, int available) {
    return '$total könyv · $available elérhető cserére';
  }

  @override
  String libraryFilterAll(int count) {
    return 'Összes $count';
  }

  @override
  String libraryFilterAvailable(int count) {
    return 'Elérhető $count';
  }

  @override
  String libraryFilterUnavailable(int count) {
    return 'Nem elérhető $count';
  }

  @override
  String libraryFilterTransferred(int count) {
    return 'Átadva $count';
  }

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
  String get bookDetailWishlistError =>
      'Nem sikerült frissíteni a kívánságlistát';

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
  String get bookDetailMessageOwner => 'Mesaj';

  @override
  String get bookDetailAvailabilityTitle => 'Disponibilitate';

  @override
  String get bookDetailReadyToExchange => 'Gata de schimb';

  @override
  String get bookDetailLocationTitle => 'Locație';

  @override
  String get bookDetailViewOnMap => 'Vezi pe hartă';

  @override
  String get bookDetailAvailableForExchangeHint =>
      'Această carte este disponibilă la schimb';

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
  String get chatSendFailed =>
      'Az üzenetet nem sikerült elküldeni. Ellenőrizd a kapcsolatot.';

  @override
  String get chatOnline => 'online';

  @override
  String get chatOffline => 'offline';

  @override
  String get chatLastSeenJustNow => 'az imént volt online';

  @override
  String chatLastSeenMinutes(int minutes) {
    return '$minutes perce volt online';
  }

  @override
  String chatLastSeenHours(int hours) {
    return '$hours órája volt online';
  }

  @override
  String chatLastSeenDays(int days) {
    return '$days napja volt online';
  }

  @override
  String get chatSeen => 'Látta';

  @override
  String get chatSent => 'Elküldve';

  @override
  String get chatReply => 'Válasz';

  @override
  String get chatCopyMessage => 'Üzenet másolása';

  @override
  String get chatMessageCopied => 'Üzenet másolva';

  @override
  String get chatReplyToYou => 'Te';

  @override
  String get chatReplyToThem => 'Idézett üzenet';

  @override
  String get chatAttachPhoto => 'Fénykép küldése';

  @override
  String get chatPhotoSendError => 'Nem sikerült elküldeni a fényképet.';

  @override
  String get chatSearchInConversation => 'Keresés a beszélgetésben';

  @override
  String get chatSearchNoResults => 'Nincs találat.';

  @override
  String get chatArchive => 'Archiválás';

  @override
  String get chatUnarchive => 'Kivétel az archívumból';

  @override
  String get chatArchived => 'Beszélgetés archiválva';

  @override
  String get chatArchivedTitle => 'Archivált';

  @override
  String get chatEmptyArchived => 'Nincs archivált beszélgetésed.';

  @override
  String get chatDeleteTitle => 'Csevegés törlése';

  @override
  String get chatDeleteConfirm =>
      'A beszélgetés csak nálad tűnik el. A másik fél megtartja az üzeneteit.';

  @override
  String get chatActionError => 'Nem sikerült. Próbáld újra.';

  @override
  String get chatReportConversation => 'Beszélgetés jelentése';

  @override
  String get chatConversationReported =>
      'A beszélgetést jelentetted. A csapatunk átnézi.';

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
  String wishlistCount(int count) {
    return '$count könyv';
  }

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
  String get notificationsFilterAll => 'Mind';

  @override
  String get notificationsFilterUnread => 'Olvasatlan';

  @override
  String get notificationsFilterExchanges => 'Csere';

  @override
  String get notificationsFilterMessages => 'Üzenetek';

  @override
  String get notificationsToday => 'Ma';

  @override
  String get notificationsYesterday => 'Tegnap';

  @override
  String get notificationsEarlier => 'Korábbi';

  @override
  String notificationsRepeatedCount(int count) {
    return '×$count';
  }

  @override
  String notificationsUnreadCount(int count) {
    return '$count olvasatlan';
  }

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
  String get helpGroupSwapping => 'Csere';

  @override
  String get helpGroupPricing => 'Árak';

  @override
  String get helpGroupSafety => 'Bizalom és biztonság';

  @override
  String get helpStillStuck => 'Nem találtad meg a választ?';

  @override
  String get helpContactModerator => 'Moderátor elérése';

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

  @override
  String get collectionsTitle => 'Gyűjtemények';

  @override
  String get collectionsEmpty => 'Még nincs gyűjtemény.';

  @override
  String get collectionsLoadError => 'Nem sikerült betölteni a gyűjteményeket.';

  @override
  String get collectionsCreateTitle => 'Új gyűjtemény';

  @override
  String get collectionsNameLabel => 'Név';

  @override
  String get collectionsPublicSwitch => 'Nyilvános';

  @override
  String collectionsBookCount(int count) {
    return '$count könyv';
  }

  @override
  String get collectionsEmptyItems => 'Még nincs könyv ebben a gyűjteményben.';

  @override
  String get collectionsDeleteConfirmTitle => 'Törlöd ezt a gyűjteményt?';

  @override
  String get collectionsAddToTitle => 'Hozzáadás gyűjteményhez';

  @override
  String get collectionsNewInline => 'Új gyűjtemény...';

  @override
  String get groupsTitle => 'Csoportok';

  @override
  String get groupsTabDiscover => 'Felfedezés';

  @override
  String get groupsTabMine => 'Sajátjaim';

  @override
  String get groupsEmpty => 'Még nincs csoport.';

  @override
  String get groupsLoadError => 'Nem sikerült betölteni a csoportot.';

  @override
  String get groupsCreateTitle => 'Új csoport';

  @override
  String get groupsNameLabel => 'Név';

  @override
  String get groupsDescriptionLabel => 'Leírás (opcionális)';

  @override
  String groupsMemberCount(int count) {
    return '$count tag';
  }

  @override
  String get groupsJoin => 'Csatlakozás';

  @override
  String get groupsLeave => 'Kilépés a csoportból';

  @override
  String get groupsDeleteConfirmTitle => 'Törlöd ezt a csoportot?';

  @override
  String get groupsEventsTitle => 'Események';

  @override
  String get groupsNoEvents => 'Nincs ütemezett esemény.';

  @override
  String get groupsAddEventTitle => 'Esemény hozzáadása';

  @override
  String get groupsEventTitleLabel => 'Cím';

  @override
  String get groupsEventLocationLabel => 'Helyszín (opcionális)';

  @override
  String get groupsDiscussionTitle => 'Beszélgetés';

  @override
  String get groupsPostHint => 'Írj egy üzenetet...';

  @override
  String get groupsNoPosts => 'Még nincs üzenet.';

  @override
  String get premiumBadgeTooltip => 'Premium tag';

  @override
  String get adminGrantPremium => 'Premium megadása';

  @override
  String get adminRemovePremium => 'Premium eltávolítása';

  @override
  String get premiumPromoteListing => 'Hirdetés kiemelése';

  @override
  String get premiumUnpromoteListing => 'Kiemelés visszavonása';

  @override
  String get premiumAnalyticsTitle => 'Speciális statisztikák';

  @override
  String get premiumAnalyticsTotalListings => 'Aktív hirdetések';

  @override
  String get premiumAnalyticsTotalViews => 'Összes megtekintés';

  @override
  String get premiumAnalyticsOffersReceived => 'Kapott ajánlatok';

  @override
  String get premiumAnalyticsConversionRate => 'Konverziós arány';

  @override
  String get premiumAnalyticsRevenue => 'Összes bevétel';

  @override
  String get premiumAnalyticsTopListings => 'Legnézettebb hirdetések';

  @override
  String get premiumAnalyticsLocked =>
      'A speciális statisztikák Premium funkció.';

  @override
  String get premiumAnalyticsLoadError =>
      'Nem sikerült betölteni a statisztikákat.';

  @override
  String get discoverMostWishedFor => 'Legkívántabbak';

  @override
  String get discoverMostLookedFor => 'Legkeresettebbek';

  @override
  String get discoverSearchTooltip => 'Könyvek keresése';

  @override
  String get discoverTopSearches => 'Népszerű keresések';

  @override
  String get discoverAuctions => 'Aktív aukciók';

  @override
  String get discoverHiddenGems => 'Rejtett gyöngyszemek';

  @override
  String get discoverSwapOnly => 'Csak csere';

  @override
  String discoverMoreGenres(int count) {
    return '+ $count további';
  }

  @override
  String get discoverUnder30 => '30 lej alatt';

  @override
  String get discoverRecommendedForYou => 'Neked ajánlott';

  @override
  String get discoverPopularAuthors => 'Népszerű szerzők';

  @override
  String get discoverQuickFilters => 'Gyors szűrők';

  @override
  String get discoverNearYou => 'A városodban';

  @override
  String get inventorySelectAll => 'Összes kijelölése';

  @override
  String get myShelfShare => 'Megosztás';

  @override
  String get inventoryMarkAvailable => 'Elérhetőnek jelöl';

  @override
  String get libraryTrashEmpty => 'A kuka üres';

  @override
  String get inventoryAppendText => 'Hozzáfűz a végéhez';

  @override
  String get inventoryTransferred => 'Átadva';

  @override
  String inventoryDeletedDaysLeft(int days) {
    return '$days nap múlva törli';
  }

  @override
  String get libraryEmptiedShelves => 'Elajándékozott vagy cserélt könyvek';

  @override
  String get libraryRestored => 'Könyv visszaállítva';

  @override
  String get inventoryDescriptionDone => 'Leírások frissítve';

  @override
  String get libraryTrashHint =>
      'A törölt könyvek 7 napig maradnak itt, majd véglegesen törlődnek';

  @override
  String get inventoryBulkEditDescription => 'Tömeges leírás szerkesztés';

  @override
  String get libraryTrash => 'Kuka';

  @override
  String get inventoryRemoveText => 'Törlés a szövegből';

  @override
  String get libraryRestore => 'Visszaállít';

  @override
  String get libraryEmptiedShelvesEmpty => 'Még nincsenek átadott könyvek';

  @override
  String get shareMaxTagsReached => 'Legfeljebb 5 címkét adhatsz hozzá';

  @override
  String get shareTitleHint => 'Könyvcím';

  @override
  String get shareTagsHint => 'Címkék (max 5)';

  @override
  String get shareEditionYear => 'Kiadás éve';

  @override
  String get shareDescriptionHint => 'Leírás (max 256 karakter)';

  @override
  String get shareMoreInfo => 'További információk';

  @override
  String get shareAuthorHint => 'Szerző';

  @override
  String get sharePageCountCustom => 'Oldalszám (felülírja az autofillt)';

  @override
  String get shareTagAdd => 'Címke hozzáadása';

  @override
  String get sharePublisher => 'Kiadó';

  @override
  String get shareCityHint => 'Város, ahol a csere történik';

  @override
  String get sharePublishedYear => 'Kiadás éve';

  @override
  String get shareSubmit => 'Közzététel';

  @override
  String get shareListingModeAuction => 'Aukció';

  @override
  String get shareSectionBook => 'A könyv';

  @override
  String get shareSectionListing => 'A hirdetés';

  @override
  String get shareListingMode => 'Hirdetés típusa';

  @override
  String shareDescriptionCharsLeft(int n) {
    return '$n karakter maradt';
  }

  @override
  String get shareListingModeSwap => 'Normál csere';

  @override
  String get shareListingModeSale => 'Eladó';

  @override
  String get shareListingModeDonation => 'Adomány';

  @override
  String get shareTitleAutocomplete => 'Kezdj el gépelni a javaslatokért';

  @override
  String get shareGenreHint => 'Műfaj';

  @override
  String get shareAddPhotos => 'Fotók hozzáadása';

  @override
  String get preRegisterAlreadyLoggedIn =>
      'A fiókod címét használjuk, ha üresen hagyod';

  @override
  String get preRegisterAndroidHeadline => 'Hamarosan a telefonodon';

  @override
  String get preRegisterSuccess => 'Rajta vagy a listán. Szólunk, amikor kész.';

  @override
  String get profilePreRegister => 'Előregisztráció Androidra';

  @override
  String get preRegisterAndroidBody =>
      'Hagyd meg az e-mail címed és értesítünk, amint az app elérhető a Google Play-en.';

  @override
  String get preRegisterSubmit => 'Felkerülök a listára';

  @override
  String get preRegisterAndroidTitle => 'Előregisztráció Androidra';

  @override
  String get preRegisterEmailHint => 'E-mail az értesítéshez';

  @override
  String get preRegisterError =>
      'Nem sikerült regisztrálni az e-mailt. Próbáld újra.';

  @override
  String get profileSettingsSubtitle => 'Minden fiókbeállítás egy helyen';

  @override
  String get profileGroupProfile => 'Profil';

  @override
  String get profileGroupPreferences => 'Beállítások';

  @override
  String get profileGroupLibrary => 'Könyvtár';

  @override
  String get profileGroupSupport => 'Támogatás';

  @override
  String get profileRecentActivity => 'Legutóbbi tevékenység';

  @override
  String get profileStatSwaps => 'csere';

  @override
  String get profileActivityAdded => 'Hozzáadva';

  @override
  String get profileMoreInSettings => 'További lehetőségek fent „⚙\"';

  @override
  String profileLibraryAvailable(int n) {
    return '$n elérhető';
  }

  @override
  String get profileStatRating => 'értékelés';

  @override
  String get profileStatBooks => 'könyv';

  @override
  String get profileSettings => 'Beállítások';

  @override
  String get profileKeepAlive => 'Keep the app alive';

  @override
  String get profileKeepAliveSubtitle =>
      'ShelfShare rulează pe un server de acasă. Un cafea ajută.';

  @override
  String get aboutDevTitle => 'About dev';

  @override
  String get aboutDevHeadline => 'Omul din spatele ShelfShare';

  @override
  String get aboutDevBodyWho =>
      'Sunt un mic dezvoltator care lucrează la o companie de IT din Transilvania.';

  @override
  String get aboutDevBodyWhy =>
      'Am făcut aplicația asta pentru că foloseam una exact ca ea, dar a dispărut din… motive? Așa că mi-am făcut una singur.';

  @override
  String get aboutDevBodyHosting =>
      'Te rog să nu te superi pe eventualele sughițuri ale aplicației - totul e găzduit de mine, pe micul meu server de acasă ☹️';

  @override
  String get aboutDevSupportTitle => 'Keep the app alive';

  @override
  String get aboutDevSupportSubtitle =>
      'Serverul, domeniul și backup-urile ies din buzunarul meu. Orice contribuție ține aplicația pornită.';

  @override
  String get aboutDevCoffeeButton => 'Buy me a coffee';

  @override
  String get aboutDevOpenError =>
      'Nu am putut deschide linkul. Încearcă din nou.';

  @override
  String get loginMadeWithLove => 'Made with ❤️ in Transilvanya';

  @override
  String get homeRecommendedTitle => 'Recomandate pentru tine';

  @override
  String homeNearbyTitle(int km) {
    return 'Aproape de tine ($km km)';
  }

  @override
  String get shareTagsSuggestions => 'Sugestii:';

  @override
  String get shareCityUnknown => 'Alege un oraș din listă';

  @override
  String get gamificationHowItWorks => 'Cum funcționează XP-ul';

  @override
  String gamificationXpIntro(int n) {
    return 'Fiecare $n XP înseamnă un nivel nou. XP-ul se acordă automat, la acțiuni din aplicație:';
  }

  @override
  String get gamificationXpBookListed => 'Listezi o carte';

  @override
  String get gamificationXpExchangeCompleted => 'Finalizezi un schimb';

  @override
  String get gamificationXpSaleCompleted => 'Finalizezi o vânzare';

  @override
  String get gamificationXpReviewWritten => 'Scrii o recenzie';

  @override
  String get gamificationNoMaxLevel =>
      'Nu există nivel maxim - curba e liniară, poți urca oricât.';

  @override
  String get profileBirthdayDay => 'Zi';

  @override
  String get profileBirthdayMonth => 'Luna nașterii';

  @override
  String get profileBirthdayNone => '—';

  @override
  String get profileLanguagesTitle => 'Limbile în care citești';

  @override
  String get profileAboutEmpty =>
      'Spune ceva despre tine — de exemplu ce genuri îți plac.';

  @override
  String get profileMemberSince => 'Membru din';

  @override
  String get profileLocation => 'Locație';

  @override
  String get profileLanguages => 'Limbi';

  @override
  String get countryRomania => 'România';

  @override
  String get profileStatsTitle => 'Statistici';

  @override
  String get profileStatBooksRead => 'Cărți citite';

  @override
  String get profileStatBooksShared => 'Cărți oferite';

  @override
  String get profileStatWishlisted => 'Cărți dorite';

  @override
  String get profileTopGenresTitle => 'Top genuri';

  @override
  String get profileTopGenresEmpty =>
      'Genurile vor apărea aici pe măsură ce citești și adaugi cărți.';

  @override
  String get navNotifications => 'Notificări';

  @override
  String get navShortcuts => 'SCURTĂTURI';

  @override
  String get shortcutsEditTooltip => 'Parancsikonok szerkesztése';

  @override
  String get shortcutsDoneTooltip => 'Kész';

  @override
  String get shortcutsAddTitle => 'Parancsikon hozzáadása';

  @override
  String get shortcutsAllAdded => 'Az összes parancsikon már hozzá van adva.';

  @override
  String get shortcutFollowing => 'Követett';

  @override
  String get shortcutLeaderboard => 'Ranglista';

  @override
  String get shortcutSellerAnalytics => 'Eladói analitika';

  @override
  String get shortcutPreRegister => 'Előregisztráció';

  @override
  String get shortcutTrash => 'Kuka';

  @override
  String get shareCoverSelected => 'Könyv borító';

  @override
  String get shareCoverRecommended => 'Ajánlott borítók';

  @override
  String get shareMainPhotoHint =>
      'Érintsd meg a csillagot a főkép beállításához (a feed-ben jelenik meg).';

  @override
  String get chatOfferCounterAction => 'Ellenajánlat';

  @override
  String get chatOfferCounterTitle => 'Ellenajánlat küldése';

  @override
  String get navMyBooks => 'Cărțile mele';

  @override
  String get navMyExchanges => 'Schimburile mele';

  @override
  String get navWishlist => 'Lista de dorințe';

  @override
  String get navMyCollections => 'Colecțiile mele';

  @override
  String get navAboutApp => 'Despre aplicație';

  @override
  String get aboutAppTitle => 'Despre aplicație';

  @override
  String get aboutAppIntro =>
      'Aici găsești pe scurt cum funcționează fiecare parte din ShelfShare. Deschide o secțiune ca să vezi detaliile.';

  @override
  String get aboutAppXpTitle => 'XP și niveluri';

  @override
  String get aboutAppTrustTitle => 'Trust Score';

  @override
  String get aboutAppTrustBody =>
      'Trust Score-ul e un număr între 0 și 100 calculat din activitatea ta reală: emailul verificat, câți schimburi ai finalizat cu succes, cât de repede răspunzi la mesaje, cât de vechi e contul, recenziile primite. Nu e o verificare de identitate - e un indicator care ajută pe alții să știe dacă ești un partener de schimb de încredere. Cu cât interacționezi mai mult și mai bine, cu atât crește.';

  @override
  String get aboutAppShelvesTitle => 'Raftul meu (Public Bookshelf)';

  @override
  String get aboutAppShelvesBody =>
      'Raftul e statusul tău personal de citit pentru o carte, indiferent dacă o deții fizic sau nu.\n\n• Citesc — cartea la care lucrezi acum\n• Vreau să citesc — lista ta de dorințe pentru viitor\n• Citită — cărțile pe care le-ai terminat\n\nCărțile pe care le poți da la schimb sau vinde sunt separate - stau în „Biblioteca mea\" (My Shelf din meniu). O carte poate fi și pe raft (ex. „Vreau să citesc\") și în bibliotecă (ex. „Am un exemplar de vânzare\") - sunt două noțiuni diferite.';

  @override
  String get aboutAppHomeSectionsTitle => 'Cele 3 secțiuni de pe Home';

  @override
  String get aboutAppHomeSectionsBody =>
      'Home-ul e feed-ul cu ultimele cărți listate. Între rânduri apar 3 secțiuni tematice:\n\n• Most Sought After — cele mai vizualizate cărți din platformă\n• Aproape de tine (25 km) — cărți disponibile în raza asta față de orașul tău. Se ascunde dacă nu ai oraș setat sau dacă nu e nimic aproape\n• Recomandate pentru tine — cărți filtrate după genurile și autorii din profilul tău. Dacă n-ai completat chestionarul de cititor, secțiunea nu apare';

  @override
  String get aboutAppExchangesTitle => 'Schimburi și oferte';

  @override
  String get aboutAppExchangesBody =>
      'Sunt două căi de a obține o carte de la altcineva:\n\n• Schimb — propui o carte din biblioteca ta în schimbul uneia din biblioteca altui user. E gratuit, doar cu costul expedierii\n• Ofertă de preț — dacă o carte e listată la vânzare și marcată „negociabil\", poți trimite o ofertă cu preț diferit. Vânzătorul acceptă, respinge sau vine cu contra-ofertă';

  @override
  String get aboutAppBadgesTitle => 'Insigne (Achievements)';

  @override
  String get aboutAppBadgesBody =>
      'Insignele se acordă automat când atingi anumite praguri: primul schimb, 10 schimburi, 50 de schimburi, primul review scris, primul cont al comunității, insigna de supporter (dacă susții proiectul prin „Keep the app alive\"), etc.\n\nSunt vizibile pe profilul tău public. Nu au impact funcțional - doar recunosc contribuția.';

  @override
  String get aboutAppChatTitle => 'Chat';

  @override
  String get aboutAppChatBody =>
      'Poți începe o conversație direct din pagina unei cărți sau din profilul altui user. Toate mesajele sunt criptate în timpul transmiterii.\n\nRegulă simplă de siguranță: nu da niciodată date personale (CNP, număr de card, adresa completă) în chat. Pentru schimburi, folosește adresa poștală doar când ești sigur de partener.';

  @override
  String get aboutAppAccountDeletionTitle => 'Ștergerea contului';

  @override
  String get aboutAppAccountDeletionBody =>
      'Dacă vrei să-ți ștergi contul, o poți face din Setări → „Șterge contul\". După confirmare ai o perioadă de grație de 15 zile în care te poți răzgândi (reintri și dai „Anulează ștergerea\"). După 15 zile, contul și toate datele legate de el sunt șterse definitiv.';

  @override
  String get chatNewConversationTooltip => 'Conversație nouă';

  @override
  String get chatSearchHint => 'Caută în conversații…';

  @override
  String get chatFilterAll => 'Toate';

  @override
  String get chatFilterUnread => 'Necitite';

  @override
  String get chatFilterArchived => 'Arhivate';

  @override
  String get chatEmptySearch => 'Nicio conversație nu se potrivește căutării.';

  @override
  String get chatEmptyUnread => 'Toate conversațiile sunt citite.';

  @override
  String get chatSafetyHeadline => 'Bine ai venit în Chat';

  @override
  String get chatSafetyIntro =>
      'Aici discuți cu ceilalți cititori despre schimburi, oferte și cărți. Alege o conversație din stânga sau ține minte câteva reguli înainte să începi.';

  @override
  String get chatSafetyPersonalTitle => 'Nu da date personale';

  @override
  String get chatSafetyPersonalBody =>
      'CNP, număr de card, adresa exactă sau parole — niciodată în chat. Nici măcar dacă „e nevoie pentru livrare\" sau dacă cineva insistă.';

  @override
  String get chatSafetyPaymentTitle => 'Plăți sigure';

  @override
  String get chatSafetyPaymentBody =>
      'Pentru vânzări, folosește metode cu protecție (transfer bancar cu factură, ramburs). Evită plățile în avans către useri fără istoric.';

  @override
  String get chatSafetyMeetupTitle => 'Întâlnește-te în loc public';

  @override
  String get chatSafetyMeetupBody =>
      'Pentru schimburi în persoană, alege o cafenea, o bibliotecă sau piața centrală. Nu invita pe cineva acasă la primul schimb.';

  @override
  String get chatSafetyReportTitle => 'Raportează ce ți se pare suspect';

  @override
  String get chatSafetyReportBody =>
      'Un utilizator care cere date personale, care insistă cu plăți neobișnuite sau al cărui profil e gol — apasă pe „…\" din header și raportează.';

  @override
  String get chatSafetyOpenCenter => 'Deschide Centrul de siguranță';

  @override
  String get chatSafetyHint =>
      'Poți reveni oricând aici — pagina se deschide când nu ai nicio conversație selectată.';

  @override
  String get greetReaderFallback => 'Cititorule';

  @override
  String get greetMorningSun => 'Bună dimineața, Soare! ☀️';

  @override
  String greetMorningNamed(String name) {
    return 'Bună dimineața, $name!';
  }

  @override
  String get greetMorningCoffeeBook => 'O cafea și o carte?';

  @override
  String get greetMorningCoffee => 'Bună dimineața la cafeluță! ☕';

  @override
  String get greetMorningStartStory => 'Începe ziua cu o poveste.';

  @override
  String get greetMorningAdventure => 'Răsare o nouă aventură.';

  @override
  String get greetMorningSleptWell => 'Sper că ai dormit bine!';

  @override
  String get greetMorningPerfectBook => 'Astăzi poate găsești cartea perfectă.';

  @override
  String get greetMorningNicer => 'Diminețile sunt mai frumoase cu o carte.';

  @override
  String greetDayNamed(String name) {
    return 'Salut, $name!';
  }

  @override
  String get greetDayDiscover => 'Ce carte descoperi astăzi?';

  @override
  String get greetDayAdventure => 'O nouă aventură te așteaptă.';

  @override
  String get greetDayLibrary => 'Biblioteca te așteaptă.';

  @override
  String get greetDayCorporateCoffee => 'Cafeluța corporatistă?';

  @override
  String get greetDayWhatsNext => 'Ce urmează pe lista ta?';

  @override
  String get greetDaySwappedToday => 'Ai schimbat o carte azi?';

  @override
  String get greetDayNewReader => 'Fiecare carte are un nou cititor.';

  @override
  String get greetDayFindNext => 'Găsește-ți următoarea lectură.';

  @override
  String get greetEveningHello => 'Bună seara!';

  @override
  String get greetEveningHowWasDay => 'Cum a fost ziua ta?';

  @override
  String get greetEveningPerfectNow => 'O carte merge perfect acum.';

  @override
  String get greetEveningFewPages => 'E timpul pentru câteva pagini.';

  @override
  String get greetEveningRelax => 'Relaxează-te cu o poveste.';

  @override
  String get greetEveningQuiet => 'O seară liniștită începe cu o carte.';

  @override
  String get greetEveningWhatTonight => 'Ce citești în seara asta?';

  @override
  String get greetEveningBeforeBed =>
      'Poate găsești ceva nou înainte de culcare.';

  @override
  String get greetNightGoodNight => 'Noapte bună! 🌙';

  @override
  String get greetNightSandman => 'Moș Ene pe la gene. 😴';

  @override
  String get greetNightCloseBook => 'E timpul să închidem cartea.';

  @override
  String greetNightSleepWell(String name) {
    return 'Somn ușor, $name!';
  }

  @override
  String get greetNightOneMoreChapter => 'Mai citești un capitol?';

  @override
  String get greetNightSeeYouTomorrow => 'Ne vedem mâine printre cărți.';

  @override
  String get greetNightNiceDay => 'Sper că ai avut o zi frumoasă.';

  @override
  String get greetNightQuiet => 'Noapte liniștită!';

  @override
  String get greetLateAwake => 'Încă treaz? 📖';

  @override
  String get greetLateNightOwl => 'Bufniță de noapte?';

  @override
  String get greetLateMidnightReads =>
      'Lecturile de la miezul nopții sunt speciale.';

  @override
  String get greetLateOneChapter => 'Mai e doar un capitol, nu?';

  @override
  String get greetLateNeverSleeps => 'ShelfShare nu doarme niciodată.';

  @override
  String get greetLateCompany => 'Cărțile țin companie și la ore târzii.';

  @override
  String get greetLateLastChapter =>
      'Noapte bună... când ajungi la ultimul capitol.';

  @override
  String get greetLateForgotSleep => 'Sperăm că nu ai uitat de somn.';

  @override
  String get greetWeekend => 'E weekend! Ce carte iei cu tine?';

  @override
  String get greetMonday => 'Luni... măcar ai o carte bună.';

  @override
  String get greetFridayEvening => 'Vineri seara? Perfect pentru citit.';

  @override
  String get greetBirthday => 'La mulți ani! 🎉';

  @override
  String get greetNationalDay => 'La mulți ani, România! 🇷🇴';

  @override
  String get greetChristmas => 'Crăciun fericit! 🎄';

  @override
  String get greetEaster => 'Paște fericit! 🐰';

  @override
  String get greetNewYear => 'An nou, cărți noi! 🎆';

  @override
  String get greetBookDay => 'Astăzi este Ziua Internațională a Cărții! 📚';
}
