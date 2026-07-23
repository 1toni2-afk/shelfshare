// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for German (`de`).
class AppLocalizationsDe extends AppLocalizations {
  AppLocalizationsDe([String locale = 'de']) : super(locale);

  @override
  String get navHome => 'Start';

  @override
  String get navSearch => 'Suche';

  @override
  String get navLibrary => 'Bibliothek';

  @override
  String get navChat => 'Chat';

  @override
  String get navProfile => 'Profil';

  @override
  String get commonCancel => 'Abbrechen';

  @override
  String get commonSubmit => 'Senden';

  @override
  String get commonSave => 'Speichern';

  @override
  String get commonSeeAll => 'Alle anzeigen';

  @override
  String get commonUnknownUser => 'Nutzer';

  @override
  String get commonAbout => 'Über mich';

  @override
  String get commonRating => 'Bewertung';

  @override
  String get commonBooksExchanged => 'Getauschte Bücher';

  @override
  String get commonRetry => 'Erneut versuchen';

  @override
  String get commonClose => 'Schließen';

  @override
  String get commonDelete => 'Löschen';

  @override
  String get commonConfirm => 'Bestätigen';

  @override
  String get continueWithGoogle => 'Weiter mit Google';

  @override
  String get reportDialogTitle => 'Melden';

  @override
  String get trustScoreTitle => 'Vertrauens-Score';

  @override
  String get trustScoreSubtitle =>
      'Berechnet aus der Aktivität in der App - keine Identitätsprüfung';

  @override
  String get trustScoreEmailVerified => 'E-Mail bestätigt';

  @override
  String trustScoreCompletedRate(int percent) {
    return '$percent% abgeschlossene Tausche';
  }

  @override
  String trustScoreRespondsIn(String time) {
    return 'Antwortet in ~$time';
  }

  @override
  String get trustScoreLastActiveToday => 'Heute aktiv';

  @override
  String trustScoreLastActiveDays(int days) {
    return 'Vor $days Tagen aktiv';
  }

  @override
  String trustScoreResponseRate(int percent) {
    return '$percent% Antwortrate';
  }

  @override
  String trustScoreAverageSwapTime(String time) {
    return 'Schließt einen Tausch in ~$time ab';
  }

  @override
  String memberSinceDays(int days) {
    return 'Mitglied seit $days Tagen';
  }

  @override
  String memberSinceMonths(int months) {
    return 'Mitglied seit $months Monaten';
  }

  @override
  String memberSinceYears(int years) {
    return 'Mitglied seit $years Jahren';
  }

  @override
  String durationMinutes(int minutes) {
    return '$minutes Min';
  }

  @override
  String durationHours(int hours) {
    return '${hours}Std';
  }

  @override
  String durationDays(int days) {
    return '$days Tage';
  }

  @override
  String priceLei(String amount) {
    return '$amount Lei';
  }

  @override
  String get commonEmailLabel => 'E-Mail';

  @override
  String get commonEmailInvalid => 'Ungültige E-Mail';

  @override
  String get commonOr => 'oder';

  @override
  String get commonRequired => 'Erforderlich';

  @override
  String get commonContinue => 'Weiter';

  @override
  String get loginWelcomeBack => 'Willkommen zurück';

  @override
  String get authPasswordLabel => 'Passwort';

  @override
  String get authEnterPasswordError => 'Gib dein Passwort ein';

  @override
  String get authMinEightChars => 'Mindestens 8 Zeichen';

  @override
  String get authForgotPasswordLink => 'Passwort vergessen?';

  @override
  String get authLoginSubmit => 'Anmelden';

  @override
  String get authNoAccount => 'Noch kein Konto? ';

  @override
  String get authCreateOne => 'Konto erstellen';

  @override
  String get authGoogleFailed =>
      'Google-Anmeldung fehlgeschlagen. Bitte versuche es erneut.';

  @override
  String get supportContactButton =>
      'Kannst du dich nicht anmelden? Kontaktiere uns';

  @override
  String get supportDialogTitle => 'Support kontaktieren';

  @override
  String get supportDialogSubtitle =>
      'Sag uns, was los ist - wir antworten per E-Mail.';

  @override
  String get supportNameLabel => 'Name';

  @override
  String get supportPhoneLabel => 'Telefon (optional)';

  @override
  String get supportMessageLabel => 'Deine Nachricht';

  @override
  String get supportCaptchaAnswerLabel => 'Deine Antwort';

  @override
  String get supportSubmit => 'Nachricht senden';

  @override
  String get supportSuccessMessage =>
      'Nachricht gesendet! Wir melden uns bald per E-Mail.';

  @override
  String get supportGenericError =>
      'Nachricht konnte nicht gesendet werden. Versuche es erneut.';

  @override
  String get authRegisterTitle => 'Konto erstellen';

  @override
  String get authRegisterSubtitle => 'Werde Teil der ShelfShare-Community';

  @override
  String get authReferralCodeLabel => 'Empfehlungscode (optional)';

  @override
  String get verifyCodeTooShort => 'Der Code muss 6 Ziffern haben';

  @override
  String get verifySuccessSnackbar => 'Konto erfolgreich bestätigt!';

  @override
  String get verifyInvalidOrExpired => 'Ungültiger oder abgelaufener Code.';

  @override
  String get verifyResendSnackbar =>
      'Der Code wurde erneut gesendet, falls zutreffend.';

  @override
  String get verifyEmailHeading => 'Bestätige deine E-Mail';

  @override
  String verifySentTo(String email) {
    return 'Wir haben einen Bestätigungscode an $email gesendet';
  }

  @override
  String get verifyConfirmButton => 'Bestätigen';

  @override
  String get verifyResending => 'Wird erneut gesendet...';

  @override
  String get verifyResendPrompt => 'Keinen Code erhalten? Erneut senden';

  @override
  String get forgotPasswordTitle => 'Passwort zurücksetzen';

  @override
  String get forgotPasswordSubtitle =>
      'Wir senden dir einen Code zum Zurücksetzen per E-Mail.';

  @override
  String get forgotPasswordSubmit => 'Code senden';

  @override
  String get forgotPasswordCodeHeading => 'Gib den Code aus deiner E-Mail ein';

  @override
  String forgotPasswordCodeSentTo(String email) {
    return 'Wir haben einen Code an $email gesendet';
  }

