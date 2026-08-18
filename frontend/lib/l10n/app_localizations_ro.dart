// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Romanian Moldavian Moldovan (`ro`).
class AppLocalizationsRo extends AppLocalizations {
  AppLocalizationsRo([String locale = 'ro']) : super(locale);

  @override
  String get navHome => 'Acasă';

  @override
  String get navSearch => 'Descoperă';

  @override
  String get navLibrary => 'Raftul meu';

  @override
  String get navChat => 'Chat';

  @override
  String get navProfile => 'Profil';

  @override
  String get commonCancel => 'Anulează';

  @override
  String get commonSubmit => 'Trimite';

  @override
  String get commonSave => 'Salvează';

  @override
  String get commonSeeAll => 'Vezi tot';

  @override
  String get commonUnknownUser => 'Utilizator';

  @override
  String get commonAbout => 'Despre';

  @override
  String get commonRating => 'Rating';

  @override
  String get commonBooksExchanged => 'Cărți schimbate';

  @override
  String get commonRetry => 'Încearcă din nou';

  @override
  String get commonDone => 'Gata';

  @override
  String get commonClose => 'Închide';

  @override
  String get commonDelete => 'Șterge';

  @override
  String get commonEdit => 'Editează';

  @override
  String get commonShowMore => 'Vezi mai mult';

  @override
  String get commonShowLess => 'Vezi mai puțin';

  @override
  String get commonConfirm => 'Confirmă';

  @override
  String get commonGenericError => 'Ceva nu a mers bine. Încearcă din nou.';

  @override
  String get reportSubmitted => 'Raportul a fost trimis.';

  @override
  String get continueWithGoogle => 'Continuă cu Google';

  @override
  String get reportDialogTitle => 'Raportează';

  @override
  String get trustScoreTitle => 'Scor de încredere';

  @override
  String get trustScoreSubtitle =>
      'Calculat din activitatea din aplicație, nu e o verificare de identitate';

  @override
  String get trustScoreEmailVerified => 'Email verificat';

  @override
  String trustScoreCompletedRate(int percent) {
    return '$percent% schimburi finalizate';
  }

  @override
  String trustScoreRespondsIn(String time) {
    return 'Răspunde în ~$time';
  }

  @override
  String get trustScoreLastActiveToday => 'Activ astăzi';

  @override
  String trustScoreLastActiveDays(int days) {
    return 'Activ acum $days zile';
  }

  @override
  String trustScoreResponseRate(int percent) {
    return '$percent% rată de răspuns';
  }

  @override
  String trustScoreAverageSwapTime(String time) {
    return 'Schimb finalizat în ~$time';
  }

  @override
  String memberSinceDays(int days) {
    return 'Membru din $days zile';
  }

  @override
  String memberSinceMonths(int months) {
    return 'Membru de $months luni';
  }

  @override
  String memberSinceYears(int years) {
    return 'Membru de $years ani';
  }

  @override
  String durationMinutes(int minutes) {
    return '$minutes min';
  }

  @override
  String durationHours(int hours) {
    return '${hours}h';
  }

  @override
  String durationDays(int days) {
    return '$days zile';
  }

  @override
  String priceLei(String amount) {
    return '$amount lei';
  }

  @override
  String get bookAvailableForSwapShort => 'Schimb';

  @override
  String get commonEmailLabel => 'Email';

  @override
  String get commonEmailInvalid => 'Email invalid';

  @override
  String get commonOr => 'sau';

  @override
  String get commonRequired => 'Obligatoriu';

  @override
  String get commonContinue => 'Continuă';

  @override
  String get loginWelcomeBack => 'Bun venit înapoi';

  @override
  String get authPasswordLabel => 'Parolă';

  @override
  String get authEnterPasswordError => 'Introdu parola';

  @override
  String get authMinEightChars => 'Minim 8 caractere';

  @override
  String get authForgotPasswordLink => 'Ai uitat parola?';

  @override
  String get authLoginSubmit => 'Autentificare';

  @override
  String get authNoAccount => 'Nu ai cont? ';

  @override
  String get authCreateOne => 'Creează unul';

  @override
  String get authGoogleFailed =>
      'Autentificarea cu Google a eșuat. Încearcă din nou.';

  @override
  String get supportContactButton => 'Nu te poți loga? Contactează-ne';

  @override
  String get supportDialogTitle => 'Contactează support';

  @override
  String get supportDialogSubtitle =>
      'Spune-ne ce problemă ai și îți răspundem pe email.';

  @override
  String get supportNameLabel => 'Nume';

  @override
  String get supportPhoneLabel => 'Telefon (opțional)';

  @override
  String get supportMessageLabel => 'Mesajul tău';

  @override
  String get supportCaptchaAnswerLabel => 'Răspunsul tău';

  @override
  String get supportSubmit => 'Trimite mesajul';

  @override
  String get supportSuccessMessage =>
      'Mesaj trimis! Îți răspundem cât mai curând pe email.';

  @override
  String get supportGenericError =>
      'Nu am putut trimite mesajul. Încearcă din nou.';

  @override
  String get authRegisterTitle => 'Creează cont';

  @override
  String get authRegisterSubtitle => 'Alătură-te comunității ShelfShare';

  @override
  String get authReferralCodeLabel => 'Cod de invitație (opțional)';

  @override
  String get verifyCodeTooShort => 'Codul trebuie să aibă 6 cifre';

  @override
  String get verifySuccessSnackbar => 'Cont confirmat cu succes!';

  @override
  String get verifyInvalidOrExpired => 'Cod invalid sau expirat.';

  @override
  String get verifyResendSnackbar => 'Am retrimis codul, dacă e cazul.';

  @override
  String get verifyEmailHeading => 'Verifică-ți emailul';

  @override
  String verifySentTo(String email) {
    return 'Ți-am trimis un cod de confirmare pe $email';
  }

  @override
  String get verifyConfirmButton => 'Confirmă';

  @override
  String get verifyResending => 'Se retrimite...';

  @override
  String get verifyResendPrompt => 'Nu ai primit codul? Retrimite';

  @override
  String get forgotPasswordTitle => 'Resetează parola';

  @override
  String get forgotPasswordSubtitle =>
      'Îți trimitem un cod de resetare pe email.';

  @override
  String get forgotPasswordSubmit => 'Trimite cod';

  @override
  String get forgotPasswordCodeHeading => 'Introdu codul primit pe email';

  @override
  String forgotPasswordCodeSentTo(String email) {
    return 'Ți-am trimis un cod de resetare pe $email';
  }

  @override
  String get resetPasswordTitle => 'Setează o parolă nouă';

  @override
  String get resetPasswordSubtitle => 'Alege o parolă nouă pentru contul tău';

  @override
  String get resetPasswordNewLabel => 'Parolă nouă';

  @override
  String get resetPasswordSubmit => 'Setează parola';

  @override
  String get resetPasswordSuccessHeading => 'Parolă schimbată';

  @override
  String get resetPasswordSuccessBody =>
      'Parola ta a fost actualizată. Te poți autentifica acum.';

  @override
  String get resetPasswordGoToLogin => 'Mergi la autentificare';

  @override
  String get resetPasswordGenericError =>
      'Nu am putut reseta parola. Încearcă din nou.';

  @override
  String get authConfirmPasswordLabel => 'Confirmă parola';

  @override
  String get authPasswordMismatch => 'Parolele nu coincid';

  @override
  String get onboardingTitle => 'Aproape gata!';

  @override
  String get onboardingSubtitle => 'Spune-ne cum vrei să te vadă ceilalți';

  @override
  String get onboardingFirstName => 'Prenume';

  @override
  String get onboardingLastName => 'Nume';

  @override
  String get onboardingUsername => 'Username';

  @override
  String get onboardingUsernameFormatError =>
      '3-20 caractere: litere, cifre sau underscore';

  @override
  String get onboardingGenericError => 'A apărut o eroare. Încearcă din nou.';

  @override
  String get onboardingNameVisibleSwitch => 'Fă numele vizibil public';

  @override
  String get onboardingUsernameAlwaysVisible =>
      'Username-ul rămâne mereu vizibil';

  @override
  String get profileTitle => 'Profilul meu';

  @override
  String get surveyTitle => 'Ce îți place să citești?';

  @override
  String get surveySubtitle =>
      'Câteva răspunsuri și îți putem recomanda cărți listate care ți se potrivesc, plus o notificare când apare una pe gustul tău.';

  @override
  String get surveyGenresQuestion => 'Ce genuri te atrag?';

  @override
  String get surveyGenresLoadError => 'Nu am putut încărca lista de genuri.';

  @override
  String get surveyAuthorsQuestion => 'Autori preferați (opțional)';

  @override
  String get surveyAuthorsHint => 'Ex.: Mihail Sadoveanu, Ursula K. Le Guin';

  @override
  String get surveyPaceQuestion => 'Câte cărți citești pe lună?';

  @override
  String get surveySubmit => 'Salvează';

  @override
  String get surveySkip => 'Sar peste deocamdată';

  @override
  String get surveySaveError =>
      'Nu am putut salva răspunsurile. Încearcă din nou.';

  @override
  String get surveyChangeLaterHint =>
      'Poți schimba oricând răspunsurile din profil.';

  @override
  String surveyPaceOption(String pace) {
    return '$pace cărți pe lună';
  }

  @override
  String get profilePhotoChoose => 'Alege o poză';

  @override
  String get profilePhotoRemove => 'Șterge poza';

  @override
  String get profilePhotoError => 'Nu am putut actualiza poza de profil.';

  @override
  String get profileCopyLink => 'Copiază linkul';

  @override
  String get profileLoadError => 'Nu am putut încărca profilul.';

  @override
  String get profileAboutMe => 'Despre mine';

  @override
  String get profileBadgesTitle => 'Insigne';

  @override
  String get profileMyExchanges => 'Schimburile mele';

