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
  String get navSearch => 'Caută';

  @override
  String get navLibrary => 'Biblioteca';

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
  String get commonClose => 'Închide';

  @override
  String get commonDelete => 'Șterge';

  @override
  String get commonConfirm => 'Confirmă';

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
  String get profileMyBookshelf => 'Raftul meu';

  @override
  String get bookshelfTitle => 'Raftul meu';

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
  String get homeNearYou => 'Din orașul tău';

  @override
  String get homeNearYouToday => 'Astăzi, aproape de tine';

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
  String get filtersAnyCondition => 'Orice stare';

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
  String get libraryTitle => 'Biblioteca mea';

  @override
  String get libraryViewAsList => 'Vezi ca listă';

  @override
  String get libraryViewAsGrid => 'Vezi ca grilă';

  @override
  String get libraryExportCsv => 'Exportă în CSV';

  @override
  String get libraryEmpty => 'Nu ai nicio carte în bibliotecă încă.';

  @override
  String get libraryLoadError => 'Nu am putut încărca biblioteca.';

  @override
  String get libraryAvailable => 'Disponibilă';

  @override
  String get libraryUnavailable => 'Indisponibilă';

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
  String get bookDetailMakeOffer => 'Fă o ofertă';

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
  String chatOfferCardLabel(String amount, String bookTitle) {
    return '$amount lei · $bookTitle';
  }

  @override
  String get chatSearchPlaceHint =>
      'Caută o adresă sau un loc (ex: Cafeneaua X, Cluj)';

  @override
  String get chatNoResults => 'Niciun rezultat.';

  @override
  String get chatPickDate => 'Alege data';

  @override
  String get chatPickTime => 'Alege ora';

  @override
  String get wishlistTitle => 'Lista de dorințe';

  @override
  String get wishlistEmpty =>
      'Nu ai adăugat încă nicio carte în lista de dorințe.';

  @override
  String get wishlistLoadError => 'Nu am putut încărca lista de dorințe.';

  @override
  String get notificationsTitle => 'Notificări';

  @override
  String get notificationsMarkAllRead => 'Marchează tot ca citit';

  @override
  String get notificationsEmpty => 'Nu ai nicio notificare.';

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
  String get safetyCenterTitle => 'Centru de siguranță';

  @override
  String get safetyCenterIntro =>
      'Câteva reguli simple ca schimburile prin ShelfShare să fie plăcute și sigure.';

  @override
  String get safetyTip1Title => 'Întâlnește-te ziua';

  @override
  String get safetyTip1Desc =>
      'Programează schimbul într-un interval orar cu lumină naturală, ideal dimineața sau după-amiaza.';

  @override
  String get safetyTip2Title => 'Alege un loc public';

  @override
  String get safetyTip2Desc =>
      'O cafenea, o librărie sau un mall sunt variante mai sigure decât adresa personală a cuiva.';

  @override
  String get safetyTip3Title => 'Preferă locații cu supraveghere video';

  @override
  String get safetyTip3Desc =>
      'Zonele cu camere de securitate descurajează comportamentul neplăcut.';

  @override
  String get safetyTip4Title => 'Nu distribui date personale';

  @override
  String get safetyTip4Desc =>
      'Nu ai nevoie să dai adresa de acasă, CNP sau alte date sensibile ca să faci un schimb.';

  @override
  String get safetyTip5Title => 'Verifică rating-ul și scorul de încredere';

  @override
  String get safetyTip5Desc =>
      'Un istoric bun de schimburi finalizate e un semn bun înainte să te întâlnești cu cineva.';

  @override
  String get safetyTip6Title => 'O poză de profil reală crește încrederea';

  @override
  String get safetyTip6Desc =>
      'Profilurile cu poză și bio completă inspiră mai multă siguranță celorlalți utilizatori.';

  @override
  String get safetyTip7Title => 'Verifică starea cărții înainte de schimb';

  @override
  String get safetyTip7Desc =>
      'Compară cartea cu descrierea din anunț înainte să confirmi schimbul ca finalizat.';

  @override
  String get safetyTip8Title => 'Raportează orice comportament suspect';

  @override
  String get safetyTip8Desc =>
      'Poți raporta sau bloca un utilizator direct din profilul lui sau din conversație.';

  @override
  String get helpCenterTitle => 'Întrebări frecvente';

  @override
  String get helpFaq1Question => 'Cum funcționează un schimb de cărți?';

  @override
  String get helpFaq1Answer =>
      'Ceri o carte din anunțul altcuiva (poți oferi și tu o carte în schimb), proprietarul acceptă sau refuză, apoi vă stabiliți o întâlnire prin chat. După ce faceți schimbul în realitate, oricare dintre voi marchează schimbul ca finalizat.';

  @override
  String get helpFaq2Question => 'Ce e Scorul de încredere?';

  @override
  String get helpFaq2Answer =>
      'Un indicator 0-100 calculat automat din activitatea din aplicație: vechimea contului, email verificat, câte schimburi ai finalizat, rating-ul primit, cât de des răspunzi și cât de rar anulezi cereri. Nu e o verificare de identitate, doar un semnal de comportament.';

  @override
  String get helpFaq3Question => 'Cum se calculează prețul „din librării”?';

  @override
  String get helpFaq3Answer =>
      'Când adaugi o carte cu ISBN, încercăm să găsim prețul de listă pe Google Books. Acoperirea e parțială - nu toate cărțile au preț disponibil acolo, mai ales edițiile mai vechi sau românești.';

  @override
  String get helpFaq4Question => 'Ce înseamnă „Preț fix, nenegociabil”?';

  @override
  String get helpFaq4Answer =>
      'Dacă cel care vinde o carte bifează asta, cumpărătorii nu mai pot trimite oferte de preț - cartea se cumpără doar la prețul afișat.';

  @override
  String get helpFaq5Question => 'Cum raportez sau blochez un utilizator?';

  @override
  String get helpFaq5Answer =>
      'Din meniul din colțul din dreapta sus al unei conversații, sau din pagina de detalii a unui anunț (iconița de steag). Blocarea oprește mesajele în ambele direcții.';

  @override
  String get helpFaq6Question =>
      'Ce se întâmplă cu cartea după ce o vând sau o dau la schimb?';

  @override
  String get helpFaq6Answer =>
      'Anunțul devine indisponibil definitiv. Dacă persoana care a primit-o vrea să o listeze mai departe, poate face asta din ecranul de Schimburi/Oferte (\"Adaugă în biblioteca ta\") - istoricul cărții rămâne urmăribil pe pagina ei de detalii, cu poze puse de fiecare proprietar.';

  @override
  String get helpFaq7Question =>
      'De ce nu-mi apare o carte în Categorii sau la Cărți similare?';

  @override
  String get helpFaq7Answer =>
      'Genul unei cărți vine din Open Library sau Google Books la adăugare - unele cărți nu au gen completat în sursele externe, mai ales edițiile mai puțin populare.';

  @override
  String get helpCenterFooter =>
      'Nu ai găsit răspunsul? Poți raporta o problemă direct din conversația cu utilizatorul implicat.';

  @override
  String get adminLoadError => 'Nu am putut încărca datele de admin.';

  @override
  String get adminStatsTitle => 'Statistici';

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
}