  @override
  String get resetPasswordTitle => 'Neues Passwort festlegen';

  @override
  String get resetPasswordSubtitle => 'Wähle ein neues Passwort für dein Konto';

  @override
  String get resetPasswordNewLabel => 'Neues Passwort';

  @override
  String get resetPasswordSubmit => 'Passwort festlegen';

  @override
  String get resetPasswordSuccessHeading => 'Passwort geändert';

  @override
  String get resetPasswordSuccessBody =>
      'Dein Passwort wurde aktualisiert. Du kannst dich jetzt anmelden.';

  @override
  String get resetPasswordGoToLogin => 'Zur Anmeldung';

  @override
  String get resetPasswordGenericError =>
      'Passwort konnte nicht zurückgesetzt werden. Versuche es erneut.';

  @override
  String get authConfirmPasswordLabel => 'Passwort bestätigen';

  @override
  String get authPasswordMismatch => 'Die Passwörter stimmen nicht überein';

  @override
  String get onboardingTitle => 'Fast fertig!';

  @override
  String get onboardingSubtitle => 'Sag uns, wie andere dich sehen sollen';

  @override
  String get onboardingFirstName => 'Vorname';

  @override
  String get onboardingLastName => 'Nachname';

  @override
  String get onboardingUsername => 'Benutzername';

  @override
  String get onboardingUsernameFormatError =>
      '3-20 Zeichen: Buchstaben, Zahlen oder Unterstrich';

  @override
  String get onboardingGenericError =>
      'Etwas ist schiefgelaufen. Bitte versuche es erneut.';

  @override
  String get onboardingNameVisibleSwitch =>
      'Meinen Namen öffentlich sichtbar machen';

  @override
  String get onboardingUsernameAlwaysVisible =>
      'Dein Benutzername bleibt immer sichtbar';

  @override
  String get profileTitle => 'Mein Profil';

  @override
  String get profileCopyLink => 'Link kopieren';

  @override
  String get profileLoadError => 'Dein Profil konnte nicht geladen werden.';

  @override
  String get profileAboutMe => 'Über mich';

  @override
  String get profileBadgesTitle => 'Abzeichen';

  @override
  String get profileMyExchanges => 'Meine Tausche';

  @override
  String get profileSafetyCenter => 'Sicherheitscenter';

  @override
  String get profileHelpCenter => 'Häufige Fragen';

  @override
  String get profileLeaderboard => 'Rangliste';

  @override
  String get profileSendFeedback => 'Feedback senden';

  @override
  String get profileEditProfile => 'Profil bearbeiten';

  @override
  String get profileAdminPanel => 'Admin-Bereich';

  @override
  String get profileLogout => 'Abmelden';

  @override
  String get profileLanguage => 'Sprache';

  @override
  String get profileDarkModeSection => 'Dunkler Modus';

  @override
  String get profileThemeSystem => 'Automatisch (System)';

  @override
  String get profileThemeLight => 'Hell';

  @override
  String get profileThemeDark => 'Dunkel';

  @override
  String get profileQrTooltip => 'QR-Code';

  @override
  String get profileQrDialogTitle => 'Dein QR-Code';

  @override
  String get profileQrDialogBody =>
      'Wer diesen Code scannt, kann dein Profil öffnen.';

  @override
  String get profileReferralTitle => 'Dein Empfehlungscode';

  @override
  String get profileReferralSubtitle =>
      'Teile ihn mit Freunden, damit sie dich auf ShelfShare finden';

  @override
  String profileReferralCountLabel(int count) {
    return '$count eingeladene Freunde';
  }

  @override
  String get profileReferralCopied => 'Code in die Zwischenablage kopiert';

  @override
  String get profileFeedbackHint => 'Was möchtest du uns mitteilen?';

  @override
  String get profileFeedbackThanks => 'Danke für dein Feedback!';

  @override
  String get profileFeedbackError =>
      'Dein Feedback konnte nicht gesendet werden';

  @override
  String get profileUsernameLabel => 'Benutzername';

  @override
  String get profileCityLabel => 'Stadt';

  @override
  String get profileNoCity => 'Keine Stadt';

  @override
  String get profileShowAcquisitionHistory =>
      'Erwerbsverlauf im Profil anzeigen';

  @override
  String get profileShowAcquisitionHistorySubtitle =>
      'Bücher, die du durch Tausch oder Kauf in der App erhalten hast';

  @override
  String get profileSaveError => 'Dein Profil konnte nicht gespeichert werden.';

  @override
  String get commonSendMessage => 'Nachricht senden';

  @override
  String get publicProfileTitle => 'Profil';

  @override
  String get publicProfileFollowUpdateError =>
      'Das Folgen konnte nicht aktualisiert werden';

  @override
  String get publicProfileMessageError =>
      'Die Unterhaltung konnte nicht gestartet werden.';

  @override
  String publicProfileMemberSince(int year) {
    return 'Mitglied seit $year';
  }

  @override
  String publicProfileFollowersFollowing(int followers, int following) {
    return '$followers Follower · $following Gefolgte';
  }

  @override
  String get publicProfileUnfollow => 'Nicht mehr folgen';

  @override
  String get publicProfileFollow => 'Folgen';

  @override
  String get publicProfileReadingStats => 'Lesestatistiken';

  @override
  String get publicProfileBooksListed => 'Gelistete Bücher';

  @override
  String get publicProfileTotalPages => 'Seiten insgesamt';

  @override
  String get publicProfileFavoriteGenre => 'Lieblingsgenre';

  @override
  String get publicProfileBooksShared => 'Geteilte Bücher';

  @override
  String get publicProfileBooksReceived => 'Erhaltene Bücher';

  @override
  String get publicProfileLongestBook => 'Längstes Buch';

  @override
  String publicProfileListedBooksCount(int count) {
    return 'Gelistete Bücher ($count)';
  }

  @override
  String get publicProfileAcquisitionHistory =>
      'Verlauf der in der App erhaltenen Bücher';

  @override
  String get publicProfileNoAcquisitions =>
      'Noch kein abgeschlossener Tausch oder Kauf.';

  @override
  String publicProfileReviewsCount(int count) {
    return 'Bewertungen ($count)';
  }

  @override
  String get leaderboardEmpty => 'Noch keine aktive Stadt.';