  @override
  String get profileSafetyCenter => 'Centru de siguranță';

  @override
  String get profileHelpCenter => 'Întrebări frecvente';

  @override
  String get profileLeaderboard => 'Clasament';

  @override
  String get profileSendFeedback => 'Trimite feedback';

  @override
  String get profileEditProfile => 'Editează profilul';

  @override
  String get profileAdminPanel => 'Panou de administrare';

  @override
  String get profileLogout => 'Deconectare';

  @override
  String get profileLanguage => 'Limbă';

  @override
  String get profileDarkModeSection => 'Mod întunecat';

  @override
  String get profileThemeSystem => 'Automat (sistem)';

  @override
  String get profileThemeLight => 'Deschis';

  @override
  String get profileThemeDark => 'Întunecat';

  @override
  String get profileQrTooltip => 'Cod QR';

  @override
  String get profileQrDialogTitle => 'Codul tău QR';

  @override
  String get profileQrDialogBody =>
      'Oricine scanează acest cod îți poate deschide profilul.';

  @override
  String get profileReferralTitle => 'Codul tău de invitație';

  @override
  String get profileReferralSubtitle =>
      'Trimite-l prietenilor ca să te descopere pe ShelfShare';

  @override
  String profileReferralCountLabel(int count) {
    return '$count prieteni invitați';
  }

  @override
  String get profileReferralCopied => 'Cod copiat în clipboard';

  @override
  String get profileFeedbackHint => 'Ce ai vrea să ne spui?';

  @override
  String get profileFeedbackThanks => 'Mulțumim pentru feedback!';

  @override
  String get profileFeedbackError => 'Nu am putut trimite feedback-ul';

  @override
  String get profileUsernameLabel => 'Username';

  @override
  String get profileCityLabel => 'Oraș';

  @override
  String get profileNoCity => 'Fără oraș';

  @override
  String get profileShowAcquisitionHistory =>
      'Arată istoricul de achiziții pe profil';

  @override
  String get profileShowAcquisitionHistorySubtitle =>
      'Cărțile pe care le-ai primit prin schimburi sau cumpărături din aplicație';

  @override
  String get profileSaveError => 'Nu am putut salva profilul.';

  @override
  String get commonSendMessage => 'Trimite mesaj';

  @override
  String get publicProfileTitle => 'Profil';

  @override
  String get publicProfileFollowUpdateError =>
      'Nu am putut actualiza urmărirea';

  @override
  String get publicProfileMessageError => 'Nu am putut porni conversația.';

  @override
  String publicProfileMemberSince(int year) {
    return 'Membru din $year';
  }

  @override
  String publicProfileFollowersFollowing(int followers, int following) {
    return '$followers urmăritori · $following urmăriți';
  }

  @override
  String get publicProfileUnfollow => 'Nu mai urmări';

  @override
  String get publicProfileFollow => 'Urmărește';

  @override
  String get publicProfileReadingStats => 'Statistici de citit';

  @override
  String get publicProfileBooksListed => 'Cărți listate';

  @override
  String get publicProfileTotalPages => 'Total pagini';

  @override
  String get publicProfileFavoriteGenre => 'Gen preferat';

  @override
  String get publicProfileBooksShared => 'Cărți date';

  @override
  String get publicProfileBooksReceived => 'Cărți primite';

  @override
  String get publicProfileLongestBook => 'Cea mai lungă carte';

  @override
  String publicProfileListedBooksCount(int count) {
    return 'Cărți listate ($count)';
  }

  @override
  String get publicProfileAcquisitionHistory =>
      'Istoric cărți primite prin aplicație';

  @override
  String get publicProfileNoAcquisitions =>
      'Niciun schimb sau cumpărare finalizată încă.';

  @override
  String publicProfileReviewsCount(int count) {
    return 'Recenzii ($count)';
  }

  @override
  String get leaderboardEmpty => 'Niciun oraș cu activitate încă.';

  @override
  String get leaderboardUnknownCity => 'Necunoscut';

  @override
  String leaderboardExchangesCount(int count) {
    return '$count schimburi';
  }

  @override
  String get leaderboardLoadError => 'Nu am putut încărca clasamentul.';

  @override
  String get leaderboardTabCity => 'Pe orașe';

  @override
  String get leaderboardTabNational => 'Național';

  @override
  String get leaderboardTabTopReaders => 'Cititori';

  @override
  String leaderboardPagesCount(int count) {
    return '$count pagini';
  }

  @override
  String get profileGlobalStats => 'Statistici globale';

  @override
  String get profileMyBookshelf => 'Raftul meu de cărți';

  @override
  String get bookshelfTitle => 'Raftul meu de cărți';

  @override
  String get bookshelfTabReading => 'Citesc';

  @override
  String get bookshelfTabWantToRead => 'Vreau să citesc';

  @override
  String get bookshelfTabFinished => 'Terminate';

  @override
  String get bookshelfTabShared => 'Împărtășite';

  @override
  String get bookshelfEmpty => 'Nicio carte aici încă.';

  @override
  String get bookshelfLoadError => 'Nu am putut încărca raftul.';

  @override
  String get bookshelfImportTooltip => 'Importă din Goodreads sau StoryGraph';

  @override
  String get bookshelfImportGoodreads => 'Importă din Goodreads (CSV)';

  @override
  String get bookshelfImportStoryGraph => 'Importă din StoryGraph (CSV)';

  @override
  String bookshelfImportSummary(int imported, int skipped) {
    return '$imported cărți importate, $skipped sărite';
  }

  @override
  String get bookshelfImportError =>
      'Nu am putut importa fișierul. Verifică dacă e un export CSV valid.';

  @override
  String get bookDetailShelfSectionTitle => 'Adaugă în raftul tău';

  @override
  String gamificationLevel(int level) {
    return 'Nivel $level';
  }

  @override
  String gamificationXp(int xp) {
    return '$xp XP';
  }

  @override
  String gamificationXpToNextLevel(int xp) {
    return '$xp XP până la nivelul următor';
  }

  @override
  String gamificationStreak(int days) {
    return '$days zile la rând';
  }

  @override
  String gamificationLongestStreak(int days) {
    return 'Record: $days zile';
  }

  @override
  String get profileMonthlyChallenges => 'Provocări lunare';

  @override
  String get monthlyChallengesTitle => 'Provocări lunare';

  @override
  String get profileReadingChallenge => 'Provocarea de citit';

  @override
  String readingChallengeTitle(int year) {
    return 'Provocarea de citit $year';
  }

  @override
  String get readingChallengeNoGoal =>
      'Nu ai setat încă un obiectiv pentru anul acesta.';

  @override
  String readingChallengeProgress(int progress, int goal) {
    return '$progress din $goal cărți terminate';
  }

  @override
  String get readingChallengeSetGoal => 'Setează un obiectiv';

  @override
  String get readingChallengeGoalLabel =>
      'Câte cărți vrei să termini anul acesta?';

  @override
  String get profileActivityFeed => 'Activitate recentă';

  @override
  String get activityFeedTitle => 'Activitate recentă';

  @override
  String get activityFeedEmpty =>
      'Niciun eveniment încă - urmărește alți useri ca să vezi ce citesc.';

  @override
  String get activityFeedLoadError => 'Nu am putut încărca activitatea.';

  @override
  String activityNewListing(String name) {
    return '$name a listat o carte nouă';
  }

  @override
  String activityFinishedBook(String name) {
    return '$name a terminat de citit';
  }

  @override
  String activityCompletedExchange(String name) {
    return '$name a finalizat un schimb';
  }

  @override
  String get bookDetailShelfRemove => 'Elimină din raft';

  @override
  String get publicProfileBookshelfTitle => 'Raftul de cărți';

  @override
  String get globalStatsTitle => 'Statistici globale';

  @override
  String get globalStatsTabMostShared => 'Cele mai schimbate';

  @override
  String get globalStatsTabTrending => 'În tendințe';

  @override
  String get globalStatsTabPopularAuthors => 'Autori populari';

  @override
  String get globalStatsEmpty => 'Nicio dată încă.';

  @override
  String get globalStatsLoadError => 'Nu am putut încărca statisticile.';

  @override
  String globalStatsTransferCount(int count) {
    return '$count schimburi/vânzări';
  }

  @override
  String globalStatsViewCount(int count) {
    return '$count vizualizări (14 zile)';
  }

  @override
  String get profileFavoriteSellers => 'Vânzători favoriți';

  @override
  String get favoriteSellersTitle => 'Vânzători favoriți';

  @override
  String get favoriteSellersEmpty => 'Nu urmărești încă niciun utilizator.';

  @override
  String get favoriteSellersLoadError => 'Nu am putut încărca lista.';

  @override
  String get publicProfileTopGenres => 'Genuri preferate';

  @override
  String get impactStatsTitle => 'Impact';

  @override
  String get impactStatsTotalValue => 'Valoare totală schimbată';

  @override
  String get impactStatsMoneySaved => 'Bani economisiți';

  @override
  String get impactStatsCo2Saved => 'CO₂ economisit (estimativ)';

  @override
  String impactStatsCo2Value(String kg) {
    return '$kg kg';
  }

  @override
  String homeGreeting(String name) {
    return 'Salut, $name!';
  }

  @override
  String get homeWelcome => 'Bine ai venit!';

  @override
  String get homeLoadError => 'Nu am putut încărca cărțile.';

  @override
  String get homeEmpty => 'Nu există încă cărți disponibile.';

  @override
  String get homeCategories => 'Categorii';

  @override
  String get homeRecentlyAdded => 'Adăugate recent';

  @override
  String get homeMostViewed => 'Cele mai vizualizate';

  @override
  String get homeMostSearched => 'Cele mai căutate';

  @override
  String get homeSeeAll => 'Vezi toate';

  @override
  String homePendingSwapBanner(int count) {
    return '$count cereri de schimb te așteaptă';
  }

