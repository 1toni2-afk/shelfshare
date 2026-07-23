import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_de.dart';
import 'app_localizations_en.dart';
import 'app_localizations_hu.dart';
import 'app_localizations_ro.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('de'),
    Locale('en'),
    Locale('hu'),
    Locale('ro'),
  ];

  /// No description provided for @navHome.
  ///
  /// In ro, this message translates to:
  /// **'Acasă'**
  String get navHome;

  /// No description provided for @navSearch.
  ///
  /// In ro, this message translates to:
  /// **'Caută'**
  String get navSearch;

  /// No description provided for @navLibrary.
  ///
  /// In ro, this message translates to:
  /// **'Biblioteca'**
  String get navLibrary;

  /// No description provided for @navChat.
  ///
  /// In ro, this message translates to:
  /// **'Chat'**
  String get navChat;

  /// No description provided for @navProfile.
  ///
  /// In ro, this message translates to:
  /// **'Profil'**
  String get navProfile;

  /// No description provided for @commonCancel.
  ///
  /// In ro, this message translates to:
  /// **'Anulează'**
  String get commonCancel;

  /// No description provided for @commonSubmit.
  ///
  /// In ro, this message translates to:
  /// **'Trimite'**
  String get commonSubmit;

  /// No description provided for @commonSave.
  ///
  /// In ro, this message translates to:
  /// **'Salvează'**
  String get commonSave;

  /// No description provided for @commonSeeAll.
  ///
  /// In ro, this message translates to:
  /// **'Vezi tot'**
  String get commonSeeAll;

  /// No description provided for @commonUnknownUser.
  ///
  /// In ro, this message translates to:
  /// **'Utilizator'**
  String get commonUnknownUser;

  /// No description provided for @commonAbout.
  ///
  /// In ro, this message translates to:
  /// **'Despre'**
  String get commonAbout;

  /// No description provided for @commonRating.
  ///
  /// In ro, this message translates to:
  /// **'Rating'**
  String get commonRating;

  /// No description provided for @commonBooksExchanged.
  ///
  /// In ro, this message translates to:
  /// **'Cărți schimbate'**
  String get commonBooksExchanged;

  /// No description provided for @commonRetry.
  ///
  /// In ro, this message translates to:
  /// **'Încearcă din nou'**
  String get commonRetry;

  /// No description provided for @commonClose.
  ///
  /// In ro, this message translates to:
  /// **'Închide'**
  String get commonClose;

  /// No description provided for @commonDelete.
  ///
  /// In ro, this message translates to:
  /// **'Șterge'**
  String get commonDelete;

  /// No description provided for @commonConfirm.
  ///
  /// In ro, this message translates to:
  /// **'Confirmă'**
  String get commonConfirm;

  /// No description provided for @continueWithGoogle.
  ///
  /// In ro, this message translates to:
  /// **'Continuă cu Google'**
  String get continueWithGoogle;

  /// No description provided for @reportDialogTitle.
  ///
  /// In ro, this message translates to:
  /// **'Raportează'**
  String get reportDialogTitle;

  /// No description provided for @trustScoreTitle.
  ///
  /// In ro, this message translates to:
  /// **'Scor de încredere'**
  String get trustScoreTitle;

  /// No description provided for @trustScoreSubtitle.
  ///
  /// In ro, this message translates to:
  /// **'Calculat din activitatea din aplicație, nu e o verificare de identitate'**
  String get trustScoreSubtitle;

  /// No description provided for @trustScoreEmailVerified.
  ///
  /// In ro, this message translates to:
  /// **'Email verificat'**
  String get trustScoreEmailVerified;

  /// No description provided for @trustScoreCompletedRate.
  ///
  /// In ro, this message translates to:
  /// **'{percent}% schimburi finalizate'**
  String trustScoreCompletedRate(int percent);

  /// No description provided for @trustScoreRespondsIn.
  ///
  /// In ro, this message translates to:
  /// **'Răspunde în ~{time}'**
  String trustScoreRespondsIn(String time);

  /// No description provided for @trustScoreLastActiveToday.
  ///
  /// In ro, this message translates to:
  /// **'Activ astăzi'**
  String get trustScoreLastActiveToday;

  /// No description provided for @trustScoreLastActiveDays.
  ///
  /// In ro, this message translates to:
  /// **'Activ acum {days} zile'**
  String trustScoreLastActiveDays(int days);

  /// No description provided for @trustScoreResponseRate.
  ///
  /// In ro, this message translates to:
  /// **'{percent}% rată de răspuns'**
  String trustScoreResponseRate(int percent);

  /// No description provided for @trustScoreAverageSwapTime.
  ///
  /// In ro, this message translates to:
  /// **'Schimb finalizat în ~{time}'**
  String trustScoreAverageSwapTime(String time);

  /// No description provided for @memberSinceDays.
  ///
  /// In ro, this message translates to:
  /// **'Membru din {days} zile'**
  String memberSinceDays(int days);

  /// No description provided for @memberSinceMonths.
  ///
  /// In ro, this message translates to:
  /// **'Membru de {months} luni'**
  String memberSinceMonths(int months);

  /// No description provided for @memberSinceYears.
  ///
  /// In ro, this message translates to:
  /// **'Membru de {years} ani'**
  String memberSinceYears(int years);

  /// No description provided for @durationMinutes.
  ///
  /// In ro, this message translates to:
  /// **'{minutes} min'**
  String durationMinutes(int minutes);

  /// No description provided for @durationHours.
  ///
  /// In ro, this message translates to:
  /// **'{hours}h'**
  String durationHours(int hours);

  /// No description provided for @durationDays.
  ///
  /// In ro, this message translates to:
  /// **'{days} zile'**
  String durationDays(int days);

  /// No description provided for @priceLei.
  ///
  /// In ro, this message translates to:
  /// **'{amount} lei'**
  String priceLei(String amount);

  /// No description provided for @commonEmailLabel.
  ///
  /// In ro, this message translates to:
  /// **'Email'**
  String get commonEmailLabel;

  /// No description provided for @commonEmailInvalid.
  ///
  /// In ro, this message translates to:
  /// **'Email invalid'**
  String get commonEmailInvalid;

  /// No description provided for @commonOr.
  ///
  /// In ro, this message translates to:
  /// **'sau'**
  String get commonOr;

  /// No description provided for @commonRequired.
  ///
  /// In ro, this message translates to:
  /// **'Obligatoriu'**
  String get commonRequired;

  /// No description provided for @commonContinue.
  ///
  /// In ro, this message translates to:
  /// **'Continuă'**
  String get commonContinue;

  /// No description provided for @loginWelcomeBack.
  ///
  /// In ro, this message translates to:
  /// **'Bun venit înapoi'**
  String get loginWelcomeBack;

  /// No description provided for @authPasswordLabel.
  ///
  /// In ro, this message translates to:
  /// **'Parolă'**
  String get authPasswordLabel;

  /// No description provided for @authEnterPasswordError.
  ///
  /// In ro, this message translates to:
  /// **'Introdu parola'**
  String get authEnterPasswordError;

  /// No description provided for @authMinEightChars.
  ///
  /// In ro, this message translates to:
  /// **'Minim 8 caractere'**
  String get authMinEightChars;

  /// No description provided for @authForgotPasswordLink.
  ///
  /// In ro, this message translates to:
  /// **'Ai uitat parola?'**
  String get authForgotPasswordLink;

  /// No description provided for @authLoginSubmit.
  ///
  /// In ro, this message translates to:
  /// **'Autentificare'**
  String get authLoginSubmit;

  /// No description provided for @authNoAccount.
  ///
  /// In ro, this message translates to:
  /// **'Nu ai cont? '**
  String get authNoAccount;

  /// No description provided for @authCreateOne.
  ///
  /// In ro, this message translates to:
  /// **'Creează unul'**
  String get authCreateOne;

  /// No description provided for @authGoogleFailed.
  ///
  /// In ro, this message translates to:
  /// **'Autentificarea cu Google a eșuat. Încearcă din nou.'**
  String get authGoogleFailed;

  /// No description provided for @supportContactButton.
  ///
  /// In ro, this message translates to:
  /// **'Nu te poți loga? Contactează-ne'**
  String get supportContactButton;

  /// No description provided for @supportDialogTitle.
  ///
  /// In ro, this message translates to:
  /// **'Contactează support'**
  String get supportDialogTitle;

  /// No description provided for @supportDialogSubtitle.
  ///
  /// In ro, this message translates to:
  /// **'Spune-ne ce problemă ai și îți răspundem pe email.'**
  String get supportDialogSubtitle;

  /// No description provided for @supportNameLabel.
  ///
  /// In ro, this message translates to:
  /// **'Nume'**
  String get supportNameLabel;

  /// No description provided for @supportPhoneLabel.
  ///
  /// In ro, this message translates to:
  /// **'Telefon (opțional)'**
  String get supportPhoneLabel;

  /// No description provided for @supportMessageLabel.
  ///
  /// In ro, this message translates to:
  /// **'Mesajul tău'**
  String get supportMessageLabel;

  /// No description provided for @supportCaptchaAnswerLabel.
  ///
  /// In ro, this message translates to:
  /// **'Răspunsul tău'**
  String get supportCaptchaAnswerLabel;

  /// No description provided for @supportSubmit.
  ///
  /// In ro, this message translates to:
  /// **'Trimite mesajul'**
  String get supportSubmit;

  /// No description provided for @supportSuccessMessage.
  ///
  /// In ro, this message translates to:
  /// **'Mesaj trimis! Îți răspundem cât mai curând pe email.'**
  String get supportSuccessMessage;

  /// No description provided for @supportGenericError.
  ///
  /// In ro, this message translates to:
  /// **'Nu am putut trimite mesajul. Încearcă din nou.'**
  String get supportGenericError;

  /// No description provided for @authRegisterTitle.
  ///
  /// In ro, this message translates to:
  /// **'Creează cont'**
  String get authRegisterTitle;

  /// No description provided for @authRegisterSubtitle.
  ///
  /// In ro, this message translates to:
  /// **'Alătură-te comunității ShelfShare'**
  String get authRegisterSubtitle;

  /// No description provided for @authReferralCodeLabel.
  ///
  /// In ro, this message translates to:
  /// **'Cod de invitație (opțional)'**
  String get authReferralCodeLabel;

  /// No description provided for @verifyCodeTooShort.
  ///
  /// In ro, this message translates to:
  /// **'Codul trebuie să aibă 6 cifre'**
  String get verifyCodeTooShort;

  /// No description provided for @verifySuccessSnackbar.
  ///
  /// In ro, this message translates to:
  /// **'Cont confirmat cu succes!'**
  String get verifySuccessSnackbar;

  /// No description provided for @verifyInvalidOrExpired.
  ///
  /// In ro, this message translates to:
  /// **'Cod invalid sau expirat.'**
  String get verifyInvalidOrExpired;

  /// No description provided for @verifyResendSnackbar.
  ///
  /// In ro, this message translates to:
  /// **'Am retrimis codul, dacă e cazul.'**
  String get verifyResendSnackbar;

  /// No description provided for @verifyEmailHeading.
  ///
  /// In ro, this message translates to:
  /// **'Verifică-ți emailul'**
  String get verifyEmailHeading;

  /// No description provided for @verifySentTo.
  ///
  /// In ro, this message translates to:
  /// **'Ți-am trimis un cod de confirmare pe {email}'**
  String verifySentTo(String email);

  /// No description provided for @verifyConfirmButton.
  ///
  /// In ro, this message translates to:
  /// **'Confirmă'**
  String get verifyConfirmButton;

  /// No description provided for @verifyResending.
  ///
  /// In ro, this message translates to:
  /// **'Se retrimite...'**
  String get verifyResending;

  /// No description provided for @verifyResendPrompt.
  ///
  /// In ro, this message translates to:
  /// **'Nu ai primit codul? Retrimite'**
  String get verifyResendPrompt;

  /// No description provided for @forgotPasswordTitle.
  ///
  /// In ro, this message translates to:
  /// **'Resetează parola'**
  String get forgotPasswordTitle;

  /// No description provided for @forgotPasswordSubtitle.
  ///
  /// In ro, this message translates to:
  /// **'Îți trimitem un cod de resetare pe email.'**
  String get forgotPasswordSubtitle;

  /// No description provided for @forgotPasswordSubmit.
  ///
  /// In ro, this message translates to:
  /// **'Trimite cod'**
  String get forgotPasswordSubmit;

  /// No description provided for @forgotPasswordCodeHeading.
  ///
  /// In ro, this message translates to:
  /// **'Introdu codul primit pe email'**
  String get forgotPasswordCodeHeading;

  /// No description provided for @forgotPasswordCodeSentTo.
  ///
  /// In ro, this message translates to:
  /// **'Ți-am trimis un cod de resetare pe {email}'**
  String forgotPasswordCodeSentTo(String email);

  /// No description provided for @resetPasswordTitle.
  ///
  /// In ro, this message translates to:
  /// **'Setează o parolă nouă'**
  String get resetPasswordTitle;

  /// No description provided for @resetPasswordSubtitle.
  ///
  /// In ro, this message translates to:
  /// **'Alege o parolă nouă pentru contul tău'**
  String get resetPasswordSubtitle;

  /// No description provided for @resetPasswordNewLabel.
  ///
  /// In ro, this message translates to:
  /// **'Parolă nouă'**
  String get resetPasswordNewLabel;

  /// No description provided for @resetPasswordSubmit.
  ///
  /// In ro, this message translates to:
  /// **'Setează parola'**
  String get resetPasswordSubmit;

  /// No description provided for @resetPasswordSuccessHeading.
  ///
  /// In ro, this message translates to:
  /// **'Parolă schimbată'**
  String get resetPasswordSuccessHeading;

  /// No description provided for @resetPasswordSuccessBody.
  ///
  /// In ro, this message translates to:
  /// **'Parola ta a fost actualizată. Te poți autentifica acum.'**
  String get resetPasswordSuccessBody;

  /// No description provided for @resetPasswordGoToLogin.
  ///
  /// In ro, this message translates to:
  /// **'Mergi la autentificare'**
  String get resetPasswordGoToLogin;

  /// No description provided for @resetPasswordGenericError.
  ///
  /// In ro, this message translates to:
  /// **'Nu am putut reseta parola. Încearcă din nou.'**
  String get resetPasswordGenericError;

  /// No description provided for @authConfirmPasswordLabel.
  ///
  /// In ro, this message translates to:
  /// **'Confirmă parola'**
  String get authConfirmPasswordLabel;

  /// No description provided for @authPasswordMismatch.
  ///
  /// In ro, this message translates to:
  /// **'Parolele nu coincid'**
  String get authPasswordMismatch;

  /// No description provided for @onboardingTitle.
  ///
  /// In ro, this message translates to:
  /// **'Aproape gata!'**
  String get onboardingTitle;

  /// No description provided for @onboardingSubtitle.
  ///
  /// In ro, this message translates to:
  /// **'Spune-ne cum vrei să te vadă ceilalți'**
  String get onboardingSubtitle;

  /// No description provided for @onboardingFirstName.
  ///
  /// In ro, this message translates to:
  /// **'Prenume'**
  String get onboardingFirstName;

  /// No description provided for @onboardingLastName.
  ///
  /// In ro, this message translates to:
  /// **'Nume'**
  String get onboardingLastName;

  /// No description provided for @onboardingUsername.
  ///
  /// In ro, this message translates to:
  /// **'Username'**
  String get onboardingUsername;

  /// No description provided for @onboardingUsernameFormatError.
  ///
  /// In ro, this message translates to:
  /// **'3-20 caractere: litere, cifre sau underscore'**
  String get onboardingUsernameFormatError;

  /// No description provided for @onboardingGenericError.
  ///
  /// In ro, this message translates to:
  /// **'A apărut o eroare. Încearcă din nou.'**
  String get onboardingGenericError;

  /// No description provided for @onboardingNameVisibleSwitch.
  ///
  /// In ro, this message translates to:
  /// **'Fă numele vizibil public'**
  String get onboardingNameVisibleSwitch;

  /// No description provided for @onboardingUsernameAlwaysVisible.
  ///
  /// In ro, this message translates to:
  /// **'Username-ul rămâne mereu vizibil'**
  String get onboardingUsernameAlwaysVisible;

  /// No description provided for @profileTitle.
  ///
  /// In ro, this message translates to:
  /// **'Profilul meu'**
  String get profileTitle;

  /// No description provided for @profileCopyLink.
  ///
  /// In ro, this message translates to:
  /// **'Copiază linkul'**
  String get profileCopyLink;

  /// No description provided for @profileLoadError.
  ///
  /// In ro, this message translates to:
  /// **'Nu am putut încărca profilul.'**
  String get profileLoadError;

  /// No description provided for @profileAboutMe.
  ///
  /// In ro, this message translates to:
  /// **'Despre mine'**
  String get profileAboutMe;

  /// No description provided for @profileBadgesTitle.
  ///
  /// In ro, this message translates to:
  /// **'Insigne'**
  String get profileBadgesTitle;

  /// No description provided for @profileMyExchanges.
  ///
  /// In ro, this message translates to:
  /// **'Schimburile mele'**
  String get profileMyExchanges;

  /// No description provided for @profileSafetyCenter.
  ///
  /// In ro, this message translates to:
  /// **'Centru de siguranță'**
  String get profileSafetyCenter;

  /// No description provided for @profileHelpCenter.
  ///
  /// In ro, this message translates to:
  /// **'Întrebări frecvente'**
  String get profileHelpCenter;

  /// No description provided for @profileLeaderboard.
  ///
  /// In ro, this message translates to:
  /// **'Clasament'**
  String get profileLeaderboard;

  /// No description provided for @profileSendFeedback.
  ///
  /// In ro, this message translates to:
  /// **'Trimite feedback'**
  String get profileSendFeedback;

  /// No description provided for @profileEditProfile.
  ///
  /// In ro, this message translates to:
  /// **'Editează profilul'**
  String get profileEditProfile;

  /// No description provided for @profileAdminPanel.
  ///
  /// In ro, this message translates to:
  /// **'Panou de administrare'**
  String get profileAdminPanel;

  /// No description provided for @profileLogout.
  ///
  /// In ro, this message translates to:
  /// **'Deconectare'**
  String get profileLogout;

  /// No description provided for @profileLanguage.
  ///
  /// In ro, this message translates to:
  /// **'Limbă'**
  String get profileLanguage;

  /// No description provided for @profileDarkModeSection.
  ///
  /// In ro, this message translates to:
  /// **'Mod întunecat'**
  String get profileDarkModeSection;

  /// No description provided for @profileThemeSystem.
  ///
  /// In ro, this message translates to:
  /// **'Automat (sistem)'**
  String get profileThemeSystem;

  /// No description provided for @profileThemeLight.
  ///
  /// In ro, this message translates to:
  /// **'Deschis'**
  String get profileThemeLight;

  /// No description provided for @profileThemeDark.
  ///
  /// In ro, this message translates to:
  /// **'Întunecat'**
  String get profileThemeDark;

  /// No description provided for @profileQrTooltip.
  ///
  /// In ro, this message translates to:
  /// **'Cod QR'**
  String get profileQrTooltip;

  /// No description provided for @profileQrDialogTitle.
  ///
  /// In ro, this message translates to:
  /// **'Codul tău QR'**
  String get profileQrDialogTitle;

  /// No description provided for @profileQrDialogBody.
  ///
  /// In ro, this message translates to:
  /// **'Oricine scanează acest cod îți poate deschide profilul.'**
  String get profileQrDialogBody;

  /// No description provided for @profileReferralTitle.
  ///
  /// In ro, this message translates to:
  /// **'Codul tău de invitație'**
  String get profileReferralTitle;

  /// No description provided for @profileReferralSubtitle.
  ///
  /// In ro, this message translates to:
  /// **'Trimite-l prietenilor ca să te descopere pe ShelfShare'**
  String get profileReferralSubtitle;

  /// No description provided for @profileReferralCountLabel.
  ///
  /// In ro, this message translates to:
  /// **'{count} prieteni invitați'**
  String profileReferralCountLabel(int count);

  /// No description provided for @profileReferralCopied.
  ///
  /// In ro, this message translates to:
  /// **'Cod copiat în clipboard'**
  String get profileReferralCopied;

  /// No description provided for @profileFeedbackHint.
  ///
  /// In ro, this message translates to:
  /// **'Ce ai vrea să ne spui?'**
  String get profileFeedbackHint;

  /// No description provided for @profileFeedbackThanks.
  ///
  /// In ro, this message translates to:
  /// **'Mulțumim pentru feedback!'**
  String get profileFeedbackThanks;

  /// No description provided for @profileFeedbackError.
  ///
  /// In ro, this message translates to:
  /// **'Nu am putut trimite feedback-ul'**
  String get profileFeedbackError;

  /// No description provided for @profileUsernameLabel.
  ///
  /// In ro, this message translates to:
  /// **'Username'**
  String get profileUsernameLabel;

  /// No description provided for @profileCityLabel.
  ///
  /// In ro, this message translates to:
  /// **'Oraș'**
  String get profileCityLabel;

  /// No description provided for @profileNoCity.
  ///
  /// In ro, this message translates to:
  /// **'Fără oraș'**
  String get profileNoCity;

  /// No description provided for @profileShowAcquisitionHistory.
  ///
  /// In ro, this message translates to:
  /// **'Arată istoricul de achiziții pe profil'**
  String get profileShowAcquisitionHistory;

  /// No description provided for @profileShowAcquisitionHistorySubtitle.
  ///
  /// In ro, this message translates to:
  /// **'Cărțile pe care le-ai primit prin schimburi sau cumpărături din aplicație'**
  String get profileShowAcquisitionHistorySubtitle;

  /// No description provided for @profileSaveError.
  ///
  /// In ro, this message translates to:
  /// **'Nu am putut salva profilul.'**
  String get profileSaveError;

  /// No description provided for @commonSendMessage.
  ///
  /// In ro, this message translates to:
  /// **'Trimite mesaj'**
  String get commonSendMessage;

  /// No description provided for @publicProfileTitle.
  ///
  /// In ro, this message translates to:
  /// **'Profil'**
  String get publicProfileTitle;

  /// No description provided for @publicProfileFollowUpdateError.
  ///
  /// In ro, this message translates to:
  /// **'Nu am putut actualiza urmărirea'**
  String get publicProfileFollowUpdateError;

  /// No description provided for @publicProfileMessageError.
  ///
  /// In ro, this message translates to:
  /// **'Nu am putut porni conversația.'**
  String get publicProfileMessageError;

  /// No description provided for @publicProfileMemberSince.
  ///
  /// In ro, this message translates to:
  /// **'Membru din {year}'**
  String publicProfileMemberSince(int year);

  /// No description provided for @publicProfileFollowersFollowing.
  ///
  /// In ro, this message translates to:
  /// **'{followers} urmăritori · {following} urmăriți'**
  String publicProfileFollowersFollowing(int followers, int following);

  /// No description provided for @publicProfileUnfollow.
  ///
  /// In ro, this message translates to:
  /// **'Nu mai urmări'**
  String get publicProfileUnfollow;

  /// No description provided for @publicProfileFollow.
  ///
  /// In ro, this message translates to:
  /// **'Urmărește'**
  String get publicProfileFollow;

  /// No description provided for @publicProfileReadingStats.
  ///
  /// In ro, this message translates to:
  /// **'Statistici de citit'**
  String get publicProfileReadingStats;

  /// No description provided for @publicProfileBooksListed.
  ///
  /// In ro, this message translates to:
  /// **'Cărți listate'**
  String get publicProfileBooksListed;

  /// No description provided for @publicProfileTotalPages.
  ///
  /// In ro, this message translates to:
  /// **'Total pagini'**
  String get publicProfileTotalPages;

  /// No description provided for @publicProfileFavoriteGenre.
  ///
  /// In ro, this message translates to:
  /// **'Gen preferat'**
  String get publicProfileFavoriteGenre;

  /// No description provided for @publicProfileBooksShared.
  ///
  /// In ro, this message translates to:
  /// **'Cărți date'**
  String get publicProfileBooksShared;

  /// No description provided for @publicProfileBooksReceived.
  ///
  /// In ro, this message translates to:
  /// **'Cărți primite'**
  String get publicProfileBooksReceived;

  /// No description provided for @publicProfileLongestBook.
  ///
  /// In ro, this message translates to:
  /// **'Cea mai lungă carte'**
  String get publicProfileLongestBook;

  /// No description provided for @publicProfileListedBooksCount.
  ///
  /// In ro, this message translates to:
  /// **'Cărți listate ({count})'**
  String publicProfileListedBooksCount(int count);

  /// No description provided for @publicProfileAcquisitionHistory.
  ///
  /// In ro, this message translates to:
  /// **'Istoric cărți primite prin aplicație'**
  String get publicProfileAcquisitionHistory;

  /// No description provided for @publicProfileNoAcquisitions.
  ///
  /// In ro, this message translates to:
  /// **'Niciun schimb sau cumpărare finalizată încă.'**
  String get publicProfileNoAcquisitions;

  /// No description provided for @publicProfileReviewsCount.
  ///
  /// In ro, this message translates to:
  /// **'Recenzii ({count})'**
  String publicProfileReviewsCount(int count);

  /// No description provided for @leaderboardEmpty.
  ///
  /// In ro, this message translates to:
  /// **'Niciun oraș cu activitate încă.'**
  String get leaderboardEmpty;

  /// No description provided for @leaderboardUnknownCity.
  ///
  /// In ro, this message translates to:
  /// **'Necunoscut'**
  String get leaderboardUnknownCity;

  /// No description provided for @leaderboardExchangesCount.
  ///
  /// In ro, this message translates to:
  /// **'{count} schimburi'**
  String leaderboardExchangesCount(int count);

  /// No description provided for @leaderboardLoadError.
  ///
  /// In ro, this message translates to:
  /// **'Nu am putut încărca clasamentul.'**
  String get leaderboardLoadError;

  /// No description provided for @leaderboardTabCity.
  ///
  /// In ro, this message translates to:
  /// **'Pe orașe'**
  String get leaderboardTabCity;

  /// No description provided for @leaderboardTabNational.
  ///
  /// In ro, this message translates to:
  /// **'Național'**
  String get leaderboardTabNational;

  /// No description provided for @leaderboardTabTopReaders.
  ///
  /// In ro, this message translates to:
  /// **'Cititori'**
  String get leaderboardTabTopReaders;

  /// No description provided for @leaderboardPagesCount.
  ///
  /// In ro, this message translates to:
  /// **'{count} pagini'**
  String leaderboardPagesCount(int count);

  /// No description provided for @profileGlobalStats.
  ///
  /// In ro, this message translates to:
  /// **'Statistici globale'**
  String get profileGlobalStats;

  /// No description provided for @profileMyBookshelf.
  ///
  /// In ro, this message translates to:
  /// **'Raftul meu'**
  String get profileMyBookshelf;

  /// No description provided for @bookshelfTitle.
  ///
  /// In ro, this message translates to:
  /// **'Raftul meu'**
  String get bookshelfTitle;

  /// No description provided for @bookshelfTabReading.
  ///
  /// In ro, this message translates to:
  /// **'Citesc'**
  String get bookshelfTabReading;

  /// No description provided for @bookshelfTabWantToRead.
  ///
  /// In ro, this message translates to:
  /// **'Vreau să citesc'**
  String get bookshelfTabWantToRead;

  /// No description provided for @bookshelfTabFinished.
  ///
  /// In ro, this message translates to:
  /// **'Terminate'**
  String get bookshelfTabFinished;

  /// No description provided for @bookshelfTabShared.
  ///
  /// In ro, this message translates to:
  /// **'Împărtășite'**
  String get bookshelfTabShared;

  /// No description provided for @bookshelfEmpty.
  ///
  /// In ro, this message translates to:
  /// **'Nicio carte aici încă.'**
  String get bookshelfEmpty;

  /// No description provided for @bookshelfLoadError.
  ///
  /// In ro, this message translates to:
  /// **'Nu am putut încărca raftul.'**
  String get bookshelfLoadError;

  /// No description provided for @bookshelfImportTooltip.
  ///
  /// In ro, this message translates to:
  /// **'Importă din Goodreads sau StoryGraph'**
  String get bookshelfImportTooltip;

  /// No description provided for @bookshelfImportGoodreads.
  ///
  /// In ro, this message translates to:
  /// **'Importă din Goodreads (CSV)'**
  String get bookshelfImportGoodreads;

  /// No description provided for @bookshelfImportStoryGraph.
  ///
  /// In ro, this message translates to:
  /// **'Importă din StoryGraph (CSV)'**
  String get bookshelfImportStoryGraph;

  /// No description provided for @bookshelfImportSummary.
  ///
  /// In ro, this message translates to:
  /// **'{imported} cărți importate, {skipped} sărite'**
  String bookshelfImportSummary(int imported, int skipped);

  /// No description provided for @bookshelfImportError.
  ///
  /// In ro, this message translates to:
  /// **'Nu am putut importa fișierul. Verifică dacă e un export CSV valid.'**
  String get bookshelfImportError;

  /// No description provided for @bookDetailShelfSectionTitle.
  ///
  /// In ro, this message translates to:
  /// **'Adaugă în raftul tău'**
  String get bookDetailShelfSectionTitle;

  /// No description provided for @gamificationLevel.
  ///
  /// In ro, this message translates to:
  /// **'Nivel {level}'**
  String gamificationLevel(int level);

  /// No description provided for @gamificationXp.
  ///
  /// In ro, this message translates to:
  /// **'{xp} XP'**
  String gamificationXp(int xp);

  /// No description provided for @gamificationXpToNextLevel.
  ///
  /// In ro, this message translates to:
  /// **'{xp} XP până la nivelul următor'**
  String gamificationXpToNextLevel(int xp);

  /// No description provided for @gamificationStreak.
  ///
  /// In ro, this message translates to:
  /// **'{days} zile la rând'**
  String gamificationStreak(int days);

  /// No description provided for @gamificationLongestStreak.
  ///
  /// In ro, this message translates to:
  /// **'Record: {days} zile'**
  String gamificationLongestStreak(int days);

  /// No description provided for @profileMonthlyChallenges.
  ///
  /// In ro, this message translates to:
  /// **'Provocări lunare'**
  String get profileMonthlyChallenges;

  /// No description provided for @monthlyChallengesTitle.
  ///
  /// In ro, this message translates to:
  /// **'Provocări lunare'**
  String get monthlyChallengesTitle;

  /// No description provided for @profileReadingChallenge.
  ///
  /// In ro, this message translates to:
  /// **'Provocarea de citit'**
  String get profileReadingChallenge;

  /// No description provided for @readingChallengeTitle.
  ///
  /// In ro, this message translates to:
  /// **'Provocarea de citit {year}'**
  String readingChallengeTitle(int year);

  /// No description provided for @readingChallengeNoGoal.
  ///
  /// In ro, this message translates to:
  /// **'Nu ai setat încă un obiectiv pentru anul acesta.'**
  String get readingChallengeNoGoal;

  /// No description provided for @readingChallengeProgress.
  ///
  /// In ro, this message translates to:
  /// **'{progress} din {goal} cărți terminate'**
  String readingChallengeProgress(int progress, int goal);

  /// No description provided for @readingChallengeSetGoal.
  ///
  /// In ro, this message translates to:
  /// **'Setează un obiectiv'**
  String get readingChallengeSetGoal;

  /// No description provided for @readingChallengeGoalLabel.
  ///
  /// In ro, this message translates to:
  /// **'Câte cărți vrei să termini anul acesta?'**
  String get readingChallengeGoalLabel;

  /// No description provided for @profileActivityFeed.
  ///
  /// In ro, this message translates to:
  /// **'Activitate recentă'**
  String get profileActivityFeed;

  /// No description provided for @activityFeedTitle.
  ///
  /// In ro, this message translates to:
  /// **'Activitate recentă'**
  String get activityFeedTitle;

  /// No description provided for @activityFeedEmpty.
  ///
  /// In ro, this message translates to:
  /// **'Niciun eveniment încă - urmărește alți useri ca să vezi ce citesc.'**
  String get activityFeedEmpty;

  /// No description provided for @activityFeedLoadError.
  ///
  /// In ro, this message translates to:
  /// **'Nu am putut încărca activitatea.'**
  String get activityFeedLoadError;

  /// No description provided for @activityNewListing.
  ///
  /// In ro, this message translates to:
  /// **'{name} a listat o carte nouă'**
  String activityNewListing(String name);

  /// No description provided for @activityFinishedBook.
  ///
  /// In ro, this message translates to:
  /// **'{name} a terminat de citit'**
  String activityFinishedBook(String name);

  /// No description provided for @activityCompletedExchange.
  ///
  /// In ro, this message translates to:
  /// **'{name} a finalizat un schimb'**
  String activityCompletedExchange(String name);

  /// No description provided for @bookDetailShelfRemove.
  ///
  /// In ro, this message translates to:
  /// **'Elimină din raft'**
  String get bookDetailShelfRemove;

  /// No description provided for @publicProfileBookshelfTitle.
  ///
  /// In ro, this message translates to:
  /// **'Raftul de cărți'**
  String get publicProfileBookshelfTitle;

  /// No description provided for @globalStatsTitle.
  ///
  /// In ro, this message translates to:
  /// **'Statistici globale'**
  String get globalStatsTitle;

  /// No description provided for @globalStatsTabMostShared.
  ///
  /// In ro, this message translates to:
  /// **'Cele mai schimbate'**
  String get globalStatsTabMostShared;

  /// No description provided for @globalStatsTabTrending.
  ///
  /// In ro, this message translates to:
  /// **'În tendințe'**
  String get globalStatsTabTrending;

  /// No description provided for @globalStatsTabPopularAuthors.
  ///
  /// In ro, this message translates to:
  /// **'Autori populari'**
  String get globalStatsTabPopularAuthors;

  /// No description provided for @globalStatsEmpty.
  ///
  /// In ro, this message translates to:
  /// **'Nicio dată încă.'**
  String get globalStatsEmpty;

  /// No description provided for @globalStatsLoadError.
  ///
  /// In ro, this message translates to:
  /// **'Nu am putut încărca statisticile.'**
  String get globalStatsLoadError;

  /// No description provided for @globalStatsTransferCount.
  ///
  /// In ro, this message translates to:
  /// **'{count} schimburi/vânzări'**
  String globalStatsTransferCount(int count);

  /// No description provided for @globalStatsViewCount.
  ///
  /// In ro, this message translates to:
  /// **'{count} vizualizări (14 zile)'**
  String globalStatsViewCount(int count);

  /// No description provided for @profileFavoriteSellers.
  ///
  /// In ro, this message translates to:
  /// **'Vânzători favoriți'**
  String get profileFavoriteSellers;

  /// No description provided for @favoriteSellersTitle.
  ///
  /// In ro, this message translates to:
  /// **'Vânzători favoriți'**
  String get favoriteSellersTitle;

  /// No description provided for @favoriteSellersEmpty.
  ///
  /// In ro, this message translates to:
  /// **'Nu urmărești încă niciun utilizator.'**
  String get favoriteSellersEmpty;

  /// No description provided for @favoriteSellersLoadError.
  ///
  /// In ro, this message translates to:
  /// **'Nu am putut încărca lista.'**
  String get favoriteSellersLoadError;

  /// No description provided for @publicProfileTopGenres.
  ///
  /// In ro, this message translates to:
  /// **'Genuri preferate'**
  String get publicProfileTopGenres;

  /// No description provided for @impactStatsTitle.
  ///
  /// In ro, this message translates to:
  /// **'Impact'**
  String get impactStatsTitle;

  /// No description provided for @impactStatsTotalValue.
  ///
  /// In ro, this message translates to:
  /// **'Valoare totală schimbată'**
  String get impactStatsTotalValue;

  /// No description provided for @impactStatsMoneySaved.
  ///
  /// In ro, this message translates to:
  /// **'Bani economisiți'**
  String get impactStatsMoneySaved;

  /// No description provided for @impactStatsCo2Saved.
  ///
  /// In ro, this message translates to:
  /// **'CO₂ economisit (estimativ)'**
  String get impactStatsCo2Saved;

  /// No description provided for @impactStatsCo2Value.
  ///
  /// In ro, this message translates to:
  /// **'{kg} kg'**
  String impactStatsCo2Value(String kg);

  /// No description provided for @homeGreeting.
  ///
  /// In ro, this message translates to:
  /// **'Salut, {name}!'**
  String homeGreeting(String name);

  /// No description provided for @homeWelcome.
  ///
  /// In ro, this message translates to:
  /// **'Bine ai venit!'**
  String get homeWelcome;

  /// No description provided for @homeLoadError.
  ///
  /// In ro, this message translates to:
  /// **'Nu am putut încărca cărțile.'**
  String get homeLoadError;

  /// No description provided for @homeEmpty.
  ///
  /// In ro, this message translates to:
  /// **'Nu există încă cărți disponibile.'**
  String get homeEmpty;

  /// No description provided for @homeCategories.
  ///
  /// In ro, this message translates to:
  /// **'Categorii'**
  String get homeCategories;

  /// No description provided for @homeRecentlyAdded.
  ///
  /// In ro, this message translates to:
  /// **'Adăugate recent'**
  String get homeRecentlyAdded;

  /// No description provided for @homeMostViewed.
  ///
  /// In ro, this message translates to:
  /// **'Cele mai vizualizate'**
  String get homeMostViewed;

  /// No description provided for @homeNearYou.
  ///
  /// In ro, this message translates to:
  /// **'Din orașul tău'**
  String get homeNearYou;

  /// No description provided for @homeNearYouToday.
  ///
  /// In ro, this message translates to:
  /// **'Astăzi, aproape de tine'**
  String get homeNearYouToday;

  /// No description provided for @homeRecommendedForYou.
  ///
  /// In ro, this message translates to:
  /// **'Recomandate pentru tine'**
  String get homeRecommendedForYou;

  /// No description provided for @homeHiddenGems.
  ///
  /// In ro, this message translates to:
  /// **'Comori ascunse'**
  String get homeHiddenGems;

  /// No description provided for @homeCompleteYourCollection.
  ///
  /// In ro, this message translates to:
  /// **'Completează-ți colecția'**
  String get homeCompleteYourCollection;

  /// No description provided for @homeSimilarTaste.
  ///
  /// In ro, this message translates to:
  /// **'Gusturi asemănătoare'**
  String get homeSimilarTaste;

  /// No description provided for @profileSmartMatches.
  ///
  /// In ro, this message translates to:
  /// **'Potriviri de schimb'**
  String get profileSmartMatches;

  /// No description provided for @smartMatchesTitle.
  ///
  /// In ro, this message translates to:
  /// **'Potriviri de schimb'**
  String get smartMatchesTitle;

  /// No description provided for @smartMatchesEmpty.
  ///
  /// In ro, this message translates to:
  /// **'Nicio potrivire încă - adaugă cărți pe wishlist și listează cărți disponibile.'**
  String get smartMatchesEmpty;

  /// No description provided for @smartMatchesLoadError.
  ///
  /// In ro, this message translates to:
  /// **'Nu am putut încărca potrivirile.'**
  String get smartMatchesLoadError;

  /// No description provided for @smartMatchesTheyHave.
  ///
  /// In ro, this message translates to:
  /// **'Are ce vrei tu'**
  String get smartMatchesTheyHave;

  /// No description provided for @smartMatchesTheyWant.
  ///
  /// In ro, this message translates to:
  /// **'Vrea ce ai tu'**
  String get smartMatchesTheyWant;

  /// No description provided for @homeUpcomingBooks.
  ///
  /// In ro, this message translates to:
  /// **'Cărți viitoare'**
  String get homeUpcomingBooks;

  /// No description provided for @homeActiveMembers.
  ///
  /// In ro, this message translates to:
  /// **'Membri activi'**
  String get homeActiveMembers;

  /// No description provided for @browseTitle.
  ///
  /// In ro, this message translates to:
  /// **'Caută cărți'**
  String get browseTitle;

  /// No description provided for @browseMapTooltip.
  ///
  /// In ro, this message translates to:
  /// **'Hartă cărți din apropiere'**
  String get browseMapTooltip;

  /// No description provided for @browseSearchHint.
  ///
  /// In ro, this message translates to:
  /// **'Caută după titlu'**
  String get browseSearchHint;

  /// No description provided for @browseEmpty.
  ///
  /// In ro, this message translates to:
  /// **'Nicio carte găsită.'**
  String get browseEmpty;

  /// No description provided for @filtersTitle.
  ///
  /// In ro, this message translates to:
  /// **'Filtre'**
  String get filtersTitle;

  /// No description provided for @filtersAuthor.
  ///
  /// In ro, this message translates to:
  /// **'Autor'**
  String get filtersAuthor;

  /// No description provided for @filtersGenre.
  ///
  /// In ro, this message translates to:
  /// **'Gen'**
  String get filtersGenre;

  /// No description provided for @filtersLanguage.
  ///
  /// In ro, this message translates to:
  /// **'Limbă'**
  String get filtersLanguage;

  /// No description provided for @filtersAnyCity.
  ///
  /// In ro, this message translates to:
  /// **'Orice oraș'**
  String get filtersAnyCity;

  /// No description provided for @filtersCondition.
  ///
  /// In ro, this message translates to:
  /// **'Stare'**
  String get filtersCondition;

  /// No description provided for @filtersAnyCondition.
  ///
  /// In ro, this message translates to:
  /// **'Orice stare'**
  String get filtersAnyCondition;

  /// No description provided for @filtersListingType.
  ///
  /// In ro, this message translates to:
  /// **'Tip de anunț'**
  String get filtersListingType;

  /// No description provided for @filtersListingTypeSwap.
  ///
  /// In ro, this message translates to:
  /// **'Schimb'**
  String get filtersListingTypeSwap;

  /// No description provided for @filtersListingTypeSale.
  ///
  /// In ro, this message translates to:
  /// **'Vânzare'**
  String get filtersListingTypeSale;

  /// No description provided for @filtersListingTypeAuction.
  ///
  /// In ro, this message translates to:
  /// **'Licitație'**
  String get filtersListingTypeAuction;

  /// No description provided for @filtersNearbyOnly.
  ///
  /// In ro, this message translates to:
  /// **'Doar din apropiere'**
  String get filtersNearbyOnly;

  /// No description provided for @filtersNearbyOnlyHintOff.
  ///
  /// In ro, this message translates to:
  /// **'Ordonează și filtrează după distanța reală față de orașul tău'**
  String get filtersNearbyOnlyHintOff;

  /// No description provided for @filtersNearbyOnlyHintOn.
  ///
  /// In ro, this message translates to:
  /// **'Până la {km} km de orașul tău'**
  String filtersNearbyOnlyHintOn(int km);

  /// No description provided for @filtersDistanceKm.
  ///
  /// In ro, this message translates to:
  /// **'{km} km'**
  String filtersDistanceKm(int km);

  /// No description provided for @filtersReset.
  ///
  /// In ro, this message translates to:
  /// **'Resetează'**
  String get filtersReset;

  /// No description provided for @filtersApply.
  ///
  /// In ro, this message translates to:
  /// **'Aplică filtre'**
  String get filtersApply;

  /// No description provided for @commonYes.
  ///
  /// In ro, this message translates to:
  /// **'Da'**
  String get commonYes;

  /// No description provided for @commonNo.
  ///
  /// In ro, this message translates to:
  /// **'Nu'**
  String get commonNo;

  /// No description provided for @commonGiveUp.
  ///
  /// In ro, this message translates to:
  /// **'Renunță'**
  String get commonGiveUp;

  /// No description provided for @libraryTitle.
  ///
  /// In ro, this message translates to:
  /// **'Biblioteca mea'**
  String get libraryTitle;

  /// No description provided for @libraryViewAsList.
  ///
  /// In ro, this message translates to:
  /// **'Vezi ca listă'**
  String get libraryViewAsList;

  /// No description provided for @libraryViewAsGrid.
  ///
  /// In ro, this message translates to:
  /// **'Vezi ca grilă'**
  String get libraryViewAsGrid;

  /// No description provided for @libraryExportCsv.
  ///
  /// In ro, this message translates to:
  /// **'Exportă în CSV'**
  String get libraryExportCsv;

  /// No description provided for @libraryEmpty.
  ///
  /// In ro, this message translates to:
  /// **'Nu ai nicio carte în bibliotecă încă.'**
  String get libraryEmpty;

  /// No description provided for @libraryLoadError.
  ///
  /// In ro, this message translates to:
  /// **'Nu am putut încărca biblioteca.'**
  String get libraryLoadError;

  /// No description provided for @libraryAvailable.
  ///
  /// In ro, this message translates to:
  /// **'Disponibilă'**
  String get libraryAvailable;

  /// No description provided for @libraryUnavailable.
  ///
  /// In ro, this message translates to:
  /// **'Indisponibilă'**
  String get libraryUnavailable;

  /// No description provided for @libraryDeleteConfirmTitle.
  ///
  /// In ro, this message translates to:
  /// **'Ștergi cartea?'**
  String get libraryDeleteConfirmTitle;

  /// No description provided for @libraryDeleteConfirmBody.
  ///
  /// In ro, this message translates to:
  /// **'„{title}\" va fi eliminată din bibliotecă.'**
  String libraryDeleteConfirmBody(String title);

  /// No description provided for @libraryAvailableForSwap.
  ///
  /// In ro, this message translates to:
  /// **'Disponibilă pentru schimb'**
  String get libraryAvailableForSwap;

  /// No description provided for @libraryDeleteBook.
  ///
  /// In ro, this message translates to:
  /// **'Șterge cartea'**
  String get libraryDeleteBook;

  /// No description provided for @libraryEditListing.
  ///
  /// In ro, this message translates to:
  /// **'Editează anunțul'**
  String get libraryEditListing;

  /// No description provided for @libraryEditListingTitle.
  ///
  /// In ro, this message translates to:
  /// **'Editează anunțul'**
  String get libraryEditListingTitle;

  /// No description provided for @libraryEditListingSuccess.
  ///
  /// In ro, this message translates to:
  /// **'Anunțul a fost actualizat.'**
  String get libraryEditListingSuccess;

  /// No description provided for @csvHeaderTitle.
  ///
  /// In ro, this message translates to:
  /// **'Titlu'**
  String get csvHeaderTitle;

  /// No description provided for @csvHeaderAvailableForSwap.
  ///
  /// In ro, this message translates to:
  /// **'Disponibilă la schimb'**
  String get csvHeaderAvailableForSwap;

  /// No description provided for @csvHeaderForSale.
  ///
  /// In ro, this message translates to:
  /// **'De vânzare'**
  String get csvHeaderForSale;

  /// No description provided for @csvHeaderPrice.
  ///
  /// In ro, this message translates to:
  /// **'Preț'**
  String get csvHeaderPrice;

  /// No description provided for @addBookTitle.
  ///
  /// In ro, this message translates to:
  /// **'Adaugă o carte'**
  String get addBookTitle;

  /// No description provided for @addBookSearchHint.
  ///
  /// In ro, this message translates to:
  /// **'Titlu sau ISBN'**
  String get addBookSearchHint;

  /// No description provided for @addBookSearchButton.
  ///
  /// In ro, this message translates to:
  /// **'Caută'**
  String get addBookSearchButton;

  /// No description provided for @addBookSearchFailed.
  ///
  /// In ro, this message translates to:
  /// **'Căutarea a eșuat. Încearcă din nou.'**
  String get addBookSearchFailed;

  /// No description provided for @addBookSearchPrompt.
  ///
  /// In ro, this message translates to:
  /// **'Caută o carte după titlu sau ISBN.'**
  String get addBookSearchPrompt;

  /// No description provided for @addBookManualEntry.
  ///
  /// In ro, this message translates to:
  /// **'Adaugă manual'**
  String get addBookManualEntry;

  /// No description provided for @addBookNotFoundManual.
  ///
  /// In ro, this message translates to:
  /// **'Nu găsești cartea? Adaugă manual'**
  String get addBookNotFoundManual;

  /// No description provided for @addBookChange.
  ///
  /// In ro, this message translates to:
  /// **'Schimbă'**
  String get addBookChange;

  /// No description provided for @addBookTitleLabel.
  ///
  /// In ro, this message translates to:
  /// **'Titlu'**
  String get addBookTitleLabel;

  /// No description provided for @addBookSearchInstead.
  ///
  /// In ro, this message translates to:
  /// **'Caută în schimb'**
  String get addBookSearchInstead;

  /// No description provided for @addBookLanguageOptional.
  ///
  /// In ro, this message translates to:
  /// **'Limbă (opțional)'**
  String get addBookLanguageOptional;

  /// No description provided for @addBookEditionOptional.
  ///
  /// In ro, this message translates to:
  /// **'Ediție (opțional)'**
  String get addBookEditionOptional;

  /// No description provided for @addBookHardcoverSwitch.
  ///
  /// In ro, this message translates to:
  /// **'Ediție cartonată'**
  String get addBookHardcoverSwitch;

  /// No description provided for @addBookForSaleSwitch.
  ///
  /// In ro, this message translates to:
  /// **'De vânzare'**
  String get addBookForSaleSwitch;

  /// No description provided for @addBookForSaleHint.
  ///
  /// In ro, this message translates to:
  /// **'Pe lângă schimb, poți vinde cartea la un preț fix'**
  String get addBookForSaleHint;

  /// No description provided for @addBookPriceLabel.
  ///
  /// In ro, this message translates to:
  /// **'Preț (lei)'**
  String get addBookPriceLabel;

  /// No description provided for @addBookNonNegotiable.
  ///
  /// In ro, this message translates to:
  /// **'Preț fix, nenegociabil'**
  String get addBookNonNegotiable;

  /// No description provided for @addBookNonNegotiableHint.
  ///
  /// In ro, this message translates to:
  /// **'Cumpărătorii nu vor putea face oferte de preț'**
  String get addBookNonNegotiableHint;

  /// No description provided for @addBookAuctionSwitch.
  ///
  /// In ro, this message translates to:
  /// **'Pornește o licitație'**
  String get addBookAuctionSwitch;

  /// No description provided for @addBookAuctionHint.
  ///
  /// In ro, this message translates to:
  /// **'Cumpărătorii vor licita, câștigă oferta cea mai mare la final'**
  String get addBookAuctionHint;

  /// No description provided for @addBookAuctionStartingPrice.
  ///
  /// In ro, this message translates to:
  /// **'Preț de pornire'**
  String get addBookAuctionStartingPrice;

  /// No description provided for @addBookAuctionReservePrice.
  ///
  /// In ro, this message translates to:
  /// **'Preț de rezervă (opțional)'**
  String get addBookAuctionReservePrice;

  /// No description provided for @addBookAuctionReservePriceHint.
  ///
  /// In ro, this message translates to:
  /// **'Prețul minim sub care nu vinzi cartea'**
  String get addBookAuctionReservePriceHint;

  /// No description provided for @addBookAuctionBuyNowPrice.
  ///
  /// In ro, this message translates to:
  /// **'Preț \"Cumpără acum\" (opțional)'**
  String get addBookAuctionBuyNowPrice;

  /// No description provided for @addBookAuctionBuyNowPriceHint.
  ///
  /// In ro, this message translates to:
  /// **'Disponibil doar înainte de prima ofertă'**
  String get addBookAuctionBuyNowPriceHint;

  /// No description provided for @addBookAuctionDuration.
  ///
  /// In ro, this message translates to:
  /// **'Durata licitației'**
  String get addBookAuctionDuration;

  /// No description provided for @addBookAuctionDuration24h.
  ///
  /// In ro, this message translates to:
  /// **'24 ore'**
  String get addBookAuctionDuration24h;

  /// No description provided for @addBookAuctionDuration3d.
  ///
  /// In ro, this message translates to:
  /// **'3 zile'**
  String get addBookAuctionDuration3d;

  /// No description provided for @addBookAuctionDuration7d.
  ///
  /// In ro, this message translates to:
  /// **'7 zile'**
  String get addBookAuctionDuration7d;

  /// No description provided for @addBookPhotosLabelRequired.
  ///
  /// In ro, this message translates to:
  /// **'Poze cu cartea (obligatoriu, cel puțin 1)'**
  String get addBookPhotosLabelRequired;

  /// No description provided for @addBookPhotosLabelOptional.
  ///
  /// In ro, this message translates to:
  /// **'Poze cu cartea (opțional)'**
  String get addBookPhotosLabelOptional;

  /// No description provided for @addBookSubmit.
  ///
  /// In ro, this message translates to:
  /// **'Adaugă în bibliotecă'**
  String get addBookSubmit;

  /// No description provided for @addBookTitleRequired.
  ///
  /// In ro, this message translates to:
  /// **'Titlul este obligatoriu'**
  String get addBookTitleRequired;

  /// No description provided for @addBookInvalidPrice.
  ///
  /// In ro, this message translates to:
  /// **'Introdu un preț valid'**
  String get addBookInvalidPrice;

  /// No description provided for @addBookNeedPhoto.
  ///
  /// In ro, this message translates to:
  /// **'Adaugă cel puțin o poză cu cartea înainte de a o pune la vânzare'**
  String get addBookNeedPhoto;

  /// No description provided for @addBookSuccess.
  ///
  /// In ro, this message translates to:
  /// **'Carte adăugată în bibliotecă'**
  String get addBookSuccess;

  /// No description provided for @addBookGenericError.
  ///
  /// In ro, this message translates to:
  /// **'Nu am putut adăuga cartea. Încearcă din nou.'**
  String get addBookGenericError;

  /// No description provided for @relistNeedPhoto.
  ///
  /// In ro, this message translates to:
  /// **'Adaugă cel puțin o poză înainte de a o pune la vânzare'**
  String get relistNeedPhoto;

  /// No description provided for @relistSuccess.
  ///
  /// In ro, this message translates to:
  /// **'Cartea a fost adăugată în biblioteca ta'**
  String get relistSuccess;

  /// No description provided for @relistGenericError.
  ///
  /// In ro, this message translates to:
  /// **'Nu am putut adăuga cartea.'**
  String get relistGenericError;

  /// No description provided for @relistHeading.
  ///
  /// In ro, this message translates to:
  /// **'Adaugă „{title}\" în biblioteca ta'**
  String relistHeading(String title);

  /// No description provided for @relistSubtitle.
  ///
  /// In ro, this message translates to:
  /// **'Descrie starea în care ai primit-o - rămâne legată de istoricul cărții.'**
  String get relistSubtitle;

  /// No description provided for @mapTitle.
  ///
  /// In ro, this message translates to:
  /// **'Cărți din apropiere'**
  String get mapTitle;

  /// No description provided for @mapLoadError.
  ///
  /// In ro, this message translates to:
  /// **'Nu am putut încărca harta.'**
  String get mapLoadError;

  /// No description provided for @mapEmpty.
  ///
  /// In ro, this message translates to:
  /// **'Nicio carte disponibilă momentan în vreun oraș.'**
  String get mapEmpty;

  /// No description provided for @mapCityBooksCount.
  ///
  /// In ro, this message translates to:
  /// **'{count, plural, one{{count} carte} other{{count} cărți}}'**
  String mapCityBooksCount(int count);

  /// No description provided for @bookDetailTitle.
  ///
  /// In ro, this message translates to:
  /// **'Detalii carte'**
  String get bookDetailTitle;

  /// No description provided for @bookDetailReportTooltip.
  ///
  /// In ro, this message translates to:
  /// **'Raportează anunțul'**
  String get bookDetailReportTooltip;

  /// No description provided for @bookDetailReportedFrom.
  ///
  /// In ro, this message translates to:
  /// **'Raportat de pe anunțul \"{title}\"'**
  String bookDetailReportedFrom(String title);

  /// No description provided for @bookDetailReportSent.
  ///
  /// In ro, this message translates to:
  /// **'Raport trimis. Mulțumim!'**
  String get bookDetailReportSent;

  /// No description provided for @bookDetailReportError.
  ///
  /// In ro, this message translates to:
  /// **'Nu am putut trimite raportul'**
  String get bookDetailReportError;

  /// No description provided for @bookDetailLoadError.
  ///
  /// In ro, this message translates to:
  /// **'Nu am putut încărca cartea.'**
  String get bookDetailLoadError;

  /// No description provided for @bookDetailViewsTitle.
  ///
  /// In ro, this message translates to:
  /// **'Vizualizări'**
  String get bookDetailViewsTitle;

  /// No description provided for @bookDetailViewsLoadError.
  ///
  /// In ro, this message translates to:
  /// **'Nu am putut încărca vizualizările.'**
  String get bookDetailViewsLoadError;

  /// No description provided for @bookDetailUniqueViews.
  ///
  /// In ro, this message translates to:
  /// **'{count} vizualizări unice'**
  String bookDetailUniqueViews(int count);

  /// No description provided for @bookDetailTotalViews.
  ///
  /// In ro, this message translates to:
  /// **'{count} vizualizări în total, inclusiv reîncărcări de pagină'**
  String bookDetailTotalViews(int count);

  /// No description provided for @bookDetailHardcoverChip.
  ///
  /// In ro, this message translates to:
  /// **'Cartonată'**
  String get bookDetailHardcoverChip;

  /// No description provided for @bookDetailAvailableChip.
  ///
  /// In ro, this message translates to:
  /// **'Disponibilă la schimb'**
  String get bookDetailAvailableChip;

  /// No description provided for @bookDetailViewCount.
  ///
  /// In ro, this message translates to:
  /// **'{count} vizualizări'**
  String bookDetailViewCount(int count);

  /// No description provided for @bookDetailDescriptionTitle.
  ///
  /// In ro, this message translates to:
  /// **'Descriere'**
  String get bookDetailDescriptionTitle;

  /// No description provided for @bookDetailDetailsTitle.
  ///
  /// In ro, this message translates to:
  /// **'Detalii'**
  String get bookDetailDetailsTitle;

  /// No description provided for @bookDetailPublisherLabel.
  ///
  /// In ro, this message translates to:
  /// **'Editură'**
  String get bookDetailPublisherLabel;

  /// No description provided for @bookDetailYearLabel.
  ///
  /// In ro, this message translates to:
  /// **'An apariție'**
  String get bookDetailYearLabel;

  /// No description provided for @bookDetailPagesLabel.
  ///
  /// In ro, this message translates to:
  /// **'Pagini'**
  String get bookDetailPagesLabel;

  /// No description provided for @bookDetailOwnerTitle.
  ///
  /// In ro, this message translates to:
  /// **'Proprietar'**
  String get bookDetailOwnerTitle;

  /// No description provided for @bookDetailPhotosTitle.
  ///
  /// In ro, this message translates to:
  /// **'Poze'**
  String get bookDetailPhotosTitle;

  /// No description provided for @bookDetailRequestExchange.
  ///
  /// In ro, this message translates to:
  /// **'Cere la schimb'**
  String get bookDetailRequestExchange;

  /// No description provided for @bookDetailUnavailableForExchange.
  ///
  /// In ro, this message translates to:
  /// **'Indisponibilă la schimb'**
  String get bookDetailUnavailableForExchange;

  /// No description provided for @bookDetailMakeOffer.
  ///
  /// In ro, this message translates to:
  /// **'Fă o ofertă'**
  String get bookDetailMakeOffer;

  /// No description provided for @bookDetailHistoryTitle.
  ///
  /// In ro, this message translates to:
  /// **'Istoricul acestei cărți'**
  String get bookDetailHistoryTitle;

  /// No description provided for @bookDetailHistorySubtitle.
  ///
  /// In ro, this message translates to:
  /// **'Cum a circulat cartea prin aplicație, cu poze puse de fiecare proprietar.'**
  String get bookDetailHistorySubtitle;

  /// No description provided for @bookDetailHistorySold.
  ///
  /// In ro, this message translates to:
  /// **'vândută'**
  String get bookDetailHistorySold;

  /// No description provided for @bookDetailHistoryExchanged.
  ///
  /// In ro, this message translates to:
  /// **'dată la schimb'**
  String get bookDetailHistoryExchanged;

  /// No description provided for @bookDetailHistoryListedOn.
  ///
  /// In ro, this message translates to:
  /// **'listată pe {date}'**
  String bookDetailHistoryListedOn(String date);

  /// No description provided for @bookDetailHistoryTransferredOn.
  ///
  /// In ro, this message translates to:
  /// **' · {action} pe {date}'**
  String bookDetailHistoryTransferredOn(String action, String date);

  /// No description provided for @bookDetailHistoryCurrentlyOwned.
  ///
  /// In ro, this message translates to:
  /// **' · deținută în prezent'**
  String get bookDetailHistoryCurrentlyOwned;

  /// No description provided for @bookDetailSimilarBooksTitle.
  ///
  /// In ro, this message translates to:
  /// **'Cărți similare'**
  String get bookDetailSimilarBooksTitle;

  /// No description provided for @bookDetailLibraryPriceLabel.
  ///
  /// In ro, this message translates to:
  /// **'Preț în librării: {price}'**
  String bookDetailLibraryPriceLabel(String price);

  /// No description provided for @bookDetailRequestedTitle.
  ///
  /// In ro, this message translates to:
  /// **'Cere „{title}\" la schimb'**
  String bookDetailRequestedTitle(String title);

  /// No description provided for @bookDetailNoBooksToOffer.
  ///
  /// In ro, this message translates to:
  /// **'Nu ai cărți disponibile de oferit - poți trimite cererea și fără.'**
  String get bookDetailNoBooksToOffer;

  /// No description provided for @bookDetailOfferOneOfYourBooks.
  ///
  /// In ro, this message translates to:
  /// **'Oferă una din cărțile tale (opțional)'**
  String get bookDetailOfferOneOfYourBooks;

  /// No description provided for @bookDetailNoOffer.
  ///
  /// In ro, this message translates to:
  /// **'Fără ofertă'**
  String get bookDetailNoOffer;

  /// No description provided for @bookDetailMessageOptional.
  ///
  /// In ro, this message translates to:
  /// **'Mesaj (opțional)'**
  String get bookDetailMessageOptional;

  /// No description provided for @bookDetailSendRequest.
  ///
  /// In ro, this message translates to:
  /// **'Trimite cererea'**
  String get bookDetailSendRequest;

  /// No description provided for @bookDetailRequestSent.
  ///
  /// In ro, this message translates to:
  /// **'Cerere de schimb trimisă'**
  String get bookDetailRequestSent;

  /// No description provided for @bookDetailRequestError.
  ///
  /// In ro, this message translates to:
  /// **'Nu am putut trimite cererea.'**
  String get bookDetailRequestError;

  /// No description provided for @bookDetailFirstExchangeTitle.
  ///
  /// In ro, this message translates to:
  /// **'Primul tău schimb'**
  String get bookDetailFirstExchangeTitle;

  /// No description provided for @bookDetailFirstExchangeBody.
  ///
  /// In ro, this message translates to:
  /// **'Câteva sfaturi înainte de primul schimb: întâlnește-te ziua, într-un loc public, și verifică starea cărții înainte să confirmi schimbul ca finalizat.'**
  String get bookDetailFirstExchangeBody;

  /// No description provided for @bookDetailUnderstood.
  ///
  /// In ro, this message translates to:
  /// **'Am înțeles, continuă'**
  String get bookDetailUnderstood;

  /// No description provided for @bookDetailMakeOfferTitle.
  ///
  /// In ro, this message translates to:
  /// **'Fă o ofertă pentru „{title}\"'**
  String bookDetailMakeOfferTitle(String title);

  /// No description provided for @bookDetailAskingPrice.
  ///
  /// In ro, this message translates to:
  /// **'Preț cerut: {price}'**
  String bookDetailAskingPrice(String price);

  /// No description provided for @bookDetailOfferAmountLabel.
  ///
  /// In ro, this message translates to:
  /// **'Suma oferită'**
  String get bookDetailOfferAmountLabel;

  /// No description provided for @bookDetailSendOffer.
  ///
  /// In ro, this message translates to:
  /// **'Trimite oferta'**
  String get bookDetailSendOffer;

  /// No description provided for @bookDetailOfferSent.
  ///
  /// In ro, this message translates to:
  /// **'Ofertă trimisă'**
  String get bookDetailOfferSent;

  /// No description provided for @bookDetailOfferError.
  ///
  /// In ro, this message translates to:
  /// **'Nu am putut trimite oferta.'**
  String get bookDetailOfferError;

  /// No description provided for @bookDetailInvalidAmount.
  ///
  /// In ro, this message translates to:
  /// **'Introdu o sumă validă'**
  String get bookDetailInvalidAmount;

  /// No description provided for @commonAddToLibrary.
  ///
  /// In ro, this message translates to:
  /// **'Adaugă în biblioteca ta'**
  String get commonAddToLibrary;

  /// No description provided for @commonAnonymousUser.
  ///
  /// In ro, this message translates to:
  /// **'un utilizator'**
  String get commonAnonymousUser;

  /// No description provided for @exchangesTitle.
  ///
  /// In ro, this message translates to:
  /// **'Schimburile mele'**
  String get exchangesTitle;

  /// No description provided for @exchangesTabReceived.
  ///
  /// In ro, this message translates to:
  /// **'Schimburi primite'**
  String get exchangesTabReceived;

  /// No description provided for @exchangesTabSent.
  ///
  /// In ro, this message translates to:
  /// **'Schimburi trimise'**
  String get exchangesTabSent;

  /// No description provided for @offersTabReceived.
  ///
  /// In ro, this message translates to:
  /// **'Oferte primite'**
  String get offersTabReceived;

  /// No description provided for @offersTabSent.
  ///
  /// In ro, this message translates to:
  /// **'Oferte trimise'**
  String get offersTabSent;

  /// No description provided for @exchangesEmptyReceived.
  ///
  /// In ro, this message translates to:
  /// **'Nu ai primit nicio cerere de schimb.'**
  String get exchangesEmptyReceived;

  /// No description provided for @exchangesEmptySent.
  ///
  /// In ro, this message translates to:
  /// **'Nu ai trimis nicio cerere de schimb.'**
  String get exchangesEmptySent;

  /// No description provided for @exchangesLoadError.
  ///
  /// In ro, this message translates to:
  /// **'Nu am putut încărca schimburile.'**
  String get exchangesLoadError;

  /// No description provided for @exchangeRequestedBy.
  ///
  /// In ro, this message translates to:
  /// **'Cerută de {name}'**
  String exchangeRequestedBy(String name);

  /// No description provided for @exchangeFrom.
  ///
  /// In ro, this message translates to:
  /// **'De la {name}'**
  String exchangeFrom(String name);

  /// No description provided for @exchangeOffersBook.
  ///
  /// In ro, this message translates to:
  /// **'Oferă: {title}'**
  String exchangeOffersBook(String title);

  /// No description provided for @exchangeOffersAmount.
  ///
  /// In ro, this message translates to:
  /// **'Oferă: {amount} RON'**
  String exchangeOffersAmount(String amount);

  /// No description provided for @exchangeReject.
  ///
  /// In ro, this message translates to:
  /// **'Refuză'**
  String get exchangeReject;

  /// No description provided for @exchangeAccept.
  ///
  /// In ro, this message translates to:
  /// **'Acceptă'**
  String get exchangeAccept;

  /// No description provided for @exchangeCancelRequest.
  ///
  /// In ro, this message translates to:
  /// **'Anulează cererea'**
  String get exchangeCancelRequest;

  /// No description provided for @exchangeScheduleMeeting.
  ///
  /// In ro, this message translates to:
  /// **'Programează întâlnirea'**
  String get exchangeScheduleMeeting;

  /// No description provided for @exchangeReschedule.
  ///
  /// In ro, this message translates to:
  /// **'Reprogramează'**
  String get exchangeReschedule;

  /// No description provided for @exchangeAddToCalendar.
  ///
  /// In ro, this message translates to:
  /// **'Adaugă în calendar'**
  String get exchangeAddToCalendar;

  /// No description provided for @exchangeQrCode.
  ///
  /// In ro, this message translates to:
  /// **'Cod QR'**
  String get exchangeQrCode;

  /// No description provided for @exchangeMarkComplete.
  ///
  /// In ro, this message translates to:
  /// **'Marchează finalizat'**
  String get exchangeMarkComplete;

  /// No description provided for @exchangeRated.
  ///
  /// In ro, this message translates to:
  /// **'Evaluat'**
  String get exchangeRated;

  /// No description provided for @exchangeRate.
  ///
  /// In ro, this message translates to:
  /// **'Evaluează'**
  String get exchangeRate;

  /// No description provided for @exchangeCalendarError.
  ///
  /// In ro, this message translates to:
  /// **'Nu am putut deschide calendarul.'**
  String get exchangeCalendarError;

  /// No description provided for @exchangeRatingDialogTitle.
  ///
  /// In ro, this message translates to:
  /// **'Cum a fost schimbul?'**
  String get exchangeRatingDialogTitle;

  /// No description provided for @exchangeRatingOverall.
  ///
  /// In ro, this message translates to:
  /// **'Per ansamblu'**
  String get exchangeRatingOverall;

  /// No description provided for @exchangeRatingCommunication.
  ///
  /// In ro, this message translates to:
  /// **'Comunicare'**
  String get exchangeRatingCommunication;

  /// No description provided for @exchangeRatingPunctuality.
  ///
  /// In ro, this message translates to:
  /// **'Punctualitate'**
  String get exchangeRatingPunctuality;

  /// No description provided for @exchangeRatingCondition.
  ///
  /// In ro, this message translates to:
  /// **'Starea cărții primite'**
  String get exchangeRatingCondition;

  /// No description provided for @exchangeReviewOptional.
  ///
  /// In ro, this message translates to:
  /// **'Recenzie (opțional)'**
  String get exchangeReviewOptional;

  /// No description provided for @exchangeQrDialogTitle.
  ///
  /// In ro, this message translates to:
  /// **'Cod QR de confirmare'**
  String get exchangeQrDialogTitle;

  /// No description provided for @exchangeQrDialogBody.
  ///
  /// In ro, this message translates to:
  /// **'Celălalt participant scanează acest cod la întâlnire ca să confirme schimbul.'**
  String get exchangeQrDialogBody;

  /// No description provided for @exchangeMeetingSheetTitle.
  ///
  /// In ro, this message translates to:
  /// **'Programează întâlnirea'**
  String get exchangeMeetingSheetTitle;

  /// No description provided for @exchangePickDateTime.
  ///
  /// In ro, this message translates to:
  /// **'Alege data și ora'**
  String get exchangePickDateTime;

  /// No description provided for @exchangeLocationLabel.
  ///
  /// In ro, this message translates to:
  /// **'Locație'**
  String get exchangeLocationLabel;

  /// No description provided for @exchangeMeetingSaveError.
  ///
  /// In ro, this message translates to:
  /// **'Nu am putut salva întâlnirea.'**
  String get exchangeMeetingSaveError;

  /// No description provided for @offersEmptyReceived.
  ///
  /// In ro, this message translates to:
  /// **'Nu ai primit nicio ofertă de preț.'**
  String get offersEmptyReceived;

  /// No description provided for @offersEmptySent.
  ///
  /// In ro, this message translates to:
  /// **'Nu ai trimis nicio ofertă de preț.'**
  String get offersEmptySent;

  /// No description provided for @offersLoadError.
  ///
  /// In ro, this message translates to:
  /// **'Nu am putut încărca ofertele.'**
  String get offersLoadError;

  /// No description provided for @offerTo.
  ///
  /// In ro, this message translates to:
  /// **'Către {name}'**
  String offerTo(String name);

  /// No description provided for @offerAmountLine.
  ///
  /// In ro, this message translates to:
  /// **'Ofertă: {amount}'**
  String offerAmountLine(String amount);

  /// No description provided for @offerCancel.
  ///
  /// In ro, this message translates to:
  /// **'Anulează oferta'**
  String get offerCancel;

  /// No description provided for @exchangeConfirmTitle.
  ///
  /// In ro, this message translates to:
  /// **'Confirmă schimbul'**
  String get exchangeConfirmTitle;

  /// No description provided for @exchangeConfirmError.
  ///
  /// In ro, this message translates to:
  /// **'Nu am putut confirma schimbul.'**
  String get exchangeConfirmError;

  /// No description provided for @exchangeConfirmDone.
  ///
  /// In ro, this message translates to:
  /// **'Schimb marcat ca finalizat!'**
  String get exchangeConfirmDone;

  /// No description provided for @exchangeConfirmQuestion.
  ///
  /// In ro, this message translates to:
  /// **'Confirmi că schimbul de cărți s-a finalizat?'**
  String get exchangeConfirmQuestion;

  /// No description provided for @exchangeConfirmButton.
  ///
  /// In ro, this message translates to:
  /// **'Confirmă finalizarea'**
  String get exchangeConfirmButton;

  /// No description provided for @chatEmptyConversations.
  ///
  /// In ro, this message translates to:
  /// **'Nu ai nicio conversație încă.'**
  String get chatEmptyConversations;

  /// No description provided for @chatStartConversation.
  ///
  /// In ro, this message translates to:
  /// **'Începe conversația'**
  String get chatStartConversation;

  /// No description provided for @chatPhotoPreview.
  ///
  /// In ro, this message translates to:
  /// **'📷 Poză'**
  String get chatPhotoPreview;

  /// No description provided for @chatLocationPreview.
  ///
  /// In ro, this message translates to:
  /// **'📍 Locație'**
  String get chatLocationPreview;

  /// No description provided for @chatLoadError.
  ///
  /// In ro, this message translates to:
  /// **'Nu am putut încărca conversațiile.'**
  String get chatLoadError;

  /// No description provided for @chatConversationFallbackTitle.
  ///
  /// In ro, this message translates to:
  /// **'Conversație'**
  String get chatConversationFallbackTitle;

  /// No description provided for @chatUnblock.
  ///
  /// In ro, this message translates to:
  /// **'Deblochează'**
  String get chatUnblock;

  /// No description provided for @chatBlock.
  ///
  /// In ro, this message translates to:
  /// **'Blochează'**
  String get chatBlock;

  /// No description provided for @chatUserUnblocked.
  ///
  /// In ro, this message translates to:
  /// **'Utilizator deblocat'**
  String get chatUserUnblocked;

  /// No description provided for @chatUserBlocked.
  ///
  /// In ro, this message translates to:
  /// **'Utilizator blocat'**
  String get chatUserBlocked;

  /// No description provided for @chatBlockUpdateError.
  ///
  /// In ro, this message translates to:
  /// **'Nu am putut actualiza blocarea'**
  String get chatBlockUpdateError;

  /// No description provided for @chatTyping.
  ///
  /// In ro, this message translates to:
  /// **'scrie...'**
  String get chatTyping;

  /// No description provided for @chatBlockedNotice.
  ///
  /// In ro, this message translates to:
  /// **'Nu poți trimite mesaje acestui utilizator - conversația este blocată.'**
  String get chatBlockedNotice;

  /// No description provided for @chatShareLocationTooltip.
  ///
  /// In ro, this message translates to:
  /// **'Trimite locația întâlnirii'**
  String get chatShareLocationTooltip;

  /// No description provided for @chatMessageHint.
  ///
  /// In ro, this message translates to:
  /// **'Scrie un mesaj...'**
  String get chatMessageHint;

  /// No description provided for @chatSafetyBannerBody.
  ///
  /// In ro, this message translates to:
  /// **'Nu trimite bani în avans și întâlnește-te într-un loc public pentru schimb. Dacă ceva pare suspect, raportează sau blochează utilizatorul din meniul de sus.'**
  String get chatSafetyBannerBody;

  /// No description provided for @chatSafetyBannerLearnMore.
  ///
  /// In ro, this message translates to:
  /// **'Află mai multe'**
  String get chatSafetyBannerLearnMore;

  /// No description provided for @chatEmptyMessages.
  ///
  /// In ro, this message translates to:
  /// **'Niciun mesaj încă. Spune salut!'**
  String get chatEmptyMessages;

  /// No description provided for @chatMapLabel.
  ///
  /// In ro, this message translates to:
  /// **'Hartă'**
  String get chatMapLabel;

  /// No description provided for @chatCalendarLabel.
  ///
  /// In ro, this message translates to:
  /// **'Calendar'**
  String get chatCalendarLabel;

  /// No description provided for @chatMeetingAt.
  ///
  /// In ro, this message translates to:
  /// **'{date}, ora {time}'**
  String chatMeetingAt(String date, String time);

  /// No description provided for @chatSafetyAdvisorLabel.
  ///
  /// In ro, this message translates to:
  /// **'Safety advisor'**
  String get chatSafetyAdvisorLabel;

  /// No description provided for @chatSafetyAdvisorBody.
  ///
  /// In ro, this message translates to:
  /// **'Asigură-te că respecți regulile de siguranță la întâlnire.'**
  String get chatSafetyAdvisorBody;

  /// No description provided for @chatOfferActionError.
  ///
  /// In ro, this message translates to:
  /// **'Nu am putut actualiza oferta. Încearcă din nou.'**
  String get chatOfferActionError;

  /// No description provided for @chatOfferCardLabel.
  ///
  /// In ro, this message translates to:
  /// **'{amount} lei · {bookTitle}'**
  String chatOfferCardLabel(String amount, String bookTitle);

  /// No description provided for @chatSearchPlaceHint.
  ///
  /// In ro, this message translates to:
  /// **'Caută o adresă sau un loc (ex: Cafeneaua X, Cluj)'**
  String get chatSearchPlaceHint;

  /// No description provided for @chatNoResults.
  ///
  /// In ro, this message translates to:
  /// **'Niciun rezultat.'**
  String get chatNoResults;

  /// No description provided for @chatSuggestedMeetingPoints.
  ///
  /// In ro, this message translates to:
  /// **'Sugestii de întâlnire în apropiere'**
  String get chatSuggestedMeetingPoints;

  /// No description provided for @chatPickDate.
  ///
  /// In ro, this message translates to:
  /// **'Alege data'**
  String get chatPickDate;

  /// No description provided for @chatPickTime.
  ///
  /// In ro, this message translates to:
  /// **'Alege ora'**
  String get chatPickTime;

  /// No description provided for @wishlistTitle.
  ///
  /// In ro, this message translates to:
  /// **'Lista de dorințe'**
  String get wishlistTitle;

  /// No description provided for @wishlistEmpty.
  ///
  /// In ro, this message translates to:
  /// **'Nu ai adăugat încă nicio carte în lista de dorințe.'**
  String get wishlistEmpty;

  /// No description provided for @wishlistLoadError.
  ///
  /// In ro, this message translates to:
  /// **'Nu am putut încărca lista de dorințe.'**
  String get wishlistLoadError;

  /// No description provided for @notificationsTitle.
  ///
  /// In ro, this message translates to:
  /// **'Notificări'**
  String get notificationsTitle;

  /// No description provided for @notificationsMarkAllRead.
  ///
  /// In ro, this message translates to:
  /// **'Marchează tot ca citit'**
  String get notificationsMarkAllRead;

  /// No description provided for @notificationsEmpty.
  ///
  /// In ro, this message translates to:
  /// **'Nu ai nicio notificare.'**
  String get notificationsEmpty;

  /// No description provided for @notificationsLoadError.
  ///
  /// In ro, this message translates to:
  /// **'Nu am putut încărca notificările.'**
  String get notificationsLoadError;

  /// No description provided for @timeJustNow.
  ///
  /// In ro, this message translates to:
  /// **'acum'**
  String get timeJustNow;

  /// No description provided for @timeMinutesAgo.
  ///
  /// In ro, this message translates to:
  /// **'acum {minutes} min'**
  String timeMinutesAgo(int minutes);

  /// No description provided for @timeHoursAgo.
  ///
  /// In ro, this message translates to:
  /// **'acum {hours} h'**
  String timeHoursAgo(int hours);

  /// No description provided for @timeDaysAgo.
  ///
  /// In ro, this message translates to:
  /// **'acum {days} zile'**
  String timeDaysAgo(int days);

  /// No description provided for @safetyCenterTitle.
  ///
  /// In ro, this message translates to:
  /// **'Centru de siguranță'**
  String get safetyCenterTitle;

  /// No description provided for @safetyCenterIntro.
  ///
  /// In ro, this message translates to:
  /// **'Câteva reguli simple ca schimburile prin ShelfShare să fie plăcute și sigure.'**
  String get safetyCenterIntro;

  /// No description provided for @safetyTip1Title.
  ///
  /// In ro, this message translates to:
  /// **'Întâlnește-te ziua'**
  String get safetyTip1Title;

  /// No description provided for @safetyTip1Desc.
  ///
  /// In ro, this message translates to:
  /// **'Programează schimbul într-un interval orar cu lumină naturală, ideal dimineața sau după-amiaza.'**
  String get safetyTip1Desc;

  /// No description provided for @safetyTip2Title.
  ///
  /// In ro, this message translates to:
  /// **'Alege un loc public'**
  String get safetyTip2Title;

  /// No description provided for @safetyTip2Desc.
  ///
  /// In ro, this message translates to:
  /// **'O cafenea, o librărie sau un mall sunt variante mai sigure decât adresa personală a cuiva.'**
  String get safetyTip2Desc;

  /// No description provided for @safetyTip3Title.
  ///
  /// In ro, this message translates to:
  /// **'Preferă locații cu supraveghere video'**
  String get safetyTip3Title;

  /// No description provided for @safetyTip3Desc.
  ///
  /// In ro, this message translates to:
  /// **'Zonele cu camere de securitate descurajează comportamentul neplăcut.'**
  String get safetyTip3Desc;

  /// No description provided for @safetyTip4Title.
  ///
  /// In ro, this message translates to:
  /// **'Nu distribui date personale'**
  String get safetyTip4Title;

  /// No description provided for @safetyTip4Desc.
  ///
  /// In ro, this message translates to:
  /// **'Nu ai nevoie să dai adresa de acasă, CNP sau alte date sensibile ca să faci un schimb.'**
  String get safetyTip4Desc;

  /// No description provided for @safetyTip5Title.
  ///
  /// In ro, this message translates to:
  /// **'Verifică rating-ul și scorul de încredere'**
  String get safetyTip5Title;

  /// No description provided for @safetyTip5Desc.
  ///
  /// In ro, this message translates to:
  /// **'Un istoric bun de schimburi finalizate e un semn bun înainte să te întâlnești cu cineva.'**
  String get safetyTip5Desc;

  /// No description provided for @safetyTip6Title.
  ///
  /// In ro, this message translates to:
  /// **'O poză de profil reală crește încrederea'**
  String get safetyTip6Title;

  /// No description provided for @safetyTip6Desc.
  ///
  /// In ro, this message translates to:
  /// **'Profilurile cu poză și bio completă inspiră mai multă siguranță celorlalți utilizatori.'**
  String get safetyTip6Desc;

  /// No description provided for @safetyTip7Title.
  ///
  /// In ro, this message translates to:
  /// **'Verifică starea cărții înainte de schimb'**
  String get safetyTip7Title;

  /// No description provided for @safetyTip7Desc.
  ///
  /// In ro, this message translates to:
  /// **'Compară cartea cu descrierea din anunț înainte să confirmi schimbul ca finalizat.'**
  String get safetyTip7Desc;

  /// No description provided for @safetyTip8Title.
  ///
  /// In ro, this message translates to:
  /// **'Raportează orice comportament suspect'**
  String get safetyTip8Title;

  /// No description provided for @safetyTip8Desc.
  ///
  /// In ro, this message translates to:
  /// **'Poți raporta sau bloca un utilizator direct din profilul lui sau din conversație.'**
  String get safetyTip8Desc;

  /// No description provided for @helpCenterTitle.
  ///
  /// In ro, this message translates to:
  /// **'Întrebări frecvente'**
  String get helpCenterTitle;

  /// No description provided for @helpFaq1Question.
  ///
  /// In ro, this message translates to:
  /// **'Cum funcționează un schimb de cărți?'**
  String get helpFaq1Question;

  /// No description provided for @helpFaq1Answer.
  ///
  /// In ro, this message translates to:
  /// **'Ceri o carte din anunțul altcuiva (poți oferi și tu o carte în schimb), proprietarul acceptă sau refuză, apoi vă stabiliți o întâlnire prin chat. După ce faceți schimbul în realitate, oricare dintre voi marchează schimbul ca finalizat.'**
  String get helpFaq1Answer;

  /// No description provided for @helpFaq2Question.
  ///
  /// In ro, this message translates to:
  /// **'Ce e Scorul de încredere?'**
  String get helpFaq2Question;

  /// No description provided for @helpFaq2Answer.
  ///
  /// In ro, this message translates to:
  /// **'Un indicator 0-100 calculat automat din activitatea din aplicație: vechimea contului, email verificat, câte schimburi ai finalizat, rating-ul primit, cât de des răspunzi și cât de rar anulezi cereri. Nu e o verificare de identitate, doar un semnal de comportament.'**
  String get helpFaq2Answer;

  /// No description provided for @helpFaq3Question.
  ///
  /// In ro, this message translates to:
  /// **'Cum se calculează prețul „din librării”?'**
  String get helpFaq3Question;

  /// No description provided for @helpFaq3Answer.
  ///
  /// In ro, this message translates to:
  /// **'Când adaugi o carte cu ISBN, încercăm să găsim prețul de listă pe Google Books. Acoperirea e parțială - nu toate cărțile au preț disponibil acolo, mai ales edițiile mai vechi sau românești.'**
  String get helpFaq3Answer;

  /// No description provided for @helpFaq4Question.
  ///
  /// In ro, this message translates to:
  /// **'Ce înseamnă „Preț fix, nenegociabil”?'**
  String get helpFaq4Question;

  /// No description provided for @helpFaq4Answer.
  ///
  /// In ro, this message translates to:
  /// **'Dacă cel care vinde o carte bifează asta, cumpărătorii nu mai pot trimite oferte de preț - cartea se cumpără doar la prețul afișat.'**
  String get helpFaq4Answer;

  /// No description provided for @helpFaq5Question.
  ///
  /// In ro, this message translates to:
  /// **'Cum raportez sau blochez un utilizator?'**
  String get helpFaq5Question;

  /// No description provided for @helpFaq5Answer.
  ///
  /// In ro, this message translates to:
  /// **'Din meniul din colțul din dreapta sus al unei conversații, sau din pagina de detalii a unui anunț (iconița de steag). Blocarea oprește mesajele în ambele direcții.'**
  String get helpFaq5Answer;

  /// No description provided for @helpFaq6Question.
  ///
  /// In ro, this message translates to:
  /// **'Ce se întâmplă cu cartea după ce o vând sau o dau la schimb?'**
  String get helpFaq6Question;

  /// No description provided for @helpFaq6Answer.
  ///
  /// In ro, this message translates to:
  /// **'Anunțul devine indisponibil definitiv. Dacă persoana care a primit-o vrea să o listeze mai departe, poate face asta din ecranul de Schimburi/Oferte (\"Adaugă în biblioteca ta\") - istoricul cărții rămâne urmăribil pe pagina ei de detalii, cu poze puse de fiecare proprietar.'**
  String get helpFaq6Answer;

  /// No description provided for @helpFaq7Question.
  ///
  /// In ro, this message translates to:
  /// **'De ce nu-mi apare o carte în Categorii sau la Cărți similare?'**
  String get helpFaq7Question;

  /// No description provided for @helpFaq7Answer.
  ///
  /// In ro, this message translates to:
  /// **'Genul unei cărți vine din Open Library sau Google Books la adăugare - unele cărți nu au gen completat în sursele externe, mai ales edițiile mai puțin populare.'**
  String get helpFaq7Answer;

  /// No description provided for @helpCenterFooter.
  ///
  /// In ro, this message translates to:
  /// **'Nu ai găsit răspunsul? Poți raporta o problemă direct din conversația cu utilizatorul implicat.'**
  String get helpCenterFooter;

  /// No description provided for @adminLoadError.
  ///
  /// In ro, this message translates to:
  /// **'Nu am putut încărca datele de admin.'**
  String get adminLoadError;

  /// No description provided for @adminStatsTitle.
  ///
  /// In ro, this message translates to:
  /// **'Statistici'**
  String get adminStatsTitle;

  /// No description provided for @adminUsersCount.
  ///
  /// In ro, this message translates to:
  /// **'Utilizatori ({count})'**
  String adminUsersCount(int count);

  /// No description provided for @adminInactiveListingsCount.
  ///
  /// In ro, this message translates to:
  /// **'Anunțuri fără nicio cerere ({count})'**
  String adminInactiveListingsCount(int count);

  /// No description provided for @adminInactiveListingsDesc.
  ///
  /// In ro, this message translates to:
  /// **'Cărți puse la schimb pentru care nimeni nu a trimis nicio cerere.'**
  String get adminInactiveListingsDesc;

  /// No description provided for @adminNoInactiveListings.
  ///
  /// In ro, this message translates to:
  /// **'Niciun anunț inactiv.'**
  String get adminNoInactiveListings;

  /// No description provided for @adminUserReportsCount.
  ///
  /// In ro, this message translates to:
  /// **'Rapoarte utilizatori ({count})'**
  String adminUserReportsCount(int count);

  /// No description provided for @adminNoReports.
  ///
  /// In ro, this message translates to:
  /// **'Niciun raport.'**
  String get adminNoReports;

  /// No description provided for @adminUpcomingReleasesCount.
  ///
  /// In ro, this message translates to:
  /// **'Cărți viitoare ({count})'**
  String adminUpcomingReleasesCount(int count);

  /// No description provided for @adminUpcomingReleasesDesc.
  ///
  /// In ro, this message translates to:
  /// **'Afișate pe ecranul principal, în secțiunea \"Cărți viitoare\".'**
  String get adminUpcomingReleasesDesc;

  /// No description provided for @adminNoUpcomingReleases.
  ///
  /// In ro, this message translates to:
  /// **'Nicio carte viitoare adăugată.'**
  String get adminNoUpcomingReleases;

  /// No description provided for @adminFeedbackCount.
  ///
  /// In ro, this message translates to:
  /// **'Feedback primit ({count})'**
  String adminFeedbackCount(int count);

  /// No description provided for @adminNoFeedback.
  ///
  /// In ro, this message translates to:
  /// **'Niciun feedback trimis încă.'**
  String get adminNoFeedback;

  /// No description provided for @adminSupportRequestsCount.
  ///
  /// In ro, this message translates to:
  /// **'Mesaje de support ({count})'**
  String adminSupportRequestsCount(int count);

  /// No description provided for @adminNoSupportRequests.
  ///
  /// In ro, this message translates to:
  /// **'Niciun mesaj de support trimis încă.'**
  String get adminNoSupportRequests;

  /// No description provided for @adminReportedBy.
  ///
  /// In ro, this message translates to:
  /// **'Raportat de {name}'**
  String adminReportedBy(String name);

  /// No description provided for @adminUnknownAuthor.
  ///
  /// In ro, this message translates to:
  /// **'Autor necunoscut'**
  String get adminUnknownAuthor;

  /// No description provided for @adminAuthorOptional.
  ///
  /// In ro, this message translates to:
  /// **'Autor (opțional)'**
  String get adminAuthorOptional;

  /// No description provided for @adminCoverUrlOptional.
  ///
  /// In ro, this message translates to:
  /// **'URL copertă (opțional)'**
  String get adminCoverUrlOptional;

  /// No description provided for @adminPickReleaseDate.
  ///
  /// In ro, this message translates to:
  /// **'Alege data lansării'**
  String get adminPickReleaseDate;

  /// No description provided for @adminReleaseDateLabel.
  ///
  /// In ro, this message translates to:
  /// **'Lansare: {date}'**
  String adminReleaseDateLabel(String date);

  /// No description provided for @adminAdd.
  ///
  /// In ro, this message translates to:
  /// **'Adaugă'**
  String get adminAdd;

  /// No description provided for @adminTitleDateRequired.
  ///
  /// In ro, this message translates to:
  /// **'Titlul și data lansării sunt obligatorii'**
  String get adminTitleDateRequired;

  /// No description provided for @adminAddBookError.
  ///
  /// In ro, this message translates to:
  /// **'Nu am putut adăuga cartea'**
  String get adminAddBookError;

  /// No description provided for @adminDeleteUserTitle.
  ///
  /// In ro, this message translates to:
  /// **'Șterge utilizatorul?'**
  String get adminDeleteUserTitle;

  /// No description provided for @adminDeleteUserBody.
  ///
  /// In ro, this message translates to:
  /// **'Se șterg definitiv contul lui {name} și toate datele asociate (cărți, schimburi, mesaje). Nu se poate anula.'**
  String adminDeleteUserBody(String name);

  /// No description provided for @adminStatsUsersLabel.
  ///
  /// In ro, this message translates to:
  /// **'Utilizatori'**
  String get adminStatsUsersLabel;

  /// No description provided for @adminStatsUsersSubtitle.
  ///
  /// In ro, this message translates to:
  /// **'din care {count} verificați'**
  String adminStatsUsersSubtitle(int count);

  /// No description provided for @adminStatsBooksLabel.
  ///
  /// In ro, this message translates to:
  /// **'Cărți în catalog'**
  String get adminStatsBooksLabel;

  /// No description provided for @adminStatsBooksSubtitle.
  ///
  /// In ro, this message translates to:
  /// **'{count} exemplare listate'**
  String adminStatsBooksSubtitle(int count);

  /// No description provided for @adminStatsExchangesLabel.
  ///
  /// In ro, this message translates to:
  /// **'Schimburi'**
  String get adminStatsExchangesLabel;

  /// No description provided for @adminStatsExchangesSubtitle.
  ///
  /// In ro, this message translates to:
  /// **'{completed} finalizate · {pending} în așteptare'**
  String adminStatsExchangesSubtitle(int completed, int pending);

  /// No description provided for @auctionTitle.
  ///
  /// In ro, this message translates to:
  /// **'Licitație'**
  String get auctionTitle;

  /// No description provided for @auctionCurrentPrice.
  ///
  /// In ro, this message translates to:
  /// **'Preț curent'**
  String get auctionCurrentPrice;

  /// No description provided for @auctionBidsCount.
  ///
  /// In ro, this message translates to:
  /// **'oferte'**
  String get auctionBidsCount;

  /// No description provided for @auctionReserveMet.
  ///
  /// In ro, this message translates to:
  /// **'Prețul de rezervă a fost atins'**
  String get auctionReserveMet;

  /// No description provided for @auctionReserveNotMet.
  ///
  /// In ro, this message translates to:
  /// **'Prețul de rezervă nu a fost încă atins'**
  String get auctionReserveNotMet;

  /// No description provided for @auctionEndedWithWinner.
  ///
  /// In ro, this message translates to:
  /// **'Licitația s-a încheiat - a câștigat cineva'**
  String get auctionEndedWithWinner;

  /// No description provided for @auctionEndedNoWinner.
  ///
  /// In ro, this message translates to:
  /// **'Licitația s-a încheiat fără câștigător'**
  String get auctionEndedNoWinner;

  /// No description provided for @auctionBidAmountLabel.
  ///
  /// In ro, this message translates to:
  /// **'Ofertă (minim {amount} lei)'**
  String auctionBidAmountLabel(String amount);

  /// No description provided for @auctionPlaceBid.
  ///
  /// In ro, this message translates to:
  /// **'Licitează'**
  String get auctionPlaceBid;

  /// No description provided for @auctionBuyNowFor.
  ///
  /// In ro, this message translates to:
  /// **'Cumpără acum cu {amount} lei'**
  String auctionBuyNowFor(String amount);

  /// No description provided for @auctionBidHistory.
  ///
  /// In ro, this message translates to:
  /// **'Istoricul ofertelor'**
  String get auctionBidHistory;

  /// No description provided for @auctionNoBidsYet.
  ///
  /// In ro, this message translates to:
  /// **'Nicio ofertă încă'**
  String get auctionNoBidsYet;

  /// No description provided for @auctionWatch.
  ///
  /// In ro, this message translates to:
  /// **'Urmărește licitația'**
  String get auctionWatch;

  /// No description provided for @auctionBidPlaced.
  ///
  /// In ro, this message translates to:
  /// **'Ofertă plasată'**
  String get auctionBidPlaced;

  /// No description provided for @auctionBoughtNow.
  ///
  /// In ro, this message translates to:
  /// **'Cumpărat cu succes'**
  String get auctionBoughtNow;

  /// No description provided for @auctionGenericError.
  ///
  /// In ro, this message translates to:
  /// **'A apărut o eroare, încearcă din nou'**
  String get auctionGenericError;

  /// No description provided for @auctionEnded.
  ///
  /// In ro, this message translates to:
  /// **'Încheiată'**
  String get auctionEnded;

  /// No description provided for @auctionEndsInDays.
  ///
  /// In ro, this message translates to:
  /// **'se încheie în {days} zile'**
  String auctionEndsInDays(int days);

  /// No description provided for @auctionEndsInHours.
  ///
  /// In ro, this message translates to:
  /// **'se încheie în {hours} h'**
  String auctionEndsInHours(int hours);

  /// No description provided for @auctionEndsInMinutes.
  ///
  /// In ro, this message translates to:
  /// **'se încheie în {minutes} min'**
  String auctionEndsInMinutes(int minutes);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['de', 'en', 'hu', 'ro'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'de':
      return AppLocalizationsDe();
    case 'en':
      return AppLocalizationsEn();
    case 'hu':
      return AppLocalizationsHu();
    case 'ro':
      return AppLocalizationsRo();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