  @override
  String get leaderboardUnknownCity => 'Unbekannt';

  @override
  String leaderboardExchangesCount(int count) {
    return '$count Tausche';
  }

  @override
  String get leaderboardLoadError =>
      'Die Rangliste konnte nicht geladen werden.';

  @override
  String get leaderboardTabCity => 'Nach Stadt';

  @override
  String get leaderboardTabNational => 'Landesweit';

  @override
  String get leaderboardTabTopReaders => 'Leser';

  @override
  String leaderboardPagesCount(int count) {
    return '$count Seiten';
  }

  @override
  String get profileGlobalStats => 'Globale Statistiken';

  @override
  String get profileMyBookshelf => 'Mein Bücherregal';

  @override
  String get bookshelfTitle => 'Mein Bücherregal';

  @override
  String get bookshelfTabReading => 'Lese ich';

  @override
  String get bookshelfTabWantToRead => 'Möchte ich lesen';

  @override
  String get bookshelfTabFinished => 'Gelesen';

  @override
  String get bookshelfTabShared => 'Geteilt';

  @override
  String get bookshelfEmpty => 'Noch keine Bücher hier.';

  @override
  String get bookshelfLoadError => 'Bücherregal konnte nicht geladen werden.';

  @override
  String get bookDetailShelfSectionTitle => 'Zu deinem Bücherregal hinzufügen';

  @override
  String gamificationLevel(int level) {
    return 'Level $level';
  }

  @override
  String gamificationXp(int xp) {
    return '$xp XP';
  }

  @override
  String gamificationXpToNextLevel(int xp) {
    return '$xp XP bis zum nächsten Level';
  }

  @override
  String gamificationStreak(int days) {
    return '$days Tage in Folge';
  }

  @override
  String gamificationLongestStreak(int days) {
    return 'Rekord: $days Tage';
  }

  @override
  String get profileMonthlyChallenges => 'Monatliche Herausforderungen';

  @override
  String get monthlyChallengesTitle => 'Monatliche Herausforderungen';

  @override
  String get profileReadingChallenge => 'Lese-Challenge';

  @override
  String readingChallengeTitle(int year) {
    return 'Lese-Challenge $year';
  }

  @override
  String get readingChallengeNoGoal =>
      'Du hast für dieses Jahr noch kein Ziel festgelegt.';

  @override
  String readingChallengeProgress(int progress, int goal) {
    return '$progress von $goal Büchern gelesen';
  }

  @override
  String get readingChallengeSetGoal => 'Ziel festlegen';

  @override
  String get readingChallengeGoalLabel =>
      'Wie viele Bücher möchtest du dieses Jahr beenden?';

  @override
  String get profileActivityFeed => 'Letzte Aktivität';

  @override
  String get activityFeedTitle => 'Letzte Aktivität';

  @override
  String get activityFeedEmpty =>
      'Noch keine Aktivität - folge anderen, um zu sehen, was sie lesen.';

  @override
  String get activityFeedLoadError => 'Aktivität konnte nicht geladen werden.';

  @override
  String activityNewListing(String name) {
    return '$name hat ein neues Buch eingestellt';
  }

  @override
  String activityFinishedBook(String name) {
    return '$name hat mit dem Lesen fertig';
  }

  @override
  String activityCompletedExchange(String name) {
    return '$name hat einen Tausch abgeschlossen';
  }

  @override
  String get bookDetailShelfRemove => 'Vom Regal entfernen';

  @override
  String get publicProfileBookshelfTitle => 'Bücherregal';

  @override
  String get globalStatsTitle => 'Globale Statistiken';

  @override
  String get globalStatsTabMostShared => 'Meistgeteilt';

  @override
  String get globalStatsTabTrending => 'Im Trend';

  @override
  String get globalStatsTabPopularAuthors => 'Beliebte Autoren';

  @override
  String get globalStatsEmpty => 'Noch keine Daten.';

  @override
  String get globalStatsLoadError =>
      'Statistiken konnten nicht geladen werden.';

  @override
  String globalStatsTransferCount(int count) {
    return '$count Tausch/Verkauf';
  }

  @override
  String globalStatsViewCount(int count) {
    return '$count Aufrufe (14 Tage)';
  }

  @override
  String get profileFavoriteSellers => 'Lieblingsverkäufer';

  @override
  String get favoriteSellersTitle => 'Lieblingsverkäufer';

  @override
  String get favoriteSellersEmpty => 'Du folgst noch niemandem.';

  @override
  String get favoriteSellersLoadError => 'Liste konnte nicht geladen werden.';

  @override
  String get publicProfileTopGenres => 'Lieblingsgenres';

  @override
  String get impactStatsTitle => 'Wirkung';

  @override
  String get impactStatsTotalValue => 'Gesamtwert getauscht';

  @override
  String get impactStatsMoneySaved => 'Gespartes Geld';

  @override
  String get impactStatsCo2Saved => 'Eingespartes CO₂ (geschätzt)';

  @override
  String impactStatsCo2Value(String kg) {
    return '$kg kg';
  }

  @override
  String homeGreeting(String name) {
    return 'Hallo, $name!';
  }

  @override
  String get homeWelcome => 'Willkommen!';

  @override
  String get homeLoadError => 'Die Bücher konnten nicht geladen werden.';

  @override
  String get homeEmpty => 'Noch keine Bücher verfügbar.';

  @override
  String get homeCategories => 'Kategorien';

  @override
  String get homeRecentlyAdded => 'Kürzlich hinzugefügt';

  @override
  String get homeMostViewed => 'Meistgesehen';

  @override
  String get homeNearYou => 'In deiner Stadt';

  @override
  String get homeNearYouToday => 'Heute in deiner Nähe';

  @override
  String get homeRecommendedForYou => 'Für dich empfohlen';

  @override
  String get homeHiddenGems => 'Versteckte Schätze';

  @override
  String get homeCompleteYourCollection => 'Vervollständige deine Sammlung';

  @override
  String get homeSimilarTaste => 'Ähnlicher Geschmack';

  @override
  String get profileSmartMatches => 'Passende Tauschpartner';

  @override
  String get smartMatchesTitle => 'Passende Tauschpartner';

  @override
  String get smartMatchesEmpty =>
      'Noch keine Treffer - füge Bücher zu deiner Wunschliste hinzu und liste verfügbare Bücher.';