  @override
  String get homePendingSwapReview => 'Revizuiește';

  @override
  String get homeOngoingExchangeBanner => 'Ai un schimb în desfășurare';

  @override
  String get homeFeedEnd => 'Ai văzut toate cărțile';

  @override
  String get homeNearYou => 'Din orașul tău';

  @override
  String get homeNearYouToday => 'Astăzi, aproape de tine';

  @override
  String get homeRecommendedForYou => 'Recomandate pentru tine';

  @override
  String get homeHiddenGems => 'Comori ascunse';

  @override
  String get homeCompleteYourCollection => 'Completează-ți colecția';

  @override
  String get homeSimilarTaste => 'Gusturi asemănătoare';

  @override
  String get profileSmartMatches => 'Potriviri de schimb';

  @override
  String get smartMatchesTitle => 'Potriviri de schimb';

  @override
  String get smartMatchesEmpty =>
      'Nicio potrivire încă - adaugă cărți pe wishlist și listează cărți disponibile.';

  @override
  String get smartMatchesLoadError => 'Nu am putut încărca potrivirile.';

  @override
  String get smartMatchesTheyHave => 'Are ce vrei tu';

  @override
  String get smartMatchesTheyWant => 'Vrea ce ai tu';

  @override
  String get homeUpcomingBooks => 'Cărți viitoare';

  @override
  String get homeActiveMembers => 'Membri activi';

  @override
  String get browseTitle => 'Caută cărți';

  @override
  String get browseMapTooltip => 'Hartă cărți din apropiere';

  @override
  String get browseSearchHint => 'Caută după titlu';

  @override
  String get browseEmpty => 'Nicio carte găsită.';

  @override
  String get filtersTitle => 'Filtre';

  @override
  String get filtersAuthor => 'Autor';

  @override
  String get filtersGenre => 'Gen';

  @override
  String get filtersLanguage => 'Limbă';

  @override
  String get filtersAnyCity => 'Orice oraș';

  @override
  String get filtersCondition => 'Stare';

  @override
  String get bookConditionNew => 'Nouă';

  @override
  String get bookConditionVeryGood => 'Foarte bună';

  @override
  String get bookConditionGood => 'Bună';

  @override
  String get bookConditionAcceptable => 'Acceptabilă';

  @override
  String get filtersAnyCondition => 'Orice stare';

  @override
  String get filtersListingType => 'Tip de anunț';

  @override
  String get filtersListingTypeSwap => 'Schimb';

  @override
  String get filtersListingTypeSale => 'Vânzare';

  @override
  String get filtersListingTypeAuction => 'Licitație';

  @override
  String get filtersNearbyOnly => 'Doar din apropiere';

  @override
  String get filtersNearbyOnlyHintOff =>
      'Ordonează și filtrează după distanța reală față de orașul tău';

  @override
  String filtersNearbyOnlyHintOn(int km) {
    return 'Până la $km km de orașul tău';
  }

  @override
  String filtersDistanceKm(int km) {
    return '$km km';
  }

  @override
  String get filtersReset => 'Resetează';

  @override
  String get filtersApply => 'Aplică filtre';

  @override
  String get commonYes => 'Da';

  @override
  String get commonNo => 'Nu';

  @override
  String get commonGiveUp => 'Renunță';

  @override
  String get libraryTitle => 'Raftul meu';

  @override
  String get libraryViewAsList => 'Vezi ca listă';

  @override
  String get libraryViewAsGrid => 'Vezi ca grilă';

  @override
  String get libraryExportCsv => 'Exportă în CSV';

  @override
  String get libraryBulkAdd => 'Adaugă mai multe cărți (scanare)';

  @override
  String get libraryImportCsv => 'Importă anunțuri din CSV';

  @override
  String libraryImportSummary(int created, int failed) {
    return '$created anunțuri create, $failed eșuate';
  }

  @override
  String get libraryImportError =>
      'Nu am putut importa fișierul. Verifică dacă e un CSV valid.';

  @override
  String get libraryEmpty => 'Nu ai nicio carte în bibliotecă încă.';

  @override
  String get libraryLoadError => 'Nu am putut încărca biblioteca.';

  @override
  String get libraryAvailable => 'Disponibilă';

  @override
  String get libraryUnavailable => 'Indisponibilă';

  @override
  String libraryShelfSubtitle(int total, int available) {
    return '$total cărți · $available disponibile la schimb';
  }

  @override
  String libraryFilterAll(int count) {
    return 'Toate $count';
  }

  @override
  String libraryFilterAvailable(int count) {
    return 'Disponibile $count';
  }

  @override
  String libraryFilterUnavailable(int count) {
    return 'Indisponibile $count';
  }

  @override
  String libraryFilterTransferred(int count) {
    return 'Transferate $count';
  }

  @override
  String get libraryOverviewTitle => 'Rezumatul raftului';

  @override
  String get libraryOverviewTotal => 'Total';

  @override
  String get libraryDeleteConfirmTitle => 'Ștergi cartea?';

  @override
  String libraryDeleteConfirmBody(String title) {
    return '„$title\" va fi eliminată din bibliotecă.';
  }

  @override
  String get libraryAvailableForSwap => 'Disponibilă pentru schimb';

  @override
  String get libraryDeleteBook => 'Șterge cartea';

  @override
  String get libraryEditListing => 'Editează anunțul';

  @override
  String get libraryEditListingTitle => 'Editează anunțul';

  @override
  String get libraryEditListingSuccess => 'Anunțul a fost actualizat.';

  @override
  String get csvHeaderTitle => 'Titlu';

  @override
  String get csvHeaderAvailableForSwap => 'Disponibilă la schimb';

  @override
  String get csvHeaderForSale => 'De vânzare';

  @override
  String get csvHeaderPrice => 'Preț';

  @override
  String get addBookTitle => 'Adaugă o carte';

  @override
  String get addBookSearchHint => 'Titlu sau ISBN';

  @override
  String get addBookSearchButton => 'Caută';

  @override
  String get addBookSearchFailed => 'Căutarea a eșuat. Încearcă din nou.';

  @override
  String get addBookSearchPrompt => 'Caută o carte după titlu sau ISBN.';

  @override
  String get addBookManualEntry => 'Adaugă manual';

  @override
  String get addBookNotFoundManual => 'Nu găsești cartea? Adaugă manual';

  @override
  String get addBookChange => 'Schimbă';

  @override
  String get addBookTitleLabel => 'Titlu';

  @override
  String get addBookSearchInstead => 'Caută în schimb';

  @override
  String get addBookLanguageOptional => 'Limbă (opțional)';

  @override
  String get addBookEditionOptional => 'Ediție (opțional)';

  @override
  String get addBookHardcoverSwitch => 'Ediție cartonată';

  @override
  String get addBookForSaleSwitch => 'De vânzare';

  @override
  String get addBookForSaleHint =>
      'Pe lângă schimb, poți vinde cartea la un preț fix';

  @override
  String get addBookPriceLabel => 'Preț (lei)';

  @override
  String get addBookNonNegotiable => 'Preț fix, nenegociabil';

  @override
  String get addBookNonNegotiableHint =>
      'Cumpărătorii nu vor putea face oferte de preț';

  @override
  String get addBookAuctionSwitch => 'Pornește o licitație';

  @override
  String get addBookAuctionHint =>
      'Cumpărătorii vor licita, câștigă oferta cea mai mare la final';

  @override
  String get addBookAuctionStartingPrice => 'Preț de pornire';

  @override
  String get addBookAuctionReservePrice => 'Preț de rezervă (opțional)';

  @override
  String get addBookAuctionReservePriceHint =>
      'Prețul minim sub care nu vinzi cartea';

  @override
  String get addBookAuctionBuyNowPrice => 'Preț \"Cumpără acum\" (opțional)';

  @override
  String get addBookAuctionBuyNowPriceHint =>
      'Disponibil doar înainte de prima ofertă';

  @override
  String get addBookAuctionDuration => 'Durata licitației';

  @override
  String get addBookAuctionDuration24h => '24 ore';

  @override
  String get addBookAuctionDuration3d => '3 zile';

  @override
  String get addBookAuctionDuration7d => '7 zile';

  @override
  String get addBookPhotosLabelRequired =>
      'Poze cu cartea (obligatoriu, cel puțin 1)';

  @override
  String get addBookPhotosLabelOptional => 'Poze cu cartea (opțional)';

  @override
  String get addBookSubmit => 'Adaugă în bibliotecă';

  @override
  String get addBookTitleRequired => 'Titlul este obligatoriu';

  @override
  String get addBookInvalidPrice => 'Introdu un preț valid';

  @override
  String get addBookNeedPhoto =>
      'Adaugă cel puțin o poză cu cartea înainte de a o pune la vânzare';

  @override
  String get addBookSuccess => 'Carte adăugată în bibliotecă';

  @override
  String get addBookGenericError =>
      'Nu am putut adăuga cartea. Încearcă din nou.';

  @override
  String get relistNeedPhoto =>
      'Adaugă cel puțin o poză înainte de a o pune la vânzare';

  @override
  String get relistSuccess => 'Cartea a fost adăugată în biblioteca ta';

  @override
  String get relistGenericError => 'Nu am putut adăuga cartea.';

  @override
  String relistHeading(String title) {
    return 'Adaugă „$title\" în biblioteca ta';
  }

  @override
  String get relistSubtitle =>
      'Descrie starea în care ai primit-o - rămâne legată de istoricul cărții.';

  @override
  String get mapTitle => 'Cărți din apropiere';

  @override
  String get mapLoadError => 'Nu am putut încărca harta.';

  @override
  String get mapEmpty => 'Nicio carte disponibilă momentan în vreun oraș.';