  @override
  String get smartMatchesLoadError => 'Treffer konnten nicht geladen werden.';

  @override
  String get smartMatchesTheyHave => 'Hat, was du willst';

  @override
  String get smartMatchesTheyWant => 'Will, was du hast';

  @override
  String get homeUpcomingBooks => 'Kommende Bücher';

  @override
  String get homeActiveMembers => 'Aktive Mitglieder';

  @override
  String get browseTitle => 'Bücher suchen';

  @override
  String get browseMapTooltip => 'Karte mit Büchern in der Nähe';

  @override
  String get browseSearchHint => 'Nach Titel suchen';

  @override
  String get browseEmpty => 'Keine Bücher gefunden.';

  @override
  String get filtersTitle => 'Filter';

  @override
  String get filtersAuthor => 'Autor';

  @override
  String get filtersGenre => 'Genre';

  @override
  String get filtersLanguage => 'Sprache';

  @override
  String get filtersAnyCity => 'Beliebige Stadt';

  @override
  String get filtersCondition => 'Zustand';

  @override
  String get filtersAnyCondition => 'Beliebiger Zustand';

  @override
  String get filtersListingType => 'Anzeigenart';

  @override
  String get filtersListingTypeSwap => 'Tausch';

  @override
  String get filtersListingTypeSale => 'Verkauf';

  @override
  String get filtersListingTypeAuction => 'Auktion';

  @override
  String get filtersNearbyOnly => 'Nur in der Nähe';

  @override
  String get filtersNearbyOnlyHintOff =>
      'Nach tatsächlicher Entfernung von deiner Stadt sortieren und filtern';

  @override
  String filtersNearbyOnlyHintOn(int km) {
    return 'Bis zu $km km von deiner Stadt entfernt';
  }

  @override
  String filtersDistanceKm(int km) {
    return '$km km';
  }

  @override
  String get filtersReset => 'Zurücksetzen';

  @override
  String get filtersApply => 'Filter anwenden';

  @override
  String get commonYes => 'Ja';

  @override
  String get commonNo => 'Nein';

  @override
  String get commonGiveUp => 'Abbrechen';

  @override
  String get libraryTitle => 'Meine Bibliothek';

  @override
  String get libraryViewAsList => 'Als Liste anzeigen';

  @override
  String get libraryViewAsGrid => 'Als Raster anzeigen';

  @override
  String get libraryExportCsv => 'Als CSV exportieren';

  @override
  String get libraryEmpty => 'Du hast noch keine Bücher in deiner Bibliothek.';

  @override
  String get libraryLoadError =>
      'Deine Bibliothek konnte nicht geladen werden.';

  @override
  String get libraryAvailable => 'Verfügbar';

  @override
  String get libraryUnavailable => 'Nicht verfügbar';

  @override
  String get libraryDeleteConfirmTitle => 'Buch löschen?';

  @override
  String libraryDeleteConfirmBody(String title) {
    return '„$title\" wird aus deiner Bibliothek entfernt.';
  }

  @override
  String get libraryAvailableForSwap => 'Verfügbar zum Tausch';

  @override
  String get libraryDeleteBook => 'Buch löschen';

  @override
  String get libraryEditListing => 'Anzeige bearbeiten';

  @override
  String get libraryEditListingTitle => 'Anzeige bearbeiten';

  @override
  String get libraryEditListingSuccess => 'Anzeige aktualisiert.';

  @override
  String get csvHeaderTitle => 'Titel';

  @override
  String get csvHeaderAvailableForSwap => 'Verfügbar zum Tausch';

  @override
  String get csvHeaderForSale => 'Zum Verkauf';

  @override
  String get csvHeaderPrice => 'Preis';

  @override
  String get addBookTitle => 'Buch hinzufügen';

  @override
  String get addBookSearchHint => 'Titel oder ISBN';

  @override
  String get addBookSearchButton => 'Suchen';

  @override
  String get addBookSearchFailed =>
      'Suche fehlgeschlagen. Bitte versuche es erneut.';

  @override
  String get addBookSearchPrompt => 'Suche ein Buch nach Titel oder ISBN.';

  @override
  String get addBookManualEntry => 'Manuell hinzufügen';

  @override
  String get addBookNotFoundManual =>
      'Findest du das Buch nicht? Manuell hinzufügen';

  @override
  String get addBookChange => 'Ändern';

  @override
  String get addBookTitleLabel => 'Titel';

  @override
  String get addBookSearchInstead => 'Stattdessen suchen';

  @override
  String get addBookLanguageOptional => 'Sprache (optional)';

  @override
  String get addBookEditionOptional => 'Ausgabe (optional)';

  @override
  String get addBookHardcoverSwitch => 'Gebundene Ausgabe';

  @override
  String get addBookForSaleSwitch => 'Zum Verkauf';

  @override
  String get addBookForSaleHint =>
      'Neben dem Tausch kannst du das Buch auch zu einem Festpreis verkaufen';

  @override
  String get addBookPriceLabel => 'Preis (Lei)';

  @override
  String get addBookNonNegotiable => 'Festpreis, nicht verhandelbar';

  @override
  String get addBookNonNegotiableHint =>
      'Käufer können keine Preisangebote machen';

  @override
  String get addBookAuctionSwitch => 'Auktion starten';

  @override
  String get addBookAuctionHint =>
      'Käufer bieten, das höchste Gebot gewinnt am Ende';

  @override
  String get addBookAuctionStartingPrice => 'Startpreis';

  @override
  String get addBookAuctionReservePrice => 'Mindestpreis (optional)';

  @override
  String get addBookAuctionReservePriceHint =>
      'Der niedrigste Preis, unter dem du nicht verkaufst';

  @override
  String get addBookAuctionBuyNowPrice => '\"Sofort kaufen\"-Preis (optional)';

  @override
  String get addBookAuctionBuyNowPriceHint =>
      'Nur vor dem ersten Gebot verfügbar';

  @override
  String get addBookAuctionDuration => 'Auktionsdauer';

  @override
  String get addBookAuctionDuration24h => '24 Stunden';

  @override
  String get addBookAuctionDuration3d => '3 Tage';

  @override
  String get addBookAuctionDuration7d => '7 Tage';

  @override
  String get addBookPhotosLabelRequired =>
      'Fotos des Buches (erforderlich, mindestens 1)';