  @override
  String mapCityBooksCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count cărți',
      one: '$count carte',
    );
    return '$_temp0';
  }

  @override
  String get bookDetailTitle => 'Detalii carte';

  @override
  String get bookDetailReportTooltip => 'Raportează anunțul';

  @override
  String bookDetailReportedFrom(String title) {
    return 'Raportat de pe anunțul \"$title\"';
  }

  @override
  String get bookDetailReportSent => 'Raport trimis. Mulțumim!';

  @override
  String get bookDetailWishlistError =>
      'Nu am putut actualiza lista de dorințe';

  @override
  String get bookDetailReportError => 'Nu am putut trimite raportul';

  @override
  String get bookDetailLoadError => 'Nu am putut încărca cartea.';

  @override
  String get bookDetailViewsTitle => 'Vizualizări';

  @override
  String get bookDetailViewsLoadError => 'Nu am putut încărca vizualizările.';

  @override
  String bookDetailUniqueViews(int count) {
    return '$count vizualizări unice';
  }

  @override
  String bookDetailTotalViews(int count) {
    return '$count vizualizări în total, inclusiv reîncărcări de pagină';
  }

  @override
  String get bookDetailHardcoverChip => 'Cartonată';

  @override
  String get bookDetailAvailableChip => 'Disponibilă la schimb';

  @override
  String bookDetailViewCount(int count) {
    return '$count vizualizări';
  }

  @override
  String get bookDetailDescriptionTitle => 'Descriere';

  @override
  String get bookDetailSellerNoteTitle => 'Notă de la proprietar';

  @override
  String get bookDetailAboutButton => 'Despre carte';

  @override
  String get bookDetailDetailsTitle => 'Detalii';

  @override
  String get bookDetailPublisherLabel => 'Editură';

  @override
  String get bookDetailYearLabel => 'An apariție';

  @override
  String get bookDetailPagesLabel => 'Pagini';

  @override
  String get bookDetailOwnerTitle => 'Proprietar';

  @override
  String get bookDetailPhotosTitle => 'Poze';

  @override
  String get bookDetailRequestExchange => 'Cere la schimb';

  @override
  String get bookDetailUnavailableForExchange => 'Indisponibilă la schimb';

  @override
  String get bookDetailRequestDonation => 'Solicită donația';

  @override
  String get bookDetailMakeOffer => 'Fă o ofertă';

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
  String get bookDetailHistoryTitle => 'Istoricul acestei cărți';

  @override
  String get bookDetailHistorySubtitle =>
      'Cum a circulat cartea prin aplicație, cu poze puse de fiecare proprietar.';

  @override
  String get bookDetailHistorySold => 'vândută';

  @override
  String get bookDetailHistoryExchanged => 'dată la schimb';

  @override
  String bookDetailHistoryListedOn(String date) {
    return 'listată pe $date';
  }

  @override
  String bookDetailHistoryTransferredOn(String action, String date) {
    return ' · $action pe $date';
  }

  @override
  String get bookDetailHistoryCurrentlyOwned => ' · deținută în prezent';

  @override
  String get bookDetailSimilarBooksTitle => 'Cărți similare';

  @override
  String bookDetailLibraryPriceLabel(String price) {
    return 'Preț în librării: $price';
  }

  @override
  String bookDetailRequestedTitle(String title) {
    return 'Cere „$title\" la schimb';
  }

  @override
  String get bookDetailNoBooksToOffer =>
      'Nu ai cărți disponibile de oferit - poți trimite cererea și fără.';

  @override
  String get bookDetailOfferOneOfYourBooks =>
      'Oferă una din cărțile tale (opțional)';

  @override
  String get bookDetailNoOffer => 'Fără ofertă';

  @override
  String get bookDetailMessageOptional => 'Mesaj (opțional)';

  @override
  String get bookDetailSendRequest => 'Trimite cererea';

  @override
  String get bookDetailRequestSent => 'Cerere de schimb trimisă';

  @override
  String get bookDetailRequestError => 'Nu am putut trimite cererea.';

  @override
  String get bookDetailFirstExchangeTitle => 'Primul tău schimb';

  @override
  String get bookDetailFirstExchangeBody =>
      'Câteva sfaturi înainte de primul schimb: întâlnește-te ziua, într-un loc public, și verifică starea cărții înainte să confirmi schimbul ca finalizat.';

  @override
  String get bookDetailUnderstood => 'Am înțeles, continuă';

  @override
  String bookDetailMakeOfferTitle(String title) {
    return 'Fă o ofertă pentru „$title\"';
  }

  @override
  String bookDetailAskingPrice(String price) {
    return 'Preț cerut: $price';
  }

  @override
  String get bookDetailOfferAmountLabel => 'Suma oferită';

  @override
  String get bookDetailSendOffer => 'Trimite oferta';

  @override
  String get bookDetailOfferSent => 'Ofertă trimisă';

  @override
  String get bookDetailOfferError => 'Nu am putut trimite oferta.';

  @override
  String get bookDetailInvalidAmount => 'Introdu o sumă validă';

  @override
  String get commonAddToLibrary => 'Adaugă în biblioteca ta';

  @override
  String get commonAnonymousUser => 'un utilizator';

  @override
  String get exchangesTitle => 'Schimburile mele';

  @override
  String get exchangesTabReceived => 'Schimburi primite';

  @override
  String get exchangesTabSent => 'Schimburi trimise';

  @override
  String get offersTabReceived => 'Oferte primite';

  @override
  String get offersTabSent => 'Oferte trimise';

  @override
  String get exchangesEmptyReceived => 'Nu ai primit nicio cerere de schimb.';

  @override
  String get exchangesEmptySent => 'Nu ai trimis nicio cerere de schimb.';

  @override
  String get exchangesLoadError => 'Nu am putut încărca schimburile.';

  @override
  String exchangeRequestedBy(String name) {
    return 'Cerută de $name';
  }

  @override
  String exchangeFrom(String name) {
    return 'De la $name';
  }

  @override
  String exchangeOffersBook(String title) {
    return 'Oferă: $title';
  }

  @override
  String exchangeOffersAmount(String amount) {
    return 'Oferă: $amount RON';
  }

  @override
  String get exchangeReject => 'Refuză';

  @override
  String get exchangeAccept => 'Acceptă';

  @override
  String get exchangeCancelRequest => 'Anulează cererea';

  @override
  String get exchangeScheduleMeeting => 'Programează întâlnirea';

  @override
  String get exchangeReschedule => 'Reprogramează';

  @override
  String get exchangeAddToCalendar => 'Adaugă în calendar';

  @override
  String get exchangeQrCode => 'Cod QR';

  @override
  String get exchangeMarkComplete => 'Marchează finalizat';

  @override
  String get exchangeRated => 'Evaluat';

  @override
  String get exchangeRate => 'Evaluează';

  @override
  String get exchangeCalendarError => 'Nu am putut deschide calendarul.';

  @override
  String get exchangeRatingDialogTitle => 'Cum a fost schimbul?';

  @override
  String get exchangeRatingOverall => 'Per ansamblu';

  @override
  String get exchangeRatingCommunication => 'Comunicare';

  @override
  String get exchangeRatingPunctuality => 'Punctualitate';

  @override
  String get exchangeRatingCondition => 'Starea cărții primite';

  @override
  String get exchangeReviewOptional => 'Recenzie (opțional)';

  @override
  String get exchangeQrDialogTitle => 'Cod QR de confirmare';

  @override
  String get exchangeQrDialogBody =>
      'Celălalt participant scanează acest cod la întâlnire ca să confirme schimbul.';

  @override
  String get exchangeMeetingSheetTitle => 'Programează întâlnirea';

  @override
  String get exchangePickDateTime => 'Alege data și ora';

  @override
  String get exchangeLocationLabel => 'Locație';

  @override
  String get exchangeMeetingSaveError => 'Nu am putut salva întâlnirea.';

  @override
  String get exchangeGoToReady => 'Continuă schimbul';

  @override
  String get readyTitle => 'Pregătire schimb';

  @override
  String get readyMeetingAwaitingYou => 'Cealaltă parte a propus o întâlnire';

  @override
  String get readyMeetingProposedByMe => 'Aștepți confirmarea celeilalte părți';

  @override
  String get readyMeetingAccept => 'Confirmă';

  @override
  String get readyMeetingDecline => 'Refuză';

  @override
  String get readyMeetingSubtitle => 'Stabiliți când și unde faceți schimbul';

  @override
  String get readySafetySubtitle => 'Sfaturi pentru un schimb sigur';

  @override
  String get readyContactSubtitle =>
      'Spune-i partenerului de schimb cum să te contacteze';

  @override
  String get readyContactTitle => 'Detalii de contact';

  @override
  String get readyContactPhoneLabel => 'Telefon (opțional)';

  @override
  String get readyContactShare => 'Trimite numărul de telefon';

  @override
  String get readyContactSkip => 'Mai bine nu';

  @override
  String get readyContactEdit => 'Editează';

  @override
  String get readyContactShared => 'Ți-ai trimis detaliile de contact';

  @override
  String get dealFinalisedBanner => 'DEAL FINALISED';

  @override
  String get dealCancelledBanner => 'DEAL CANCELLED';

  @override
  String get dealCancelledByYouBanner => 'ANULAT DE TINE';

  @override
  String dealCancelledByOtherBanner(String name) {
    return 'ANULAT DE $name';
  }

  @override
  String readyContactOtherPhone(String phone) {
    return 'Telefon: $phone';
  }

  @override
  String get readyContactSharedNoPhone =>
      'Cealaltă parte și-a trimis detaliile, fără număr de telefon.';

  @override
  String readyContactCall(String name) {
    return 'Sună pe $name';
  }

  @override
  String get readyContactMessageInApp => 'Mesaj în aplicație';

  @override
  String get readySafetyTitle => 'Recomandări de siguranță';

  @override
  String get readySafetyViewLink => 'Vezi recomandările de siguranță';

  @override
  String get readySafetyAck => 'Am citit';

  @override
  String get readySafetyWaitingOther =>
      'Aștepți ca cealaltă parte să confirme că a citit recomandările.';

  @override
  String get readySafetyBothReady => 'Sunteți gata de schimb';

  @override
  String get readyReportIssue => 'Raportează o problemă';

  @override
  String get readyCancel => 'Anulează';

  @override
  String get readyPostpone => 'Amână';

  @override
  String get readyDone => 'Gata';

  @override
  String get readyConfirmDone => 'Confirmă finalizarea';

  @override
  String get readyDisputeDone => 'Nu e finalizat';

  @override
  String get readyWaitingConfirmation => 'Aștepți confirmarea celeilalte părți';

  @override
  String get readyOtherMarkedDone =>
      'Cealaltă parte a marcat schimbul ca finalizat. Confirmi?';

  @override
  String get doneReviewTitle => 'Cum a fost schimbul?';

  @override
  String get doneReviewLabel => 'Câteva cuvinte (opțional)';

  @override
  String get doneReviewSubmit => 'Trimite';

  @override
  String get cancelReasonTitle => 'Ce s-a întâmplat?';

  @override
  String get cancelReasonNoShow => 'Cealaltă persoană nu s-a prezentat';

  @override
  String get cancelReasonBookMismatch => 'Cartea nu a corespuns așteptărilor';

  @override
  String get cancelReasonChangedMind => 'M-am răzgândit';

  @override
  String get cancelReasonOther => 'Altceva';

  @override
  String get cancelReasonDetailsLabel => 'Detalii (opțional)';

  @override
  String get cancelReasonSubmit => 'Anulează schimbul';

  @override
  String get offersEmptyReceived => 'Nu ai primit nicio ofertă de preț.';

  @override
  String get offersEmptySent => 'Nu ai trimis nicio ofertă de preț.';

  @override
  String get offersLoadError => 'Nu am putut încărca ofertele.';

  @override
  String offerTo(String name) {
    return 'Către $name';
  }

  @override
  String offerAmountLine(String amount) {
    return 'Ofertă: $amount';
  }

  @override
  String get offerCancel => 'Anulează oferta';

  @override
  String get exchangeConfirmTitle => 'Confirmă schimbul';

  @override
  String get exchangeConfirmError => 'Nu am putut confirma schimbul.';

  @override
  String get exchangeConfirmDone => 'Schimb marcat ca finalizat!';

  @override
  String get exchangeConfirmQuestion =>
      'Confirmi că schimbul de cărți s-a finalizat?';

  @override
  String get exchangeConfirmButton => 'Confirmă finalizarea';

  @override
  String get chatEmptyConversations => 'Nu ai nicio conversație încă.';

  @override
  String get chatStartConversation => 'Începe conversația';

  @override
  String get chatPhotoPreview => '📷 Poză';

  @override
  String get chatLocationPreview => '📍 Locație';

  @override
  String get chatLoadError => 'Nu am putut încărca conversațiile.';

  @override
  String get chatConversationFallbackTitle => 'Conversație';

  @override
  String get chatUnblock => 'Deblochează';

  @override
  String get chatBlock => 'Blochează';

  @override
  String get chatUserUnblocked => 'Utilizator deblocat';

  @override
  String get chatUserBlocked => 'Utilizator blocat';

  @override
  String get chatBlockUpdateError => 'Nu am putut actualiza blocarea';

  @override
  String get chatTyping => 'scrie...';

  @override
  String get chatSendFailed =>
      'Mesajul nu a putut fi trimis. Verifică conexiunea.';

  @override
  String get chatOnline => 'online';

  @override
  String get chatOffline => 'offline';

  @override
  String get chatLastSeenJustNow => 'văzut adineauri';

  @override
  String chatLastSeenMinutes(int minutes) {
    return 'văzut acum $minutes min';
  }

  @override
  String chatLastSeenHours(int hours) {
    return 'văzut acum $hours h';
  }

  @override
  String chatLastSeenDays(int days) {
    return 'văzut acum $days z';
  }

  @override
  String get chatSeen => 'Văzut';

  @override
  String get chatSent => 'Trimis';

  @override
  String get chatReply => 'Răspunde';

  @override
  String get chatCopyMessage => 'Copiază mesajul';

  @override
  String get chatMessageCopied => 'Mesaj copiat';

  @override
  String get chatReplyToYou => 'Tu';

  @override
  String get chatReplyToThem => 'Mesaj citat';

  @override
  String get chatAttachPhoto => 'Trimite o poză';

  @override
  String get chatPhotoSendError => 'Nu am putut trimite poza.';

  @override
  String get chatSearchInConversation => 'Caută în conversație';

  @override
  String get chatSearchNoResults => 'Niciun mesaj găsit.';

  @override
  String get chatArchive => 'Arhivează';

  @override
  String get chatUnarchive => 'Dezarhivează';

  @override
  String get chatArchived => 'Conversație arhivată';

  @override
  String get chatArchivedTitle => 'Arhivate';

  @override
  String get chatEmptyArchived => 'Nu ai nicio conversație arhivată.';

  @override
  String get chatDeleteTitle => 'Șterge chatul';

  @override
  String get chatDeleteConfirm =>
      'Conversația dispare doar pentru tine. Celălalt utilizator își păstrează mesajele.';

  @override
  String get chatActionError => 'Nu am putut face asta. Încearcă din nou.';

  @override
  String get chatReportConversation => 'Raportează conversația';

  @override
  String get chatConversationReported =>
      'Conversația a fost raportată. Echipa o va analiza.';

  @override
  String get chatBlockedNotice =>
      'Nu poți trimite mesaje acestui utilizator - conversația este blocată.';

  @override
  String get chatShareLocationTooltip => 'Trimite locația întâlnirii';

  @override
  String get chatMessageHint => 'Scrie un mesaj...';

  @override
  String get chatSafetyBannerBody =>
      'Nu trimite bani în avans și întâlnește-te într-un loc public pentru schimb. Dacă ceva pare suspect, raportează sau blochează utilizatorul din meniul de sus.';

  @override
  String get chatSafetyBannerLearnMore => 'Află mai multe';

  @override
  String get chatEmptyMessages => 'Niciun mesaj încă. Spune salut!';

  @override
  String get chatMapLabel => 'Hartă';

  @override
  String get chatCalendarLabel => 'Calendar';

  @override
  String chatMeetingAt(String date, String time) {
    return '$date, ora $time';
  }

  @override
  String get chatSafetyAdvisorLabel => 'Safety advisor';

  @override
  String get chatSafetyAdvisorBody =>
      'Asigură-te că respecți regulile de siguranță la întâlnire.';

  @override
  String get chatOfferActionError =>
      'Nu am putut actualiza oferta. Încearcă din nou.';

  @override
  String get chatOfferCardTitle => 'Oferta de preț';

  @override
  String chatOfferCardFrom(String bookTitle) {
    return 'de la $bookTitle';
  }

  @override
  String get chatExchangeCardTitle => 'Cerere de schimb';

  @override
  String get readyYouGive => 'Dai';

  @override
  String get readyYouReceive => 'Primești';

  @override
  String readyFromCity(String city) {
    return 'din $city';
  }

  @override
  String chatOfferCardLabel(String amount, String bookTitle) {
    return '$amount lei · $bookTitle';
  }

  @override
  String chatExchangeCardLabel(String offeredTitle, String requestedTitle) {
    return 'Schimb: $offeredTitle pentru $requestedTitle';
  }

  @override
  String chatExchangeCardLabelNoOffer(String requestedTitle) {
    return 'Cerere de schimb: $requestedTitle';
  }

  @override
  String get chatSearchPlaceHint =>
      'Caută o adresă sau un loc (ex: Cafeneaua X, Cluj)';

  @override
  String get chatNoResults => 'Niciun rezultat.';

  @override
  String get chatSuggestedMeetingPoints => 'Sugestii de întâlnire în apropiere';

  @override
  String get chatPickDate => 'Alege data';

  @override
  String get chatPickTime => 'Alege ora';

  @override
  String get wishlistTitle => 'Lista de dorințe';

  @override
  String wishlistCount(int count) {
    return '$count cărți';
  }

  @override
  String get wishlistEmpty =>
      'Nu ai adăugat încă nicio carte în lista de dorințe.';

  @override
  String get wishlistLoadError => 'Nu am putut încărca lista de dorințe.';

  @override
  String wishlistSectionPersonal(int count) {
    return 'Alegerile mele ($count)';
  }

  @override
  String wishlistSectionBookMatch(int count) {
    return 'Book Match ($count)';
  }

  @override
  String get notificationsTitle => 'Notificări';

  @override
  String get notificationsMarkAllRead => 'Marchează tot ca citit';

  @override
  String get notificationsEmpty => 'Nu ai nicio notificare.';

  @override
  String get notificationsFilterAll => 'Toate';

  @override
  String get notificationsFilterUnread => 'Necitite';

  @override
  String get notificationsFilterExchanges => 'Schimburi';

  @override
  String get notificationsFilterMessages => 'Mesaje';

  @override
  String get notificationsToday => 'Astăzi';

  @override
  String get notificationsYesterday => 'Ieri';

  @override
  String get notificationsEarlier => 'Mai vechi';

  @override
  String get notificationsToastNewMessage => 'Ai un mesaj nou';

  @override
  String get notificationsToastNewReply => 'Ai un răspuns nou';

  @override
  String get notificationsToastMultiple => 'Ai mai multe notificări';

  @override
  String get notificationsToastGeneric => 'Ai o notificare nouă';

  @override
  String notificationsRepeatedCount(int count) {
    return '×$count';
  }

  @override
  String notificationsUnreadCount(int count) {
    return '$count necitite';
  }

  @override
  String get notificationsLoadError => 'Nu am putut încărca notificările.';

  @override
  String get timeJustNow => 'acum';

  @override
  String timeMinutesAgo(int minutes) {
    return 'acum $minutes min';
  }

  @override
  String timeHoursAgo(int hours) {
    return 'acum $hours h';
  }

  @override
  String timeDaysAgo(int days) {
    return 'acum $days zile';
  }

  @override
  String get adminLoadError => 'Nu am putut încărca datele de admin.';

  @override
  String get adminStatsTitle => 'Statistici';

  @override
  String get adminMarketplaceStatsTitle => 'Statistici marketplace';

  @override
  String get adminMarketplaceGmv => 'Volum total tranzacționat';

  @override
  String get adminMarketplaceCompletedSales => 'Vânzări finalizate';

  @override
  String get adminMarketplaceCompletedAuctions => 'Licitații finalizate';

  @override
  String get adminMarketplaceAvgPrice => 'Preț mediu vânzare';

  @override
  String get adminMarketplaceTopGenres => 'Top genuri (anunțuri active)';

  @override
  String get adminActiveZonesTitle => 'Zone active';

  @override
  String get adminActiveZonesDesc => 'Densitatea anunțurilor active pe oraș';

  @override
  String get adminActiveZonesEmpty => 'Niciun anunț activ încă.';

  @override
  String adminUsersCount(int count) {
    return 'Utilizatori ($count)';
  }

  @override
  String adminInactiveListingsCount(int count) {
    return 'Anunțuri fără nicio cerere ($count)';
  }

  @override
  String get adminInactiveListingsDesc =>
      'Cărți puse la schimb pentru care nimeni nu a trimis nicio cerere.';

  @override
  String get adminNoInactiveListings => 'Niciun anunț inactiv.';

  @override
  String adminUserReportsCount(int count) {
    return 'Rapoarte utilizatori ($count)';
  }

  @override
  String get adminNoReports => 'Niciun raport.';

  @override
  String adminUpcomingReleasesCount(int count) {
    return 'Cărți viitoare ($count)';
  }

  @override
  String get adminUpcomingReleasesDesc =>
      'Afișate pe ecranul principal, în secțiunea \"Cărți viitoare\".';

  @override
  String get adminNoUpcomingReleases => 'Nicio carte viitoare adăugată.';

  @override
  String adminFeedbackCount(int count) {
    return 'Feedback primit ($count)';
  }

  @override
  String get adminNoFeedback => 'Niciun feedback trimis încă.';

  @override
  String adminSupportRequestsCount(int count) {
    return 'Mesaje de support ($count)';
  }

  @override
  String get adminNoSupportRequests => 'Niciun mesaj de support trimis încă.';

  @override
  String adminReportedBy(String name) {
    return 'Raportat de $name';
  }

  @override
  String get adminUnknownAuthor => 'Autor necunoscut';

  @override
  String get adminAuthorOptional => 'Autor (opțional)';

  @override
  String get adminCoverUrlOptional => 'URL copertă (opțional)';

  @override
  String get adminPickReleaseDate => 'Alege data lansării';

  @override
  String adminReleaseDateLabel(String date) {
    return 'Lansare: $date';
  }

  @override
  String get adminAdd => 'Adaugă';

  @override
  String get adminTitleDateRequired =>
      'Titlul și data lansării sunt obligatorii';

  @override
  String get adminAddBookError => 'Nu am putut adăuga cartea';

  @override
  String get adminDeleteUserTitle => 'Șterge utilizatorul?';

  @override
  String adminDeleteUserBody(String name) {
    return 'Se șterg definitiv contul lui $name și toate datele asociate (cărți, schimburi, mesaje). Nu se poate anula.';
  }

  @override
  String get adminStatsUsersLabel => 'Utilizatori';

  @override
  String adminStatsUsersSubtitle(int count) {
    return 'din care $count verificați';
  }

  @override
  String get adminStatsBooksLabel => 'Cărți în catalog';

  @override
  String adminStatsBooksSubtitle(int count) {
    return '$count exemplare listate';
  }

  @override
  String get adminStatsExchangesLabel => 'Schimburi';

  @override
  String adminStatsExchangesSubtitle(int completed, int pending) {
    return '$completed finalizate · $pending în așteptare';
  }

  @override
  String get auctionTitle => 'Licitație';

  @override
  String get auctionCurrentPrice => 'Preț curent';

  @override
  String get auctionBidsCount => 'oferte';

  @override
  String get auctionReserveMet => 'Prețul de rezervă a fost atins';

  @override
  String get auctionReserveNotMet => 'Prețul de rezervă nu a fost încă atins';

  @override
  String get auctionEndedWithWinner =>
      'Licitația s-a încheiat - a câștigat cineva';

  @override
  String get auctionEndedNoWinner => 'Licitația s-a încheiat fără câștigător';

  @override
  String auctionBidAmountLabel(String amount) {
    return 'Ofertă (minim $amount lei)';
  }

  @override
  String get auctionPlaceBid => 'Licitează';

  @override
  String auctionBuyNowFor(String amount) {
    return 'Cumpără acum cu $amount lei';
  }

  @override
  String get auctionBidHistory => 'Istoricul ofertelor';

  @override
  String get auctionNoBidsYet => 'Nicio ofertă încă';

  @override
  String get auctionWatch => 'Urmărește licitația';

  @override
  String get auctionBidPlaced => 'Ofertă plasată';

  @override
  String get auctionBoughtNow => 'Cumpărat cu succes';

  @override
  String get auctionGenericError => 'A apărut o eroare, încearcă din nou';

  @override
  String get auctionEnded => 'Încheiată';

  @override
  String auctionEndsInDays(int days) {
    return 'se încheie în $days zile';
  }

  @override
  String auctionEndsInHours(int hours) {
    return 'se încheie în $hours h';
  }

  @override
  String auctionEndsInMinutes(int minutes) {
    return 'se încheie în $minutes min';
  }

  @override
  String get bulkAddTitle => 'Adaugă mai multe cărți';

  @override
  String get bulkAddScanTooltip => 'Scanează cod de bare';

  @override
  String get bulkAddManualEntry => 'Introducere manuală';

  @override
  String get bulkAddManualHint =>
      'Lipește mai multe ISBN-uri, câte unul pe linie (sau separate prin virgulă)';

  @override
  String get bulkAddManualPlaceholder => '9780439023481\n9780441172719';

  @override
  String get bulkAddAddIsbns => 'Adaugă în listă';

  @override
  String get bulkAddQueueEmpty =>
      'Nicio carte adăugată încă - scanează sau introdu un ISBN.';

  @override
  String bulkAddSubmit(int count) {
    return 'Adaugă $count cărți';
  }

  @override
  String bulkAddResultSummary(int created, int failed) {
    return '$created cărți adăugate, $failed eșuate';
  }

  @override
  String inventorySelectedCount(int count) {
    return '$count selectate';
  }

  @override
  String get inventoryMarkUnavailable => 'Marchează indisponibile';

  @override
  String get inventoryChangePriceTitle => 'Schimbă prețul';

  @override
  String inventoryPriceChangedCount(int count) {
    return 'Preț schimbat la $count anunțuri';
  }

  @override
  String get inventoryDeleteConfirmTitle => 'Ștergi anunțurile selectate?';

  @override
  String inventoryDeleteConfirmBody(int count) {
    return 'Se șterg definitiv $count anunțuri. Nu se poate anula.';
  }

  @override
  String get inventoryBulkDone => 'Acțiune aplicată';

  @override
  String get collectionsTitle => 'Colecții';

  @override
  String get collectionsEmpty => 'Nicio colecție încă.';

  @override
  String get collectionsLoadError => 'Nu am putut încărca colecțiile.';

  @override
  String get collectionsCreateTitle => 'Colecție nouă';

  @override
  String get collectionsNameLabel => 'Nume';

  @override
  String get collectionsPublicSwitch => 'Publică';

  @override
  String collectionsBookCount(int count) {
    return '$count cărți';
  }

  @override
  String get collectionsEmptyItems => 'Nicio carte în această colecție încă.';

  @override
  String get collectionsDeleteConfirmTitle => 'Ștergi această colecție?';

  @override
  String get collectionsAddToTitle => 'Adaugă în colecție';

  @override
  String get collectionsNewInline => 'Colecție nouă...';

  @override
  String get groupsTitle => 'Grupuri';

  @override
  String get groupsTabDiscover => 'Descoperă';

  @override
  String get groupsTabMine => 'Ale mele';

  @override
  String get groupsEmpty => 'Niciun grup încă.';

  @override
  String get groupsLoadError => 'Nu am putut încărca grupul.';

  @override
  String get groupsCreateTitle => 'Grup nou';

  @override
  String get groupsNameLabel => 'Nume';

  @override
  String get groupsDescriptionLabel => 'Descriere (opțional)';

  @override
  String groupsMemberCount(int count) {
    return '$count membri';
  }

  @override
  String get groupsJoin => 'Alătură-te';

  @override
  String get groupsLeave => 'Părăsește grupul';

  @override
  String get groupsDeleteConfirmTitle => 'Ștergi acest grup?';

  @override
  String get groupsEventsTitle => 'Evenimente';

  @override
  String get groupsNoEvents => 'Niciun eveniment programat.';

  @override
  String get groupsAddEventTitle => 'Adaugă eveniment';

  @override
  String get groupsEventTitleLabel => 'Titlu';

  @override
  String get groupsEventLocationLabel => 'Locație (opțional)';

  @override
  String get groupsDiscussionTitle => 'Discuții';

  @override
  String get groupsPostHint => 'Scrie un mesaj...';

  @override
  String get groupsNoPosts => 'Niciun mesaj încă.';

  @override
  String get premiumBadgeTooltip => 'Membru Premium';

  @override
  String get adminGrantPremium => 'Acordă Premium';

  @override
  String get adminRemovePremium => 'Elimină Premium';

  @override
  String get premiumPromoteListing => 'Promovează anunțul';

  @override
  String get premiumUnpromoteListing => 'Anulează promovarea';

  @override
  String get premiumAnalyticsTitle => 'Statistici avansate';

  @override
  String get premiumAnalyticsTotalListings => 'Anunțuri active';

  @override
  String get premiumAnalyticsTotalViews => 'Vizualizări totale';

  @override
  String get premiumAnalyticsOffersReceived => 'Oferte primite';

  @override
  String get premiumAnalyticsConversionRate => 'Rată de conversie';

  @override
  String get premiumAnalyticsRevenue => 'Venit total';

  @override
  String get premiumAnalyticsTopListings => 'Cele mai vizualizate anunțuri';

  @override
  String get premiumAnalyticsLocked =>
      'Statisticile avansate sunt o funcție Premium.';

  @override
  String get premiumAnalyticsLoadError => 'Nu am putut încărca statisticile.';

  @override
  String get discoverMostWishedFor => 'Cele mai dorite';

  @override
  String get discoverMostLookedFor => 'Cele mai căutate';

  @override
  String get discoverSearchTooltip => 'Caută cărți';

  @override
  String get discoverTopSearches => 'Top căutări';

  @override
  String get discoverAuctions => 'Licitații active';

  @override
  String get discoverHiddenGems => 'Comori ascunse';

  @override
  String get discoverSwapOnly => 'Doar la schimb';

  @override
  String discoverMoreGenres(int count) {
    return '+ $count altele';
  }

  @override
  String get discoverUnder30 => 'Sub 30 lei';

  @override
  String get discoverRecommendedForYou => 'Recomandate pentru tine';

  @override
  String get discoverPopularAuthors => 'Autori populari';

  @override
  String get discoverQuickFilters => 'Filtre rapide';

  @override
  String get discoverNearYou => 'În orașul tău';

  @override
  String get discoverFilterButton => 'Filtrează';

  @override
  String get discoverSortButton => 'Sortează';

  @override
  String get discoverSortTitle => 'Sortare';

  @override
  String get discoverFilterCategory => 'Categorie';

  @override
  String get discoverFilterListingType => 'Tip de anunț';

  @override
  String get discoverFilterAll => 'Toate';

  @override
  String get discoverSortGenre => 'Gen prioritar';

  @override
  String get discoverSortDate => 'După dată';

  @override
  String get discoverSortNewest => 'Cele mai noi întâi';

  @override
  String get discoverSortOldest => 'Cele mai vechi întâi';

  @override
  String get discoverSortNearest => 'Cele mai apropiate întâi';

  @override
  String get discoverSortApply => 'Sortează';

  @override
  String get discoverScoreBadgeTooltip =>
      'Scor de interes pe 14 zile (vizibil doar adminilor)';

  @override
  String get inventorySelectAll => 'Selectează toate';

  @override
  String get myShelfShare => 'Împarte';

  @override
  String get inventoryMarkAvailable => 'Marchează disponibile';

  @override
  String get libraryTrashEmpty => 'Coșul de gunoi e gol';

  @override
  String get inventoryAppendText => 'Adaugă la sfârșit';

  @override
  String get inventoryTransferred => 'Schimbată';

  @override
  String inventoryDeletedDaysLeft(int days) {
    return 'Șterge în $days zile';
  }

  @override
  String get libraryEmptiedShelves => 'Cărți date sau schimbate';

  @override
  String get libraryRestored => 'Cartea a fost restaurată';

  @override
  String get inventoryDescriptionDone => 'Descrierile au fost actualizate';

  @override
  String get libraryTrashHint =>
      'Cărțile șterse rămân aici 7 zile, apoi dispar definitiv';

  @override
  String get inventoryBulkEditDescription => 'Editează descriere în bulk';

  @override
  String get libraryTrash => 'Coșul de gunoi';

  @override
  String get inventoryRemoveText => 'Șterge din text';

  @override
  String get libraryRestore => 'Restaurează';

  @override
  String get libraryEmptiedShelvesEmpty => 'Nicio carte transferată încă';

  @override
  String get shareMaxTagsReached => 'Poți adăuga maxim 5 taguri';

  @override
  String get shareTitleHint => 'Titlu carte';

  @override
  String get shareTagsHint => 'Taguri (max 5)';

  @override
  String get shareEditionYear => 'An ediție';

  @override
  String get shareDescriptionHint => 'Descriere (max 256 caractere)';

  @override
  String get shareMoreInfo => 'Mai multe informații';

  @override
  String get shareAuthorHint => 'Autor';

  @override
  String get sharePageCountCustom => 'Număr de pagini (suprascrie autofill)';

  @override
  String get shareTagAdd => 'Adaugă tag';

  @override
  String get sharePublisher => 'Editura';

  @override
  String get shareCityHint => 'Localitatea unde se face schimbul';

  @override
  String get sharePublishedYear => 'An apariție';

  @override
  String get shareSubmit => 'Publică';

  @override
  String get shareListingModeAuction => 'Licitație';

  @override
  String get shareSectionBook => 'Cartea';

  @override
  String get shareSectionListing => 'Anunțul';

  @override
  String get shareListingMode => 'Mod de schimb';

  @override
  String shareDescriptionCharsLeft(int n) {
    return '$n caractere rămase';
  }

  @override
  String get shareListingModeSwap => 'Schimb';

  @override
  String get shareListingModeSale => 'Vânzare';

  @override
  String get shareListingModeDonation => 'Donație';

  @override
  String get shareTitleAutocomplete => 'Începe să scrii ca să vezi sugestii';

  @override
  String get shareTitleSearching => 'Se caută titlul...';

  @override
  String get shareSwapAlsoSell => 'Sau vinde cu';

  @override
  String get shareSwapAlsoSellPrice => 'Preț de vânzare';

  @override
  String get shareGenreHint => 'Gen';

  @override
  String get shareAddPhotos => 'Adaugă poze';

  @override
  String get shareFromMyBooks => 'Din cărțile mele';

  @override
  String get shareChooseFromMyBooks => 'Alege din cărțile mele';

  @override
  String get shareNoBooksInMyLibrary => 'Nu ai încă nicio carte adăugată în bibliotecă.';

  @override
  String get preRegisterAlreadyLoggedIn =>
      'Vom folosi emailul tău dacă nu completezi altul';

  @override
  String get preRegisterAndroidHeadline => 'Vine în curând pe telefoanele tale';

  @override
  String get preRegisterSuccess =>
      'Te-ai înscris. Îți dăm de veste când e gata.';

  @override
  String get profilePreRegister => 'Pre-înscriere Android';

  @override
  String get preRegisterAndroidBody =>
      'Lasă-ne emailul și te anunțăm în prima zi când aplicația e live pe Google Play.';

  @override
  String get preRegisterSubmit => 'Adaugă-mă pe listă';

  @override
  String get preRegisterAndroidTitle => 'Pre-înscrie-te pentru Android';

  @override
  String get preRegisterEmailHint => 'Email pentru anunț';

  @override
  String get preRegisterError =>
      'Nu am putut înregistra emailul. Încearcă din nou.';

  @override
  String get profileSettingsSubtitle =>
      'Toate opțiunile contului într-un singur loc';

  @override
  String get profileGroupProfile => 'Profil';

  @override
  String get profileGroupPreferences => 'Preferințe';

  @override
  String get profileGroupAccount => 'Cont';

  @override
  String get profileGroupLibrary => 'Biblioteca mea';

  @override
  String get profileGroupDiscovery => 'Descoperire';

  @override
  String get profileGroupStats => 'Statistici';

  @override
  String get profileGroupSupport => 'Suport';

  @override
  String get profileRecentActivity => 'Activitate recentă';

  @override
  String get profileStatSwaps => 'schimburi';

  @override
  String get profileActivityAdded => 'Ai adăugat';

  @override
  String get profileMoreInSettings => 'Mai multe opțiuni în „⚙\" sus';

  @override
  String profileLibraryAvailable(int n) {
    return '$n disponibile';
  }

  @override
  String get profileStatRating => 'rating';

  @override
  String get profileStatBooks => 'cărți';

  @override
  String get profileSettings => 'Setări';

  @override
  String get profileKeepAlive => 'Keep the app alive';

  @override
  String get profileKeepAliveSubtitle =>
      'ShelfShare rulează pe un server de acasă. Un cafea ajută.';

  @override
  String get aboutDevTitle => 'About dev';

  @override
  String get aboutDevOpenError =>
      'Nu am putut deschide linkul. Încearcă din nou.';

  @override
  String get loginMadeWithLove =>
      'Made with ❤️ in Transylvania 🇷🇴 · Europe 🇪🇺';

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
  String get shortcutsEditTooltip => 'Editează scurtăturile';

  @override
  String get shortcutsDoneTooltip => 'Gata';

  @override
  String get shortcutsAddTitle => 'Adaugă scurtătură';

  @override
  String get shortcutsAllAdded => 'Toate scurtăturile sunt deja adăugate.';

  @override
  String get shortcutFollowing => 'Urmăriți';

  @override
  String get shortcutLeaderboard => 'Clasament';

  @override
  String get shortcutSellerAnalytics => 'Analize vânzător';

  @override
  String get shortcutPreRegister => 'Pre-înregistrare';

  @override
  String get shortcutTrash => 'Coș';

  @override
  String get shareCoverSelected => 'Coperta cărții';

  @override
  String get shareCoverRecommended => 'Coperte recomandate';

  @override
  String get shareCoverChooseOne => 'Alege coperta';

  @override
  String get shareCoverRemove => 'Elimină';

  @override
  String get shareMainPhotoHint =>
      'Apasă pe stea pentru a marca poza principală (apare în feed).';

  @override
  String get chatOfferCounterAction => 'Contra-ofertă';

  @override
  String get chatOfferCounterTitle => 'Trimite o contra-ofertă';

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
  String get aboutAppSustainabilityTitle => 'Sustenabilitate';

  @override
  String get aboutAppSustainabilityBody =>
      'Fiecare schimb de carte înseamnă o carte nouă care nu mai trebuie tipărită, transportată și ambalată. Cumpărarea uneia noi consumă hârtie, apă și energie - un exemplar deja existent, ajuns la un nou cititor, evită tot acest cost.\n\nShelfShare se alătură unei mișcări europene tot mai puternice pentru economia circulară: reutilizarea, în loc de producția continuă de lucruri noi. Un schimb de cărți e un gest mic, dar care contează.';

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

  @override
  String get greetMottoStandingTree =>
      'O carte schimbată e un copac care rămâne în picioare. 🌳';

  @override
  String get greetMottoWhyBuyNew =>
      'De ce cumperi o carte nouă când una te așteaptă la schimb?';

  @override
  String get greetMottoMoreSustainable =>
      'Schimbul de cărți e mai sustenabil decât cumpărarea uneia noi.';

  @override
  String get greetMottoEuropeanMovement =>
      'Faci parte dintr-o mișcare europeană pentru un consum mai sustenabil. 🇪🇺';

  @override
  String get greetMottoCirculating =>
      'Mai puține cărți noi tipărite, mai multe povești care circulă.';

  @override
  String get adminFeatureAccessTitle => 'Acces la funcții';

  @override
  String get adminFeatureAccessDesc =>
      'Acordă acces în avans la funcții aflate încă în lucru, pentru utilizatori aleși manual.';

  @override
  String get adminFeatureAccessSearchHint => 'Caută după nume sau email';

  @override
  String get adminFeatureAccessSearchEmpty =>
      'Caută un utilizator ca să îi vezi accesul.';

  @override
  String get adminFeatureAccessNoResults => 'Niciun utilizator găsit.';

  @override
  String get adminFeatureAccessApply => 'Aplică';

  @override
  String get adminFeatureAccessSaved => 'Accesul a fost actualizat.';

  @override
  String get adminFeatureAccessSaveError => 'Nu am putut salva accesul.';

  @override
  String get featureFlagAdvancedStatistics => 'Statistici avansate';

  @override
  String get bookMatchTitle => 'Potriviri de cărți';

  @override
  String get bookMatchEntryTooltip => 'Potriviri de cărți';

  @override
  String get bookMatchYesTooltip => 'Îmi place';

  @override
  String get bookMatchNoTooltip => 'Nu mă interesează';

  @override
  String get bookMatchInfoTooltip => 'Detalii carte';

  @override
  String get bookMatchYesLabel => 'Da';

  @override
  String get bookMatchNoLabel => 'Nu';

  @override
  String get bookMatchInfoLabel => 'Detalii';

  @override
  String get bookMatchSkip => 'Sari peste';

  @override
  String get bookMatchHint =>
      'Trage cardul la dreapta pentru da, la stânga pentru nu sau în sus ca să sari peste.';

  @override
  String get bookMatchStampYes => 'DA';

  @override
  String get bookMatchStampNo => 'NU';

  @override
  String get bookMatchStampSkip => 'SKIP';

  @override
  String get bookMatchDiscoveryBadge => 'Descoperire';

  @override
  String get bookMatchEmptyTitle => 'Gata pentru moment';

  @override
  String get bookMatchEmptyBody =>
      'Ai văzut tot ce aveam pentru tine acum, revino mai târziu.';

  @override
  String get bookMatchLoadError => 'Nu am putut încărca recomandările.';

  @override
  String get bookMatchRecalibrateTooltip => 'Recalibrare';

  @override
  String get bookMatchRecalibrateTitle => 'Recalibrezi preferințele?';

  @override
  String get bookMatchRecalibrateWarning =>
      'Preferințele tale vor fi semi-resetate: scorurile pe genuri se atenuează și o perioadă vei vedea din nou cărți variate. Acțiunea nu poate fi anulată.';

  @override
  String get bookMatchRecalibrateConfirm => 'Recalibrează';

  @override
  String get bookMatchRecalibrateDone => 'Preferințele au fost recalibrate.';

  @override
  String get bookMatchRecalibrateError => 'Nu am putut recalibra acum.';

  @override
  String get bookMatchRecalibrateCooldownTitle => 'Recalibrare indisponibilă';

  @override
  String bookMatchRecalibrateCooldownBody(int days) {
    return 'Mai poți recalibra peste $days zile.';
  }

  @override
  String onboardingFlowStepLabel(int step, int total) {
    return 'Pasul $step din $total';
  }

  @override
  String get onboardingFlowSkip => 'Sari peste';

  @override
  String get onboardingFlowMoveForward => 'Mergi mai departe';

  @override
  String get onboardingFlowBackTooltip => 'Înapoi';

  @override
  String get onboardingFlowGenresTitle => 'Ce-ți place să citești?';

  @override
  String get onboardingFlowGenresSubtitle =>
      'Alege câteva genuri - le folosim ca să-ți pregătim primele potriviri de cărți.';

  @override
  String get onboardingFlowFrequencyTitle => 'Cât de des citești?';

  @override
  String get onboardingFlowFrequencySubtitle =>
      'Ne ajută să calibrăm cât de des îți arătăm cărți noi.';

  @override
  String get onboardingFlowFrequencyLowTitle => 'Puțin';

  @override
  String get onboardingFlowFrequencyLowDesc => '1-2 cărți pe lună';

  @override
  String get onboardingFlowFrequencyMidTitle => 'Mediu';

  @override
  String get onboardingFlowFrequencyMidDesc => 'O carte pe săptămână';

  @override
  String get onboardingFlowFrequencyHighTitle => 'Mult';

  @override
  String get onboardingFlowFrequencyHighDesc => 'Câteva cărți pe săptămână';

  @override
  String get onboardingFlowLocationTitle => 'Unde te găsim?';

  @override
  String get onboardingFlowLocationSubtitle =>
      'Folosim locația ca să-ți arătăm schimburi realiste, în apropiere.';

  @override
  String get onboardingFlowLanguagesLabel => 'Limbi în care citești';

  @override
  String get onboardingFlowPurposeTitle => 'Ce cauți pe ShelfShare?';

  @override
  String get onboardingFlowPurposeSubtitle =>
      'Ne ajută să-ți personalizăm pagina principală.';

  @override
  String get onboardingFlowPurposeSwapTitle => 'Schimb cărți';

  @override
  String get onboardingFlowPurposeSwapDesc =>
      'Dau și primesc cărți de la alți membri';

  @override
  String get onboardingFlowPurposeSellTitle => 'Vând cărți';

  @override
  String get onboardingFlowPurposeSellDesc =>
      'Vreau mai ales să-mi eliberez rafturile';

  @override
  String get onboardingFlowPurposeDiscoverTitle => 'Doar descopăr';

  @override
  String get onboardingFlowPurposeDiscoverDesc =>
      'Explorez recomandări, fără schimburi încă';

  @override
  String get onboardingFlowPurposeAllTitle => 'Toate de mai sus';

  @override
  String get onboardingFlowPurposeAllDesc => 'Sunt aici pentru tot';

  @override
  String get onboardingFlowBookMatchTitle => 'Hai să vedem ce-ți place';

  @override
  String get onboardingFlowBookMatchSubtitle =>
      'Dă swipe la câteva cărți - ne ajută să-ți pregătim recomandări mai bune chiar de la început.';

  @override
  String get onboardingFlowAddBooksTitle => 'Pune primele cărți pe raft';

  @override
  String get onboardingFlowAddBooksSubtitle =>
      'Adaugă 2-3 cărți pe care le ai acasă - apar direct în profilul tău.';

  @override
  String get onboardingFlowAddBooksCta => 'Adaugă o carte';

  @override
  String get onboardingFlowAddBooksCtaSubtitle => 'Caută titlu sau scanează';

  @override
  String get onboardingFlowAddBooksSkipNote =>
      'Poți sări peste pasul ăsta și să adaugi cărți mai târziu, din Raftul meu.';

  @override
  String get onboardingFlowFinish => 'Intră în ShelfShare';

  @override
  String onboardingFlowBookAdded(String title) {
    return 'Adăugată: $title';
  }

  @override
  String get genreFiction => 'Ficțiune';

  @override
  String get genreNonFiction => 'Non-ficțiune';

  @override
  String get genreClassic => 'Clasic';

  @override
  String get genreRomanianClassic => 'Clasic românesc';

  @override
  String get genreFantasy => 'Fantasy';

  @override
  String get genreSciFi => 'SF';

  @override
  String get genreThriller => 'Thriller';

  @override
  String get genreMystery => 'Mister';

  @override
  String get genreDystopia => 'Distopie';

  @override
  String get genreRomance => 'Romantic';

  @override
  String get genreHistorical => 'Istoric';

  @override
  String get genreBiography => 'Biografie';

  @override
  String get genreSelfHelp => 'Dezvoltare personală';

  @override
  String get genrePsychology => 'Psihologie';

  @override
  String get genrePhilosophy => 'Filosofie';

  @override
  String get genreBusiness => 'Business';

  @override
  String get genrePoetry => 'Poezie';

  @override
  String get genreChildren => 'Copii';

  @override
  String get genreYoungAdult => 'Young adult';

  @override
  String get genreComics => 'Benzi desenate';

  @override
  String get onboardingWelcomeTitle =>
      'Mulțumim că folosești ShelfShare.ro 🇷🇴🇪🇺';

  @override
  String get onboardingWelcomeBullet1 =>
      '🌍 Produs european, găzduit local (self-hosted)';

  @override
  String get onboardingWelcomeBullet2 => '🌳 Creat ca să ajute mediul';

  @override
  String get onboardingWelcomeBullet3 =>
      '📖 Un copac produce în medie ~20.000 de pagini de hârtie, deci fiecare schimb contează';

  @override
  String get onboardingWelcomeBullet4 =>
      '🤝 Nu e doar despre citit, e despre împărtășit';

  @override
  String get onboardingWelcomeSource => 'Sursă: ribble-pack.co.uk';
}