  @override
  String get addBookPhotosLabelOptional => 'Fotos des Buches (optional)';

  @override
  String get addBookSubmit => 'Zur Bibliothek hinzufügen';

  @override
  String get addBookTitleRequired => 'Titel ist erforderlich';

  @override
  String get addBookInvalidPrice => 'Gib einen gültigen Preis ein';

  @override
  String get addBookNeedPhoto =>
      'Füge mindestens ein Foto des Buches hinzu, bevor du es zum Verkauf anbietest';

  @override
  String get addBookSuccess => 'Buch zur Bibliothek hinzugefügt';

  @override
  String get addBookGenericError =>
      'Das Buch konnte nicht hinzugefügt werden. Bitte versuche es erneut.';

  @override
  String get relistNeedPhoto =>
      'Füge mindestens ein Foto hinzu, bevor du es zum Verkauf anbietest';

  @override
  String get relistSuccess => 'Das Buch wurde zu deiner Bibliothek hinzugefügt';

  @override
  String get relistGenericError => 'Das Buch konnte nicht hinzugefügt werden.';

  @override
  String relistHeading(String title) {
    return '„$title\" zu deiner Bibliothek hinzufügen';
  }

  @override
  String get relistSubtitle =>
      'Beschreibe den Zustand, in dem du es erhalten hast - das bleibt mit der Buchhistorie verknüpft.';

  @override
  String get mapTitle => 'Bücher in der Nähe';

  @override
  String get mapLoadError => 'Die Karte konnte nicht geladen werden.';

  @override
  String get mapEmpty => 'Noch keine Bücher in irgendeiner Stadt verfügbar.';

  @override
  String mapCityBooksCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Bücher',
      one: '$count Buch',
    );
    return '$_temp0';
  }

  @override
  String get bookDetailTitle => 'Buchdetails';

  @override
  String get bookDetailReportTooltip => 'Anzeige melden';

  @override
  String bookDetailReportedFrom(String title) {
    return 'Gemeldet von Anzeige \"$title\"';
  }

  @override
  String get bookDetailReportSent => 'Meldung gesendet. Danke!';

  @override
  String get bookDetailReportError =>
      'Die Meldung konnte nicht gesendet werden';

  @override
  String get bookDetailLoadError => 'Das Buch konnte nicht geladen werden.';

  @override
  String get bookDetailViewsTitle => 'Aufrufe';

  @override
  String get bookDetailViewsLoadError =>
      'Die Aufrufstatistik konnte nicht geladen werden.';

  @override
  String bookDetailUniqueViews(int count) {
    return '$count eindeutige Aufrufe';
  }

  @override
  String bookDetailTotalViews(int count) {
    return '$count Aufrufe insgesamt, inklusive Neuladen der Seite';
  }

  @override
  String get bookDetailHardcoverChip => 'Gebunden';

  @override
  String get bookDetailAvailableChip => 'Verfügbar zum Tausch';

  @override
  String bookDetailViewCount(int count) {
    return '$count Aufrufe';
  }

  @override
  String get bookDetailDescriptionTitle => 'Beschreibung';

  @override
  String get bookDetailDetailsTitle => 'Details';

  @override
  String get bookDetailPublisherLabel => 'Verlag';

  @override
  String get bookDetailYearLabel => 'Erscheinungsjahr';

  @override
  String get bookDetailPagesLabel => 'Seiten';

  @override
  String get bookDetailOwnerTitle => 'Besitzer';

  @override
  String get bookDetailPhotosTitle => 'Fotos';

  @override
  String get bookDetailRequestExchange => 'Zum Tausch anfragen';

  @override
  String get bookDetailUnavailableForExchange => 'Nicht verfügbar zum Tausch';

  @override
  String get bookDetailMakeOffer => 'Angebot machen';

  @override
  String get bookDetailHistoryTitle => 'Verlauf dieses Buches';

  @override
  String get bookDetailHistorySubtitle =>
      'Wie das Buch durch die App gewandert ist, mit Fotos von jedem Besitzer.';

  @override
  String get bookDetailHistorySold => 'verkauft';

  @override
  String get bookDetailHistoryExchanged => 'getauscht';

  @override
  String bookDetailHistoryListedOn(String date) {
    return 'gelistet am $date';
  }

  @override
  String bookDetailHistoryTransferredOn(String action, String date) {
    return ' · $action am $date';
  }

  @override
  String get bookDetailHistoryCurrentlyOwned => ' · aktuell im Besitz';

  @override
  String get bookDetailSimilarBooksTitle => 'Ähnliche Bücher';

  @override
  String bookDetailLibraryPriceLabel(String price) {
    return 'Buchhandelspreis: $price';
  }

  @override
  String bookDetailRequestedTitle(String title) {
    return '„$title\" zum Tausch anfragen';
  }

  @override
  String get bookDetailNoBooksToOffer =>
      'Du hast keine Bücher zum Anbieten - du kannst die Anfrage auch ohne senden.';

  @override
  String get bookDetailOfferOneOfYourBooks =>
      'Biete eines deiner Bücher an (optional)';

  @override
  String get bookDetailNoOffer => 'Kein Angebot';

  @override
  String get bookDetailMessageOptional => 'Nachricht (optional)';

  @override
  String get bookDetailSendRequest => 'Anfrage senden';

  @override
  String get bookDetailRequestSent => 'Tauschanfrage gesendet';

  @override
  String get bookDetailRequestError =>
      'Die Anfrage konnte nicht gesendet werden.';

  @override
  String get bookDetailFirstExchangeTitle => 'Dein erster Tausch';

  @override
  String get bookDetailFirstExchangeBody =>
      'Ein paar Tipps vor deinem ersten Tausch: Trefft euch tagsüber an einem öffentlichen Ort und prüfe den Zustand des Buches, bevor du den Tausch als abgeschlossen bestätigst.';

  @override
  String get bookDetailUnderstood => 'Verstanden, weiter';

  @override
  String bookDetailMakeOfferTitle(String title) {
    return 'Angebot machen für „$title\"';
  }

  @override
  String bookDetailAskingPrice(String price) {
    return 'Geforderter Preis: $price';
  }

  @override
  String get bookDetailOfferAmountLabel => 'Angebotener Betrag';

  @override
  String get bookDetailSendOffer => 'Angebot senden';

  @override
  String get bookDetailOfferSent => 'Angebot gesendet';

  @override
  String get bookDetailOfferError =>
      'Das Angebot konnte nicht gesendet werden.';

  @override
  String get bookDetailInvalidAmount => 'Gib einen gültigen Betrag ein';

  @override
  String get commonAddToLibrary => 'Zu deiner Bibliothek hinzufügen';

  @override
  String get commonAnonymousUser => 'ein Nutzer';

  @override
  String get exchangesTitle => 'Meine Tausche';

  @override
  String get exchangesTabReceived => 'Erhaltene Tausche';

  @override
  String get exchangesTabSent => 'Gesendete Tausche';

  @override
  String get offersTabReceived => 'Erhaltene Angebote';

  @override
  String get offersTabSent => 'Gesendete Angebote';

  @override
  String get exchangesEmptyReceived =>
      'Du hast noch keine Tauschanfragen erhalten.';

  @override
  String get exchangesEmptySent =>
      'Du hast noch keine Tauschanfragen gesendet.';

  @override
  String get exchangesLoadError =>
      'Deine Tausche konnten nicht geladen werden.';

  @override
  String exchangeRequestedBy(String name) {
    return 'Angefragt von $name';
  }

  @override
  String exchangeFrom(String name) {
    return 'Von $name';
  }

  @override
  String exchangeOffersBook(String title) {
    return 'Bietet: $title';
  }

  @override
  String exchangeOffersAmount(String amount) {
    return 'Bietet: $amount RON';
  }

  @override
  String get exchangeReject => 'Ablehnen';

  @override
  String get exchangeAccept => 'Annehmen';

  @override
  String get exchangeCancelRequest => 'Anfrage stornieren';

  @override
  String get exchangeScheduleMeeting => 'Treffen planen';

  @override
  String get exchangeReschedule => 'Neu planen';

  @override
  String get exchangeAddToCalendar => 'Zum Kalender hinzufügen';

  @override
  String get exchangeQrCode => 'QR-Code';

  @override
  String get exchangeMarkComplete => 'Als abgeschlossen markieren';

  @override
  String get exchangeRated => 'Bewertet';

  @override
  String get exchangeRate => 'Bewerten';

  @override
  String get exchangeCalendarError =>
      'Der Kalender konnte nicht geöffnet werden.';

  @override
  String get exchangeRatingDialogTitle => 'Wie war der Tausch?';

  @override
  String get exchangeRatingOverall => 'Insgesamt';

  @override
  String get exchangeRatingCommunication => 'Kommunikation';

  @override
  String get exchangeRatingPunctuality => 'Pünktlichkeit';

  @override
  String get exchangeRatingCondition => 'Zustand des erhaltenen Buchs';

  @override
  String get exchangeReviewOptional => 'Bewertung (optional)';

  @override
  String get exchangeQrDialogTitle => 'Bestätigungs-QR-Code';

  @override
  String get exchangeQrDialogBody =>
      'Die andere Person scannt diesen Code beim Treffen, um den Tausch zu bestätigen.';

  @override
  String get exchangeMeetingSheetTitle => 'Treffen planen';

  @override
  String get exchangePickDateTime => 'Datum und Uhrzeit wählen';

  @override
  String get exchangeLocationLabel => 'Ort';

  @override
  String get exchangeMeetingSaveError =>
      'Das Treffen konnte nicht gespeichert werden.';

  @override
  String get offersEmptyReceived =>
      'Du hast noch keine Preisangebote erhalten.';

  @override
  String get offersEmptySent => 'Du hast noch keine Preisangebote gesendet.';

  @override
  String get offersLoadError => 'Deine Angebote konnten nicht geladen werden.';

  @override
  String offerTo(String name) {
    return 'An $name';
  }

  @override
  String offerAmountLine(String amount) {
    return 'Angebot: $amount';
  }

  @override
  String get offerCancel => 'Angebot stornieren';

  @override
  String get exchangeConfirmTitle => 'Tausch bestätigen';

  @override
  String get exchangeConfirmError =>
      'Der Tausch konnte nicht bestätigt werden.';

  @override
  String get exchangeConfirmDone => 'Tausch als abgeschlossen markiert!';

  @override
  String get exchangeConfirmQuestion =>
      'Bestätigst du, dass der Büchertausch abgeschlossen ist?';

  @override
  String get exchangeConfirmButton => 'Abschluss bestätigen';

  @override
  String get chatEmptyConversations => 'Du hast noch keine Unterhaltungen.';

  @override
  String get chatStartConversation => 'Unterhaltung beginnen';

  @override
  String get chatPhotoPreview => '📷 Foto';

  @override
  String get chatLocationPreview => '📍 Standort';

  @override
  String get chatLoadError =>
      'Deine Unterhaltungen konnten nicht geladen werden.';

  @override
  String get chatConversationFallbackTitle => 'Unterhaltung';

  @override
  String get chatUnblock => 'Entsperren';

  @override
  String get chatBlock => 'Blockieren';

  @override
  String get chatUserUnblocked => 'Nutzer entsperrt';

  @override
  String get chatUserBlocked => 'Nutzer blockiert';

  @override
  String get chatBlockUpdateError =>
      'Die Blockierung konnte nicht aktualisiert werden';

  @override
  String get chatTyping => 'schreibt...';

  @override
  String get chatBlockedNotice =>
      'Du kannst diesem Nutzer keine Nachrichten senden - die Unterhaltung ist blockiert.';

  @override
  String get chatShareLocationTooltip => 'Treffpunkt senden';

  @override
  String get chatMessageHint => 'Schreibe eine Nachricht...';

  @override
  String get chatSafetyBannerBody =>
      'Sende kein Geld im Voraus und trefft euch für den Tausch an einem öffentlichen Ort. Wenn dir etwas verdächtig vorkommt, melde oder blockiere den Nutzer über das Menü oben.';

  @override
  String get chatSafetyBannerLearnMore => 'Mehr erfahren';

  @override
  String get chatEmptyMessages => 'Noch keine Nachrichten. Sag Hallo!';

  @override
  String get chatMapLabel => 'Karte';

  @override
  String get chatCalendarLabel => 'Kalender';

  @override
  String chatMeetingAt(String date, String time) {
    return '$date um $time';
  }

  @override
  String get chatSafetyAdvisorLabel => 'Sicherheitsberater';

  @override
  String get chatSafetyAdvisorBody =>
      'Achte darauf, die Sicherheitshinweise für dieses Treffen zu befolgen.';

  @override
  String get chatOfferActionError =>
      'Angebot konnte nicht aktualisiert werden. Versuche es erneut.';

  @override
  String chatOfferCardLabel(String amount, String bookTitle) {
    return '$amount Lei · $bookTitle';
  }

  @override
  String get chatSearchPlaceHint =>
      'Suche nach einer Adresse oder einem Ort (z.B. Café X, Cluj)';

  @override
  String get chatNoResults => 'Keine Ergebnisse.';

  @override
  String get chatSuggestedMeetingPoints => 'Empfohlene Treffpunkte in der Nähe';

  @override
  String get chatPickDate => 'Datum wählen';

  @override
  String get chatPickTime => 'Uhrzeit wählen';

  @override
  String get wishlistTitle => 'Wunschliste';

  @override
  String get wishlistEmpty =>
      'Du hast noch keine Bücher zu deiner Wunschliste hinzugefügt.';

  @override
  String get wishlistLoadError =>
      'Deine Wunschliste konnte nicht geladen werden.';

  @override
  String get notificationsTitle => 'Benachrichtigungen';

  @override
  String get notificationsMarkAllRead => 'Alle als gelesen markieren';

  @override
  String get notificationsEmpty => 'Du hast keine Benachrichtigungen.';

  @override
  String get notificationsLoadError =>
      'Deine Benachrichtigungen konnten nicht geladen werden.';

  @override
  String get timeJustNow => 'gerade eben';

  @override
  String timeMinutesAgo(int minutes) {
    return 'vor $minutes Min';
  }

  @override
  String timeHoursAgo(int hours) {
    return 'vor $hours Std';
  }

  @override
  String timeDaysAgo(int days) {
    return 'vor $days Tagen';
  }

  @override
  String get safetyCenterTitle => 'Sicherheitscenter';

  @override
  String get safetyCenterIntro =>
      'Ein paar einfache Regeln, damit Tausche auf ShelfShare angenehm und sicher bleiben.';

  @override
  String get safetyTip1Title => 'Trefft euch tagsüber';

  @override
  String get safetyTip1Desc =>
      'Plane den Tausch für eine Zeit mit natürlichem Tageslicht, idealerweise morgens oder nachmittags.';

  @override
  String get safetyTip2Title => 'Wähle einen öffentlichen Ort';

  @override
  String get safetyTip2Desc =>
      'Ein Café, eine Buchhandlung oder ein Einkaufszentrum sind sicherer als eine private Adresse.';

  @override
  String get safetyTip3Title => 'Bevorzuge videoüberwachte Orte';

  @override
  String get safetyTip3Desc =>
      'Bereiche mit Sicherheitskameras schrecken unangenehmes Verhalten ab.';

  @override
  String get safetyTip4Title => 'Teile keine persönlichen Daten';

  @override
  String get safetyTip4Desc =>
      'Du musst deine Heimatadresse, Ausweisnummer oder andere sensible Daten für einen Tausch nicht angeben.';

  @override
  String get safetyTip5Title => 'Prüfe Bewertung und Vertrauens-Score';

  @override
  String get safetyTip5Desc =>
      'Eine gute Historie abgeschlossener Tausche ist ein gutes Zeichen, bevor du dich mit jemandem triffst.';

  @override
  String get safetyTip6Title => 'Ein echtes Profilfoto schafft Vertrauen';

  @override
  String get safetyTip6Desc =>
      'Profile mit Foto und vollständiger Bio wirken auf andere Nutzer vertrauenswürdiger.';

  @override
  String get safetyTip7Title => 'Prüfe den Zustand des Buches vor dem Tausch';

  @override
  String get safetyTip7Desc =>
      'Vergleiche das Buch mit der Beschreibung der Anzeige, bevor du den Tausch als abgeschlossen bestätigst.';

  @override
  String get safetyTip8Title => 'Melde jedes verdächtige Verhalten';

  @override
  String get safetyTip8Desc =>
      'Du kannst einen Nutzer direkt über sein Profil oder aus der Unterhaltung heraus melden oder blockieren.';

  @override
  String get helpCenterTitle => 'Häufige Fragen';

  @override
  String get helpFaq1Question => 'Wie funktioniert ein Büchertausch?';

  @override
  String get helpFaq1Answer =>
      'Du fragst ein Buch aus der Anzeige einer anderen Person an (du kannst auch ein Buch im Tausch anbieten), der Besitzer nimmt an oder lehnt ab, dann vereinbart ihr ein Treffen per Chat. Nachdem ihr den Tausch persönlich abgeschlossen habt, markiert einer von euch den Tausch als abgeschlossen.';

  @override
  String get helpFaq2Question => 'Was ist der Vertrauens-Score?';

  @override
  String get helpFaq2Answer =>
      'Ein automatisch berechneter Indikator von 0-100 aus der App-Aktivität: Kontoalter, bestätigte E-Mail, Anzahl abgeschlossener Tausche, erhaltene Bewertung, wie oft du antwortest und wie selten du Anfragen stornierst. Es ist keine Identitätsprüfung, nur ein Verhaltenssignal.';

  @override
  String get helpFaq3Question => 'Wie wird der „Buchhandelspreis” berechnet?';

  @override
  String get helpFaq3Answer =>
      'Wenn du ein Buch mit ISBN hinzufügst, versuchen wir, den Listenpreis bei Google Books zu finden. Die Abdeckung ist teilweise - nicht alle Bücher haben dort einen verfügbaren Preis, besonders ältere oder rumänische Ausgaben.';

  @override
  String get helpFaq4Question =>
      'Was bedeutet „Festpreis, nicht verhandelbar”?';

  @override
  String get helpFaq4Answer =>
      'Wenn der Verkäufer dies markiert, können Käufer keine Preisangebote mehr senden - das Buch kann nur zum angegebenen Preis gekauft werden.';

  @override
  String get helpFaq5Question => 'Wie melde oder blockiere ich einen Nutzer?';

  @override
  String get helpFaq5Answer =>
      'Über das Menü oben rechts in einer Unterhaltung oder über die Detailseite einer Anzeige (Flaggen-Symbol). Blockieren stoppt Nachrichten in beide Richtungen.';

  @override
  String get helpFaq6Question =>
      'Was passiert mit dem Buch, nachdem ich es verkauft oder getauscht habe?';

  @override
  String get helpFaq6Answer =>
      'Die Anzeige wird dauerhaft nicht mehr verfügbar. Wenn die Person, die es erhalten hat, es erneut listen möchte, kann sie das über den Bereich Tausche/Angebote tun (\"Zu deiner Bibliothek hinzufügen\") - die Historie des Buches bleibt auf seiner Detailseite nachvollziehbar, mit Fotos von jedem Besitzer.';

  @override
  String get helpFaq7Question =>
      'Warum erscheint ein Buch nicht in Kategorien oder bei Ähnlichen Büchern?';

  @override
  String get helpFaq7Answer =>
      'Das Genre eines Buches stammt beim Hinzufügen von Open Library oder Google Books - manche Bücher haben dort kein Genre hinterlegt, besonders weniger populäre Ausgaben.';

  @override
  String get helpCenterFooter =>
      'Keine Antwort gefunden? Du kannst ein Problem direkt aus der Unterhaltung mit der betroffenen Person melden.';

  @override
  String get adminLoadError => 'Die Admin-Daten konnten nicht geladen werden.';

  @override
  String get adminStatsTitle => 'Statistiken';

  @override
  String adminUsersCount(int count) {
    return 'Nutzer ($count)';
  }

  @override
  String adminInactiveListingsCount(int count) {
    return 'Anzeigen ohne Anfragen ($count)';
  }

  @override
  String get adminInactiveListingsDesc =>
      'Zum Tausch gelistete Bücher, für die noch niemand eine Anfrage gesendet hat.';

  @override
  String get adminNoInactiveListings => 'Keine inaktiven Anzeigen.';

  @override
  String adminUserReportsCount(int count) {
    return 'Nutzermeldungen ($count)';
  }

  @override
  String get adminNoReports => 'Keine Meldungen.';

  @override
  String adminUpcomingReleasesCount(int count) {
    return 'Kommende Bücher ($count)';
  }

  @override
  String get adminUpcomingReleasesDesc =>
      'Wird auf der Startseite im Bereich \"Kommende Bücher\" angezeigt.';

  @override
  String get adminNoUpcomingReleases =>
      'Noch keine kommenden Bücher hinzugefügt.';

  @override
  String adminFeedbackCount(int count) {
    return 'Erhaltenes Feedback ($count)';
  }

  @override
  String get adminNoFeedback => 'Noch kein Feedback gesendet.';

  @override
  String adminSupportRequestsCount(int count) {
    return 'Support-Nachrichten ($count)';
  }

  @override
  String get adminNoSupportRequests =>
      'Noch keine Support-Nachrichten gesendet.';

  @override
  String adminReportedBy(String name) {
    return 'Gemeldet von $name';
  }

  @override
  String get adminUnknownAuthor => 'Unbekannter Autor';

  @override
  String get adminAuthorOptional => 'Autor (optional)';

  @override
  String get adminCoverUrlOptional => 'Cover-URL (optional)';

  @override
  String get adminPickReleaseDate => 'Erscheinungsdatum wählen';

  @override
  String adminReleaseDateLabel(String date) {
    return 'Erscheinung: $date';
  }

  @override
  String get adminAdd => 'Hinzufügen';

  @override
  String get adminTitleDateRequired =>
      'Titel und Erscheinungsdatum sind erforderlich';

  @override
  String get adminAddBookError => 'Das Buch konnte nicht hinzugefügt werden';

  @override
  String get adminDeleteUserTitle => 'Nutzer löschen?';

  @override
  String adminDeleteUserBody(String name) {
    return 'Dies löscht das Konto von $name und alle zugehörigen Daten (Bücher, Tausche, Nachrichten) dauerhaft. Dies kann nicht rückgängig gemacht werden.';
  }

  @override
  String get adminStatsUsersLabel => 'Nutzer';

  @override
  String adminStatsUsersSubtitle(int count) {
    return 'davon $count bestätigt';
  }

  @override
  String get adminStatsBooksLabel => 'Bücher im Katalog';

  @override
  String adminStatsBooksSubtitle(int count) {
    return '$count gelistete Exemplare';
  }

  @override
  String get adminStatsExchangesLabel => 'Tausche';

  @override
  String adminStatsExchangesSubtitle(int completed, int pending) {
    return '$completed abgeschlossen · $pending ausstehend';
  }

  @override
  String get auctionTitle => 'Auktion';

  @override
  String get auctionCurrentPrice => 'Aktueller Preis';

  @override
  String get auctionBidsCount => 'Gebote';

  @override
  String get auctionReserveMet => 'Der Mindestpreis wurde erreicht';

  @override
  String get auctionReserveNotMet =>
      'Der Mindestpreis wurde noch nicht erreicht';

  @override
  String get auctionEndedWithWinner =>
      'Die Auktion ist beendet - jemand hat gewonnen';

  @override
  String get auctionEndedNoWinner => 'Die Auktion endete ohne Gewinner';

  @override
  String auctionBidAmountLabel(String amount) {
    return 'Gebot (mindestens $amount lei)';
  }

  @override
  String get auctionPlaceBid => 'Bieten';

  @override
  String auctionBuyNowFor(String amount) {
    return 'Sofort kaufen für $amount lei';
  }

  @override
  String get auctionBidHistory => 'Gebotshistorie';

  @override
  String get auctionNoBidsYet => 'Noch keine Gebote';

  @override
  String get auctionWatch => 'Auktion beobachten';

  @override
  String get auctionBidPlaced => 'Gebot abgegeben';

  @override
  String get auctionBoughtNow => 'Erfolgreich gekauft';

  @override
  String get auctionGenericError =>
      'Etwas ist schiefgelaufen, versuch es erneut';

  @override
  String get auctionEnded => 'Beendet';

  @override
  String auctionEndsInDays(int days) {
    return 'endet in $days Tagen';
  }

  @override
  String auctionEndsInHours(int hours) {
    return 'endet in $hours Std';
  }

  @override
  String auctionEndsInMinutes(int minutes) {
    return 'endet in $minutes Min';
  }
}
