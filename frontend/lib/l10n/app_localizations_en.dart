// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get navHome => 'Home';

  @override
  String get navSearch => 'Discover';

  @override
  String get navLibrary => 'My Shelf';

  @override
  String get navChat => 'Chat';

  @override
  String get navProfile => 'Profile';

  @override
  String get commonCancel => 'Cancel';

  @override
  String get commonSubmit => 'Submit';

  @override
  String get commonSave => 'Save';

  @override
  String get commonSeeAll => 'See all';

  @override
  String get commonUnknownUser => 'User';

  @override
  String get commonAbout => 'About';

  @override
  String get commonRating => 'Rating';

  @override
  String get commonBooksExchanged => 'Books exchanged';

  @override
  String get commonRetry => 'Try again';

  @override
  String get commonDone => 'Done';

  @override
  String get commonClose => 'Close';

  @override
  String get commonDelete => 'Delete';

  @override
  String get commonConfirm => 'Confirm';

  @override
  String get continueWithGoogle => 'Continue with Google';

  @override
  String get reportDialogTitle => 'Report';

  @override
  String get trustScoreTitle => 'Trust Score';

  @override
  String get trustScoreSubtitle =>
      'Calculated from in-app activity - not an identity verification';

  @override
  String get trustScoreEmailVerified => 'Email verified';

  @override
  String trustScoreCompletedRate(int percent) {
    return '$percent% completed exchanges';
  }

  @override
  String trustScoreRespondsIn(String time) {
    return 'Responds in ~$time';
  }

  @override
  String get trustScoreLastActiveToday => 'Active today';

  @override
  String trustScoreLastActiveDays(int days) {
    return 'Active $days days ago';
  }

  @override
  String trustScoreResponseRate(int percent) {
    return '$percent% response rate';
  }

  @override
  String trustScoreAverageSwapTime(String time) {
    return 'Completes a swap in ~$time';
  }

  @override
  String memberSinceDays(int days) {
    return 'Member for $days days';
  }

  @override
  String memberSinceMonths(int months) {
    return 'Member for $months months';
  }

  @override
  String memberSinceYears(int years) {
    return 'Member for $years years';
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
    return '$days days';
  }

  @override
  String priceLei(String amount) {
    return '$amount lei';
  }

  @override
  String get bookAvailableForSwapShort => 'Swap';

  @override
  String get commonEmailLabel => 'Email';

  @override
  String get commonEmailInvalid => 'Invalid email';

  @override
  String get commonOr => 'or';

  @override
  String get commonRequired => 'Required';

  @override
  String get commonContinue => 'Continue';

  @override
  String get loginWelcomeBack => 'Welcome back';

  @override
  String get authPasswordLabel => 'Password';

  @override
  String get authEnterPasswordError => 'Enter your password';

  @override
  String get authMinEightChars => 'At least 8 characters';

  @override
  String get authForgotPasswordLink => 'Forgot your password?';

  @override
  String get authLoginSubmit => 'Sign in';

  @override
  String get authNoAccount => 'Don\'t have an account? ';

  @override
  String get authCreateOne => 'Create one';

  @override
  String get authGoogleFailed => 'Google sign-in failed. Please try again.';

  @override
  String get supportContactButton => 'Can\'t log in? Contact us';

  @override
  String get supportDialogTitle => 'Contact support';

  @override
  String get supportDialogSubtitle =>
      'Tell us what\'s wrong and we\'ll reply by email.';

  @override
  String get supportNameLabel => 'Name';

  @override
  String get supportPhoneLabel => 'Phone (optional)';

  @override
  String get supportMessageLabel => 'Your message';

  @override
  String get supportCaptchaAnswerLabel => 'Your answer';

  @override
  String get supportSubmit => 'Send message';

  @override
  String get supportSuccessMessage =>
      'Message sent! We\'ll get back to you by email soon.';

  @override
  String get supportGenericError => 'Couldn\'t send the message. Try again.';

  @override
  String get authRegisterTitle => 'Create account';

  @override
  String get authRegisterSubtitle => 'Join the ShelfShare community';

  @override
  String get authReferralCodeLabel => 'Referral code (optional)';

  @override
  String get verifyCodeTooShort => 'The code must have 6 digits';

  @override
  String get verifySuccessSnackbar => 'Account confirmed successfully!';

  @override
  String get verifyInvalidOrExpired => 'Invalid or expired code.';

  @override
  String get verifyResendSnackbar => 'We\'ve resent the code, if applicable.';

  @override
  String get verifyEmailHeading => 'Verify your email';

  @override
  String verifySentTo(String email) {
    return 'We\'ve sent a confirmation code to $email';
  }

  @override
  String get verifyConfirmButton => 'Confirm';

  @override
  String get verifyResending => 'Resending...';

  @override
  String get verifyResendPrompt => 'Didn\'t get the code? Resend';

  @override
  String get forgotPasswordTitle => 'Reset password';

  @override
  String get forgotPasswordSubtitle => 'We\'ll send you a reset code by email.';

  @override
  String get forgotPasswordSubmit => 'Send code';

  @override
  String get forgotPasswordCodeHeading => 'Enter the code from your email';

  @override
  String forgotPasswordCodeSentTo(String email) {
    return 'We sent a reset code to $email';
  }

  @override
  String get resetPasswordTitle => 'Set a new password';

  @override
  String get resetPasswordSubtitle => 'Choose a new password for your account';

  @override
  String get resetPasswordNewLabel => 'New password';

  @override
  String get resetPasswordSubmit => 'Set password';

  @override
  String get resetPasswordSuccessHeading => 'Password changed';

  @override
  String get resetPasswordSuccessBody =>
      'Your password has been updated. You can log in now.';

  @override
  String get resetPasswordGoToLogin => 'Go to login';

  @override
  String get resetPasswordGenericError =>
      'Couldn\'t reset the password. Try again.';

  @override
  String get authConfirmPasswordLabel => 'Confirm password';

  @override
  String get authPasswordMismatch => 'Passwords don\'t match';

  @override
  String get onboardingTitle => 'Almost there!';

  @override
  String get onboardingSubtitle => 'Tell us how you\'d like others to see you';

  @override
  String get onboardingFirstName => 'First name';

  @override
  String get onboardingLastName => 'Last name';

  @override
  String get onboardingUsername => 'Username';

  @override
  String get onboardingUsernameFormatError =>
      '3-20 characters: letters, digits or underscore';

  @override
  String get onboardingGenericError =>
      'Something went wrong. Please try again.';

  @override
  String get onboardingNameVisibleSwitch => 'Make my name publicly visible';

  @override
  String get onboardingUsernameAlwaysVisible =>
      'Your username always stays visible';

  @override
  String get profileTitle => 'My profile';

  @override
  String get surveyTitle => 'What do you like to read?';

  @override
  String get surveySubtitle =>
      'A few answers let us recommend listed books that suit you, plus a heads-up when one shows up in your taste.';

  @override
  String get surveyGenresQuestion => 'Which genres appeal to you?';

  @override
  String get surveyGenresLoadError => 'We could not load the genre list.';

  @override
  String get surveyAuthorsQuestion => 'Favourite authors (optional)';

  @override
  String get surveyAuthorsHint => 'e.g. Mihail Sadoveanu, Ursula K. Le Guin';

  @override
  String get surveyPaceQuestion => 'How many books do you read a month?';

  @override
  String get surveySubmit => 'Save';

  @override
  String get surveySkip => 'Skip for now';

  @override
  String get surveySaveError =>
      'We could not save your answers. Please try again.';

  @override
  String get surveyChangeLaterHint =>
      'You can change your answers anytime from your profile.';

  @override
  String surveyPaceOption(String pace) {
    return '$pace books a month';
  }

  @override
  String get profilePhotoChoose => 'Choose a photo';

  @override
  String get profilePhotoRemove => 'Remove photo';

  @override
  String get profilePhotoError => 'We could not update your profile photo.';

  @override
  String get profileCopyLink => 'Copy link';

  @override
  String get profileLoadError => 'We couldn\'t load your profile.';

  @override
  String get profileAboutMe => 'About me';

  @override
  String get profileBadgesTitle => 'Badges';

  @override
  String get profileMyExchanges => 'My exchanges';

  @override
  String get profileSafetyCenter => 'Safety center';

  @override
  String get profileHelpCenter => 'FAQ';

  @override
  String get profileLeaderboard => 'Leaderboard';

  @override
  String get profileSendFeedback => 'Send feedback';

  @override
  String get profileEditProfile => 'Edit profile';

  @override
  String get profileAdminPanel => 'Admin panel';

  @override
  String get profileLogout => 'Log out';

  @override
  String get profileLanguage => 'Language';

  @override
  String get profileDarkModeSection => 'Dark Mode';

  @override
  String get profileThemeSystem => 'Automatic (system)';

  @override
  String get profileThemeLight => 'Light';

  @override
  String get profileThemeDark => 'Dark';

  @override
  String get profileQrTooltip => 'QR code';

  @override
  String get profileQrDialogTitle => 'Your QR code';

  @override
  String get profileQrDialogBody =>
      'Anyone who scans this code can open your profile.';

  @override
  String get profileReferralTitle => 'Your referral code';

  @override
  String get profileReferralSubtitle =>
      'Share it with friends so they can find you on ShelfShare';

  @override
  String profileReferralCountLabel(int count) {
    return '$count friends invited';
  }

  @override
  String get profileReferralCopied => 'Code copied to clipboard';

  @override
  String get profileFeedbackHint => 'What would you like to tell us?';

  @override
  String get profileFeedbackThanks => 'Thanks for your feedback!';

  @override
  String get profileFeedbackError => 'We couldn\'t send your feedback';

  @override
  String get profileUsernameLabel => 'Username';

  @override
  String get profileCityLabel => 'City';

  @override
  String get profileNoCity => 'No city';

  @override
  String get profileShowAcquisitionHistory =>
      'Show acquisition history on profile';

  @override
  String get profileShowAcquisitionHistorySubtitle =>
      'Books you\'ve received through exchanges or purchases in the app';

  @override
  String get profileSaveError => 'We couldn\'t save your profile.';

  @override
  String get commonSendMessage => 'Send message';

  @override
  String get publicProfileTitle => 'Profile';

  @override
  String get publicProfileFollowUpdateError =>
      'We couldn\'t update the follow status';

  @override
  String get publicProfileMessageError =>
      'We couldn\'t start the conversation.';

  @override
  String publicProfileMemberSince(int year) {
    return 'Member since $year';
  }

  @override
  String publicProfileFollowersFollowing(int followers, int following) {
    return '$followers followers · $following following';
  }

  @override
  String get publicProfileUnfollow => 'Unfollow';

  @override
  String get publicProfileFollow => 'Follow';

  @override
  String get publicProfileReadingStats => 'Reading stats';

  @override
  String get publicProfileBooksListed => 'Books listed';

  @override
  String get publicProfileTotalPages => 'Total pages';

  @override
  String get publicProfileFavoriteGenre => 'Favorite genre';

  @override
  String get publicProfileBooksShared => 'Books shared';

  @override
  String get publicProfileBooksReceived => 'Books received';

  @override
  String get publicProfileLongestBook => 'Longest book';

  @override
  String publicProfileListedBooksCount(int count) {
    return 'Listed books ($count)';
  }

  @override
  String get publicProfileAcquisitionHistory =>
      'History of books received in the app';

  @override
  String get publicProfileNoAcquisitions =>
      'No completed exchange or purchase yet.';

  @override
  String publicProfileReviewsCount(int count) {
    return 'Reviews ($count)';
  }

  @override
  String get leaderboardEmpty => 'No city with activity yet.';

  @override
  String get leaderboardUnknownCity => 'Unknown';

  @override
  String leaderboardExchangesCount(int count) {
    return '$count exchanges';
  }

  @override
  String get leaderboardLoadError => 'We couldn\'t load the leaderboard.';

  @override
  String get leaderboardTabCity => 'By city';

  @override
  String get leaderboardTabNational => 'National';

  @override
  String get leaderboardTabTopReaders => 'Readers';

  @override
  String leaderboardPagesCount(int count) {
    return '$count pages';
  }

  @override
  String get profileGlobalStats => 'Global statistics';

  @override
  String get profileMyBookshelf => 'My bookshelf';

  @override
  String get bookshelfTitle => 'My bookshelf';

  @override
  String get bookshelfTabReading => 'Reading';

  @override
  String get bookshelfTabWantToRead => 'Want to read';

  @override
  String get bookshelfTabFinished => 'Finished';

  @override
  String get bookshelfTabShared => 'Shared';

  @override
  String get bookshelfEmpty => 'No books here yet.';

  @override
  String get bookshelfLoadError => 'Couldn\'t load the bookshelf.';

  @override
  String get bookshelfImportTooltip => 'Import from Goodreads or StoryGraph';

  @override
  String get bookshelfImportGoodreads => 'Import from Goodreads (CSV)';

  @override
  String get bookshelfImportStoryGraph => 'Import from StoryGraph (CSV)';

  @override
  String bookshelfImportSummary(int imported, int skipped) {
    return '$imported books imported, $skipped skipped';
  }

  @override
  String get bookshelfImportError =>
      'Couldn\'t import the file. Check that it\'s a valid CSV export.';

  @override
  String get bookDetailShelfSectionTitle => 'Add to your bookshelf';

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
    return '$xp XP to next level';
  }

  @override
  String gamificationStreak(int days) {
    return '$days-day streak';
  }

  @override
  String gamificationLongestStreak(int days) {
    return 'Best: $days days';
  }

  @override
  String get profileMonthlyChallenges => 'Monthly challenges';

  @override
  String get monthlyChallengesTitle => 'Monthly challenges';

  @override
  String get profileReadingChallenge => 'Reading challenge';

  @override
  String readingChallengeTitle(int year) {
    return '$year reading challenge';
  }

  @override
  String get readingChallengeNoGoal =>
      'You haven\'t set a goal for this year yet.';

  @override
  String readingChallengeProgress(int progress, int goal) {
    return '$progress of $goal books finished';
  }

  @override
  String get readingChallengeSetGoal => 'Set a goal';

  @override
  String get readingChallengeGoalLabel =>
      'How many books do you want to finish this year?';

  @override
  String get profileActivityFeed => 'Recent activity';

  @override
  String get activityFeedTitle => 'Recent activity';

  @override
  String get activityFeedEmpty =>
      'No activity yet - follow other users to see what they\'re reading.';

  @override
  String get activityFeedLoadError => 'Couldn\'t load activity.';

  @override
  String activityNewListing(String name) {
    return '$name listed a new book';
  }

  @override
  String activityFinishedBook(String name) {
    return '$name finished reading';
  }

  @override
  String activityCompletedExchange(String name) {
    return '$name completed a swap';
  }

  @override
  String get bookDetailShelfRemove => 'Remove from shelf';

  @override
  String get publicProfileBookshelfTitle => 'Bookshelf';

  @override
  String get globalStatsTitle => 'Global statistics';

  @override
  String get globalStatsTabMostShared => 'Most shared';

  @override
  String get globalStatsTabTrending => 'Trending';

  @override
  String get globalStatsTabPopularAuthors => 'Popular authors';

  @override
  String get globalStatsEmpty => 'No data yet.';

  @override
  String get globalStatsLoadError => 'Couldn\'t load the statistics.';

  @override
  String globalStatsTransferCount(int count) {
    return '$count swaps/sales';
  }

  @override
  String globalStatsViewCount(int count) {
    return '$count views (14 days)';
  }

  @override
  String get profileFavoriteSellers => 'Favorite sellers';

  @override
  String get favoriteSellersTitle => 'Favorite sellers';

  @override
  String get favoriteSellersEmpty => 'You\'re not following anyone yet.';

  @override
  String get favoriteSellersLoadError => 'Couldn\'t load the list.';

  @override
  String get publicProfileTopGenres => 'Favorite genres';

  @override
  String get impactStatsTitle => 'Impact';

  @override
  String get impactStatsTotalValue => 'Total value exchanged';

  @override
  String get impactStatsMoneySaved => 'Money saved';

  @override
  String get impactStatsCo2Saved => 'CO₂ saved (estimated)';

  @override
  String impactStatsCo2Value(String kg) {
    return '$kg kg';
  }

  @override
  String homeGreeting(String name) {
    return 'Hi, $name!';
  }

  @override
  String get homeWelcome => 'Welcome!';

  @override
  String get homeLoadError => 'We couldn\'t load the books.';

  @override
  String get homeEmpty => 'No books available yet.';

  @override
  String get homeCategories => 'Categories';

  @override
  String get homeRecentlyAdded => 'Recently added';

  @override
  String get homeMostViewed => 'Most viewed';

  @override
  String get homeMostSearched => 'Most sought after';

  @override
  String get homeSeeAll => 'See all';

  @override
  String get homeFeedEnd => 'You\'ve seen all the books';

  @override
  String get homeNearYou => 'Near your city';

  @override
  String get homeNearYouToday => 'Near you today';

  @override
  String get homeRecommendedForYou => 'Recommended for you';

  @override
  String get homeHiddenGems => 'Hidden gems';

  @override
  String get homeCompleteYourCollection => 'Complete your collection';

  @override
  String get homeSimilarTaste => 'Similar taste';

  @override
  String get profileSmartMatches => 'Smart swap matches';

  @override
  String get smartMatchesTitle => 'Smart swap matches';

  @override
  String get smartMatchesEmpty =>
      'No matches yet - add books to your wishlist and list some available books.';

  @override
  String get smartMatchesLoadError => 'Couldn\'t load matches.';

  @override
  String get smartMatchesTheyHave => 'Has what you want';

  @override
  String get smartMatchesTheyWant => 'Wants what you have';

  @override
  String get homeUpcomingBooks => 'Upcoming books';

  @override
  String get homeActiveMembers => 'Active members';

  @override
  String get browseTitle => 'Search books';

  @override
  String get browseMapTooltip => 'Map of nearby books';

  @override
  String get browseSearchHint => 'Search by title';

  @override
  String get browseEmpty => 'No books found.';

  @override
  String get filtersTitle => 'Filters';

  @override
  String get filtersAuthor => 'Author';

  @override
  String get filtersGenre => 'Genre';

  @override
  String get filtersLanguage => 'Language';

  @override
  String get filtersAnyCity => 'Any city';

  @override
  String get filtersCondition => 'Condition';

  @override
  String get bookConditionNew => 'New';

  @override
  String get bookConditionVeryGood => 'Very good';

  @override
  String get bookConditionGood => 'Good';

  @override
  String get bookConditionAcceptable => 'Acceptable';

  @override
  String get filtersAnyCondition => 'Any condition';

  @override
  String get filtersListingType => 'Listing type';

  @override
  String get filtersListingTypeSwap => 'Swap';

  @override
  String get filtersListingTypeSale => 'Sale';

  @override
  String get filtersListingTypeAuction => 'Auction';

  @override
  String get filtersNearbyOnly => 'Nearby only';

  @override
  String get filtersNearbyOnlyHintOff =>
      'Sort and filter by actual distance from your city';

  @override
  String filtersNearbyOnlyHintOn(int km) {
    return 'Up to $km km from your city';
  }

  @override
  String filtersDistanceKm(int km) {
    return '$km km';
  }

  @override
  String get filtersReset => 'Reset';

  @override
  String get filtersApply => 'Apply filters';

  @override
  String get commonYes => 'Yes';

  @override
  String get commonNo => 'No';

  @override
  String get commonGiveUp => 'Cancel';

  @override
  String get libraryTitle => 'My Shelf';

  @override
  String get libraryViewAsList => 'View as list';

  @override
  String get libraryViewAsGrid => 'View as grid';

  @override
  String get libraryExportCsv => 'Export to CSV';

  @override
  String get libraryBulkAdd => 'Add multiple books (scan)';

  @override
  String get libraryImportCsv => 'Import listings from CSV';

  @override
  String libraryImportSummary(int created, int failed) {
    return '$created listings created, $failed failed';
  }

  @override
  String get libraryImportError =>
      'Couldn\'t import the file. Check that it\'s a valid CSV.';

  @override
  String get libraryEmpty => 'You don\'t have any books in your library yet.';

  @override
  String get libraryLoadError => 'We couldn\'t load your library.';

  @override
  String get libraryAvailable => 'Available';

  @override
  String get libraryUnavailable => 'Unavailable';

  @override
  String get libraryDeleteConfirmTitle => 'Delete this book?';

  @override
  String libraryDeleteConfirmBody(String title) {
    return '\"$title\" will be removed from your library.';
  }

  @override
  String get libraryAvailableForSwap => 'Available for exchange';

  @override
  String get libraryDeleteBook => 'Delete book';

  @override
  String get libraryEditListing => 'Edit listing';

  @override
  String get libraryEditListingTitle => 'Edit listing';

  @override
  String get libraryEditListingSuccess => 'Listing updated.';

  @override
  String get csvHeaderTitle => 'Title';

  @override
  String get csvHeaderAvailableForSwap => 'Available for exchange';

  @override
  String get csvHeaderForSale => 'For sale';

  @override
  String get csvHeaderPrice => 'Price';

  @override
  String get addBookTitle => 'Add a book';

  @override
  String get addBookSearchHint => 'Title or ISBN';

  @override
  String get addBookSearchButton => 'Search';

  @override
  String get addBookSearchFailed => 'Search failed. Please try again.';

  @override
  String get addBookSearchPrompt => 'Search for a book by title or ISBN.';

  @override
  String get addBookManualEntry => 'Add manually';

  @override
  String get addBookNotFoundManual => 'Can\'t find the book? Add it manually';

  @override
  String get addBookChange => 'Change';

  @override
  String get addBookTitleLabel => 'Title';

  @override
  String get addBookSearchInstead => 'Search instead';

  @override
  String get addBookLanguageOptional => 'Language (optional)';

  @override
  String get addBookEditionOptional => 'Edition (optional)';

  @override
  String get addBookHardcoverSwitch => 'Hardcover edition';

  @override
  String get addBookForSaleSwitch => 'For sale';

  @override
  String get addBookForSaleHint =>
      'Besides exchange, you can sell the book for a fixed price';

  @override
  String get addBookPriceLabel => 'Price (lei)';

  @override
  String get addBookNonNegotiable => 'Fixed price, non-negotiable';

  @override
  String get addBookNonNegotiableHint =>
      'Buyers won\'t be able to make price offers';

  @override
  String get addBookAuctionSwitch => 'Start an auction';

  @override
  String get addBookAuctionHint =>
      'Buyers will bid, the highest offer wins at the end';

  @override
  String get addBookAuctionStartingPrice => 'Starting price';

  @override
  String get addBookAuctionReservePrice => 'Reserve price (optional)';

  @override
  String get addBookAuctionReservePriceHint =>
      'The minimum price below which you won\'t sell';

  @override
  String get addBookAuctionBuyNowPrice => '\"Buy Now\" price (optional)';

  @override
  String get addBookAuctionBuyNowPriceHint =>
      'Only available before the first bid';

  @override
  String get addBookAuctionDuration => 'Auction duration';

  @override
  String get addBookAuctionDuration24h => '24 hours';

  @override
  String get addBookAuctionDuration3d => '3 days';

  @override
  String get addBookAuctionDuration7d => '7 days';

  @override
  String get addBookPhotosLabelRequired =>
      'Photos of the book (required, at least 1)';

  @override
  String get addBookPhotosLabelOptional => 'Photos of the book (optional)';

  @override
  String get addBookSubmit => 'Add to library';

  @override
  String get addBookTitleRequired => 'Title is required';

  @override
  String get addBookInvalidPrice => 'Enter a valid price';

  @override
  String get addBookNeedPhoto =>
      'Add at least one photo of the book before listing it for sale';

  @override
  String get addBookSuccess => 'Book added to your library';

  @override
  String get addBookGenericError =>
      'We couldn\'t add the book. Please try again.';

  @override
  String get relistNeedPhoto =>
      'Add at least one photo before listing it for sale';

  @override
  String get relistSuccess => 'The book was added to your library';

  @override
  String get relistGenericError => 'We couldn\'t add the book.';

  @override
  String relistHeading(String title) {
    return 'Add \"$title\" to your library';
  }

  @override
  String get relistSubtitle =>
      'Describe the condition you received it in - it stays linked to the book\'s history.';

  @override
  String get mapTitle => 'Nearby books';

  @override
  String get mapLoadError => 'We couldn\'t load the map.';

  @override
  String get mapEmpty => 'No books available yet in any city.';

  @override
  String mapCityBooksCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count books',
      one: '$count book',
    );
    return '$_temp0';
  }

  @override
  String get bookDetailTitle => 'Book details';

  @override
  String get bookDetailReportTooltip => 'Report listing';

  @override
  String bookDetailReportedFrom(String title) {
    return 'Reported from listing \"$title\"';
  }

  @override
  String get bookDetailReportSent => 'Report sent. Thank you!';

  @override
  String get bookDetailReportError => 'We couldn\'t send the report';

  @override
  String get bookDetailLoadError => 'We couldn\'t load the book.';

  @override
  String get bookDetailViewsTitle => 'Views';

  @override
  String get bookDetailViewsLoadError => 'We couldn\'t load the view stats.';

  @override
  String bookDetailUniqueViews(int count) {
    return '$count unique views';
  }

  @override
  String bookDetailTotalViews(int count) {
    return '$count total views, including page reloads';
  }

  @override
  String get bookDetailHardcoverChip => 'Hardcover';

  @override
  String get bookDetailAvailableChip => 'Available for exchange';

  @override
  String bookDetailViewCount(int count) {
    return '$count views';
  }

  @override
  String get bookDetailDescriptionTitle => 'Description';

  @override
  String get bookDetailDetailsTitle => 'Details';

  @override
  String get bookDetailPublisherLabel => 'Publisher';

  @override
  String get bookDetailYearLabel => 'Year published';

  @override
  String get bookDetailPagesLabel => 'Pages';

  @override
  String get bookDetailOwnerTitle => 'Owner';

  @override
  String get bookDetailPhotosTitle => 'Photos';

  @override
  String get bookDetailRequestExchange => 'Request exchange';

  @override
  String get bookDetailUnavailableForExchange => 'Unavailable for exchange';

  @override
  String get bookDetailMakeOffer => 'Make an offer';

  @override
  String get bookDetailHistoryTitle => 'This book\'s history';

  @override
  String get bookDetailHistorySubtitle =>
      'How the book has moved through the app, with photos from each owner.';

  @override
  String get bookDetailHistorySold => 'sold';

  @override
  String get bookDetailHistoryExchanged => 'given in exchange';

  @override
  String bookDetailHistoryListedOn(String date) {
    return 'listed on $date';
  }

  @override
  String bookDetailHistoryTransferredOn(String action, String date) {
    return ' · $action on $date';
  }

  @override
  String get bookDetailHistoryCurrentlyOwned => ' · currently owned';

  @override
  String get bookDetailSimilarBooksTitle => 'Similar books';

  @override
  String bookDetailLibraryPriceLabel(String price) {
    return 'Bookstore price: $price';
  }

  @override
  String bookDetailRequestedTitle(String title) {
    return 'Request \"$title\" for exchange';
  }

  @override
  String get bookDetailNoBooksToOffer =>
      'You don\'t have any books available to offer - you can still send the request without one.';

  @override
  String get bookDetailOfferOneOfYourBooks =>
      'Offer one of your books (optional)';

  @override
  String get bookDetailNoOffer => 'No offer';

  @override
  String get bookDetailMessageOptional => 'Message (optional)';

  @override
  String get bookDetailSendRequest => 'Send request';

  @override
  String get bookDetailRequestSent => 'Exchange request sent';

  @override
  String get bookDetailRequestError => 'We couldn\'t send the request.';

  @override
  String get bookDetailFirstExchangeTitle => 'Your first exchange';

  @override
  String get bookDetailFirstExchangeBody =>
      'A few tips before your first exchange: meet during the day, in a public place, and check the book\'s condition before confirming the exchange as completed.';

  @override
  String get bookDetailUnderstood => 'Got it, continue';

  @override
  String bookDetailMakeOfferTitle(String title) {
    return 'Make an offer for \"$title\"';
  }

  @override
  String bookDetailAskingPrice(String price) {
    return 'Asking price: $price';
  }

  @override
  String get bookDetailOfferAmountLabel => 'Offer amount';

  @override
  String get bookDetailSendOffer => 'Send offer';

  @override
  String get bookDetailOfferSent => 'Offer sent';

  @override
  String get bookDetailOfferError => 'We couldn\'t send the offer.';

  @override
  String get bookDetailInvalidAmount => 'Enter a valid amount';

  @override
  String get commonAddToLibrary => 'Add to your library';

  @override
  String get commonAnonymousUser => 'a user';

  @override
  String get exchangesTitle => 'My exchanges';

  @override
  String get exchangesTabReceived => 'Received exchanges';

  @override
  String get exchangesTabSent => 'Sent exchanges';

  @override
  String get offersTabReceived => 'Received offers';

  @override
  String get offersTabSent => 'Sent offers';

  @override
  String get exchangesEmptyReceived =>
      'You haven\'t received any exchange requests.';

  @override
  String get exchangesEmptySent => 'You haven\'t sent any exchange requests.';

  @override
  String get exchangesLoadError => 'We couldn\'t load your exchanges.';

  @override
  String exchangeRequestedBy(String name) {
    return 'Requested by $name';
  }

  @override
  String exchangeFrom(String name) {
    return 'From $name';
  }

  @override
  String exchangeOffersBook(String title) {
    return 'Offers: $title';
  }

  @override
  String exchangeOffersAmount(String amount) {
    return 'Offers: $amount RON';
  }

  @override
  String get exchangeReject => 'Decline';

  @override
  String get exchangeAccept => 'Accept';

  @override
  String get exchangeCancelRequest => 'Cancel request';

  @override
  String get exchangeScheduleMeeting => 'Schedule meeting';

  @override
  String get exchangeReschedule => 'Reschedule';

  @override
  String get exchangeAddToCalendar => 'Add to calendar';

  @override
  String get exchangeQrCode => 'QR code';

  @override
  String get exchangeMarkComplete => 'Mark as completed';

  @override
  String get exchangeRated => 'Rated';

  @override
  String get exchangeRate => 'Rate';

  @override
  String get exchangeCalendarError => 'We couldn\'t open the calendar.';

  @override
  String get exchangeRatingDialogTitle => 'How was the exchange?';

  @override
  String get exchangeRatingOverall => 'Overall';

  @override
  String get exchangeRatingCommunication => 'Communication';

  @override
  String get exchangeRatingPunctuality => 'Punctuality';

  @override
  String get exchangeRatingCondition => 'Condition of the book received';

  @override
  String get exchangeReviewOptional => 'Review (optional)';

  @override
  String get exchangeQrDialogTitle => 'Confirmation QR code';

  @override
  String get exchangeQrDialogBody =>
      'The other participant scans this code at the meeting to confirm the exchange.';

  @override
  String get exchangeMeetingSheetTitle => 'Schedule the meeting';

  @override
  String get exchangePickDateTime => 'Pick date and time';

  @override
  String get exchangeLocationLabel => 'Location';

  @override
  String get exchangeMeetingSaveError => 'We couldn\'t save the meeting.';

  @override
  String get offersEmptyReceived => 'You haven\'t received any price offers.';

  @override
  String get offersEmptySent => 'You haven\'t sent any price offers.';

  @override
  String get offersLoadError => 'We couldn\'t load your offers.';

  @override
  String offerTo(String name) {
    return 'To $name';
  }

  @override
  String offerAmountLine(String amount) {
    return 'Offer: $amount';
  }

  @override
  String get offerCancel => 'Cancel offer';

  @override
  String get exchangeConfirmTitle => 'Confirm the exchange';

  @override
  String get exchangeConfirmError => 'We couldn\'t confirm the exchange.';

  @override
  String get exchangeConfirmDone => 'Exchange marked as completed!';

  @override
  String get exchangeConfirmQuestion =>
      'Do you confirm the book exchange is complete?';

  @override
  String get exchangeConfirmButton => 'Confirm completion';

  @override
  String get chatEmptyConversations => 'You don\'t have any conversations yet.';

  @override
  String get chatStartConversation => 'Start the conversation';

  @override
  String get chatPhotoPreview => '📷 Photo';

  @override
  String get chatLocationPreview => '📍 Location';

  @override
  String get chatLoadError => 'We couldn\'t load your conversations.';

  @override
  String get chatConversationFallbackTitle => 'Conversation';

  @override
  String get chatUnblock => 'Unblock';

  @override
  String get chatBlock => 'Block';

  @override
  String get chatUserUnblocked => 'User unblocked';

  @override
  String get chatUserBlocked => 'User blocked';

  @override
  String get chatBlockUpdateError => 'We couldn\'t update the block status';

  @override
  String get chatTyping => 'typing...';

  @override
  String get chatSendFailed =>
      'The message could not be sent. Check your connection.';

  @override
  String get chatOnline => 'online';

  @override
  String get chatOffline => 'offline';

  @override
  String get chatLastSeenJustNow => 'last seen just now';

  @override
  String chatLastSeenMinutes(int minutes) {
    return 'last seen $minutes min ago';
  }

  @override
  String chatLastSeenHours(int hours) {
    return 'last seen $hours h ago';
  }

  @override
  String chatLastSeenDays(int days) {
    return 'last seen $days d ago';
  }

  @override
  String get chatSeen => 'Seen';

  @override
  String get chatSent => 'Sent';

  @override
  String get chatReply => 'Reply';

  @override
  String get chatCopyMessage => 'Copy message';

  @override
  String get chatMessageCopied => 'Message copied';

  @override
  String get chatReplyToYou => 'You';

  @override
  String get chatReplyToThem => 'Quoted message';

  @override
  String get chatAttachPhoto => 'Send a photo';

  @override
  String get chatPhotoSendError => 'We could not send the photo.';

  @override
  String get chatSearchInConversation => 'Search in conversation';

  @override
  String get chatSearchNoResults => 'No messages found.';

  @override
  String get chatArchive => 'Archive';

  @override
  String get chatUnarchive => 'Unarchive';

  @override
  String get chatArchived => 'Conversation archived';

  @override
  String get chatArchivedTitle => 'Archived';

  @override
  String get chatEmptyArchived => 'You have no archived conversations.';

  @override
  String get chatDeleteTitle => 'Delete chat';

  @override
  String get chatDeleteConfirm =>
      'The conversation disappears only for you. The other person keeps their messages.';

  @override
  String get chatActionError => 'We could not do that. Please try again.';

  @override
  String get chatReportConversation => 'Report conversation';

  @override
  String get chatConversationReported =>
      'The conversation was reported. Our team will review it.';

  @override
  String get chatBlockedNotice =>
      'You can\'t send messages to this user - the conversation is blocked.';

  @override
  String get chatShareLocationTooltip => 'Send meeting location';

  @override
  String get chatMessageHint => 'Write a message...';

  @override
  String get chatSafetyBannerBody =>
      'Don\'t send money in advance and meet in a public place for the exchange. If something looks suspicious, report or block the user from the menu above.';

  @override
  String get chatSafetyBannerLearnMore => 'Learn more';

  @override
  String get chatEmptyMessages => 'No messages yet. Say hi!';

  @override
  String get chatMapLabel => 'Map';

  @override
  String get chatCalendarLabel => 'Calendar';

  @override
  String chatMeetingAt(String date, String time) {
    return '$date, at $time';
  }

  @override
  String get chatSafetyAdvisorLabel => 'Safety advisor';

  @override
  String get chatSafetyAdvisorBody =>
      'Make sure you follow the safety guidelines for this meeting.';

  @override
  String get chatOfferActionError => 'Couldn\'t update the offer. Try again.';

  @override
  String chatOfferCardLabel(String amount, String bookTitle) {
    return '$amount lei · $bookTitle';
  }

  @override
  String get chatSearchPlaceHint =>
      'Search for an address or place (e.g. Cafe X, Cluj)';

  @override
  String get chatNoResults => 'No results.';

  @override
  String get chatSuggestedMeetingPoints => 'Suggested meeting points nearby';

  @override
  String get chatPickDate => 'Pick a date';

  @override
  String get chatPickTime => 'Pick a time';

  @override
  String get wishlistTitle => 'Wishlist';

  @override
  String get wishlistEmpty =>
      'You haven\'t added any books to your wishlist yet.';

  @override
  String get wishlistLoadError => 'We couldn\'t load your wishlist.';

  @override
  String get notificationsTitle => 'Notifications';

  @override
  String get notificationsMarkAllRead => 'Mark all as read';

  @override
  String get notificationsEmpty => 'You don\'t have any notifications.';

  @override
  String get notificationsLoadError => 'We couldn\'t load your notifications.';

  @override
  String get timeJustNow => 'just now';

  @override
  String timeMinutesAgo(int minutes) {
    return '$minutes min ago';
  }

  @override
  String timeHoursAgo(int hours) {
    return '${hours}h ago';
  }

  @override
  String timeDaysAgo(int days) {
    return '${days}d ago';
  }

  @override
  String get safetyCenterTitle => 'Safety center';

  @override
  String get safetyCenterIntro =>
      'A few simple rules to keep exchanges on ShelfShare pleasant and safe.';

  @override
  String get safetyTip1Title => 'Meet during the day';

  @override
  String get safetyTip1Desc =>
      'Schedule the exchange for a time with natural daylight, ideally morning or afternoon.';

  @override
  String get safetyTip2Title => 'Choose a public place';

  @override
  String get safetyTip2Desc =>
      'A café, bookstore, or mall is safer than someone\'s personal address.';

  @override
  String get safetyTip3Title => 'Prefer locations with video surveillance';

  @override
  String get safetyTip3Desc =>
      'Areas with security cameras discourage unpleasant behavior.';

  @override
  String get safetyTip4Title => 'Don\'t share personal data';

  @override
  String get safetyTip4Desc =>
      'You don\'t need to give your home address, ID number, or other sensitive data to make an exchange.';

  @override
  String get safetyTip5Title => 'Check the rating and trust score';

  @override
  String get safetyTip5Desc =>
      'A good history of completed exchanges is a good sign before meeting someone.';

  @override
  String get safetyTip6Title => 'A real profile photo builds trust';

  @override
  String get safetyTip6Desc =>
      'Profiles with a photo and a complete bio inspire more confidence in other users.';

  @override
  String get safetyTip7Title =>
      'Check the book\'s condition before the exchange';

  @override
  String get safetyTip7Desc =>
      'Compare the book to the listing\'s description before confirming the exchange as completed.';

  @override
  String get safetyTip8Title => 'Report any suspicious behavior';

  @override
  String get safetyTip8Desc =>
      'You can report or block a user directly from their profile or from the conversation.';

  @override
  String get helpCenterTitle => 'FAQ';

  @override
  String get helpFaq1Question => 'How does a book exchange work?';

  @override
  String get helpFaq1Answer =>
      'You request a book from someone else\'s listing (you can also offer a book in exchange), the owner accepts or declines, then you arrange a meeting via chat. After you complete the exchange in person, either of you marks the exchange as completed.';

  @override
  String get helpFaq2Question => 'What is the Trust Score?';

  @override
  String get helpFaq2Answer =>
      'A 0-100 indicator calculated automatically from in-app activity: account age, verified email, how many exchanges you\'ve completed, your rating, how often you respond, and how rarely you cancel requests. It\'s not an identity check, just a behavior signal.';

  @override
  String get helpFaq3Question => 'How is the \"bookstore\" price calculated?';

  @override
  String get helpFaq3Answer =>
      'When you add a book with an ISBN, we try to find the list price on Google Books. Coverage is partial - not all books have a price available there, especially older or Romanian editions.';

  @override
  String get helpFaq4Question =>
      'What does \"Fixed price, non-negotiable\" mean?';

  @override
  String get helpFaq4Answer =>
      'If the seller checks this, buyers can no longer send price offers - the book can only be bought at the listed price.';

  @override
  String get helpFaq5Question => 'How do I report or block a user?';

  @override
  String get helpFaq5Answer =>
      'From the menu in the top-right corner of a conversation, or from a listing\'s detail page (the flag icon). Blocking stops messages in both directions.';

  @override
  String get helpFaq6Question =>
      'What happens to the book after I sell it or give it in exchange?';

  @override
  String get helpFaq6Answer =>
      'The listing becomes permanently unavailable. If the person who received it wants to list it again, they can do so from the Exchanges/Offers screen (\"Add to your library\") - the book\'s history stays traceable on its detail page, with photos from each owner.';

  @override
  String get helpFaq7Question =>
      'Why doesn\'t a book show up in Categories or Similar Books?';

  @override
  String get helpFaq7Answer =>
      'A book\'s genre comes from Open Library or Google Books when it\'s added - some books don\'t have a genre filled in on those external sources, especially less popular editions.';

  @override
  String get helpCenterFooter =>
      'Didn\'t find your answer? You can report an issue directly from the conversation with the user involved.';

  @override
  String get adminLoadError => 'We couldn\'t load the admin data.';

  @override
  String get adminStatsTitle => 'Statistics';

  @override
  String get adminMarketplaceStatsTitle => 'Marketplace statistics';

  @override
  String get adminMarketplaceGmv => 'Total transacted volume';

  @override
  String get adminMarketplaceCompletedSales => 'Completed sales';

  @override
  String get adminMarketplaceCompletedAuctions => 'Completed auctions';

  @override
  String get adminMarketplaceAvgPrice => 'Average sale price';

  @override
  String get adminMarketplaceTopGenres => 'Top genres (active listings)';

  @override
  String get adminActiveZonesTitle => 'Active zones';

  @override
  String get adminActiveZonesDesc => 'Density of active listings by city';

  @override
  String get adminActiveZonesEmpty => 'No active listings yet.';

  @override
  String adminUsersCount(int count) {
    return 'Users ($count)';
  }

  @override
  String adminInactiveListingsCount(int count) {
    return 'Listings with no requests ($count)';
  }

  @override
  String get adminInactiveListingsDesc =>
      'Books listed for exchange that no one has requested.';

  @override
  String get adminNoInactiveListings => 'No inactive listings.';

  @override
  String adminUserReportsCount(int count) {
    return 'User reports ($count)';
  }

  @override
  String get adminNoReports => 'No reports.';

  @override
  String adminUpcomingReleasesCount(int count) {
    return 'Upcoming books ($count)';
  }

  @override
  String get adminUpcomingReleasesDesc =>
      'Shown on the home screen, in the \"Upcoming books\" section.';

  @override
  String get adminNoUpcomingReleases => 'No upcoming books added.';

  @override
  String adminFeedbackCount(int count) {
    return 'Feedback received ($count)';
  }

  @override
  String get adminNoFeedback => 'No feedback submitted yet.';

  @override
  String adminSupportRequestsCount(int count) {
    return 'Support messages ($count)';
  }

  @override
  String get adminNoSupportRequests => 'No support messages submitted yet.';

  @override
  String adminReportedBy(String name) {
    return 'Reported by $name';
  }

  @override
  String get adminUnknownAuthor => 'Unknown author';

  @override
  String get adminAuthorOptional => 'Author (optional)';

  @override
  String get adminCoverUrlOptional => 'Cover URL (optional)';

  @override
  String get adminPickReleaseDate => 'Pick release date';

  @override
  String adminReleaseDateLabel(String date) {
    return 'Release: $date';
  }

  @override
  String get adminAdd => 'Add';

  @override
  String get adminTitleDateRequired => 'Title and release date are required';

  @override
  String get adminAddBookError => 'We couldn\'t add the book';

  @override
  String get adminDeleteUserTitle => 'Delete this user?';

  @override
  String adminDeleteUserBody(String name) {
    return 'This permanently deletes $name\'s account and all associated data (books, exchanges, messages). This cannot be undone.';
  }

  @override
  String get adminStatsUsersLabel => 'Users';

  @override
  String adminStatsUsersSubtitle(int count) {
    return 'of which $count verified';
  }

  @override
  String get adminStatsBooksLabel => 'Books in catalog';

  @override
  String adminStatsBooksSubtitle(int count) {
    return '$count copies listed';
  }

  @override
  String get adminStatsExchangesLabel => 'Exchanges';

  @override
  String adminStatsExchangesSubtitle(int completed, int pending) {
    return '$completed completed · $pending pending';
  }

  @override
  String get auctionTitle => 'Auction';

  @override
  String get auctionCurrentPrice => 'Current price';

  @override
  String get auctionBidsCount => 'bids';

  @override
  String get auctionReserveMet => 'Reserve price has been met';

  @override
  String get auctionReserveNotMet => 'Reserve price has not been met yet';

  @override
  String get auctionEndedWithWinner => 'The auction has ended - someone won';

  @override
  String get auctionEndedNoWinner => 'The auction ended without a winner';

  @override
  String auctionBidAmountLabel(String amount) {
    return 'Bid (minimum $amount lei)';
  }

  @override
  String get auctionPlaceBid => 'Place bid';

  @override
  String auctionBuyNowFor(String amount) {
    return 'Buy now for $amount lei';
  }

  @override
  String get auctionBidHistory => 'Bid history';

  @override
  String get auctionNoBidsYet => 'No bids yet';

  @override
  String get auctionWatch => 'Watch auction';

  @override
  String get auctionBidPlaced => 'Bid placed';

  @override
  String get auctionBoughtNow => 'Bought successfully';

  @override
  String get auctionGenericError => 'Something went wrong, try again';

  @override
  String get auctionEnded => 'Ended';

  @override
  String auctionEndsInDays(int days) {
    return 'ends in $days days';
  }

  @override
  String auctionEndsInHours(int hours) {
    return 'ends in $hours h';
  }

  @override
  String auctionEndsInMinutes(int minutes) {
    return 'ends in $minutes min';
  }

  @override
  String get bulkAddTitle => 'Add multiple books';

  @override
  String get bulkAddScanTooltip => 'Scan barcode';

  @override
  String get bulkAddManualEntry => 'Manual entry';

  @override
  String get bulkAddManualHint =>
      'Paste multiple ISBNs, one per line (or comma-separated)';

  @override
  String get bulkAddManualPlaceholder => '9780439023481\n9780441172719';

  @override
  String get bulkAddAddIsbns => 'Add to list';

  @override
  String get bulkAddQueueEmpty => 'No books added yet - scan or enter an ISBN.';

  @override
  String bulkAddSubmit(int count) {
    return 'Add $count books';
  }

  @override
  String bulkAddResultSummary(int created, int failed) {
    return '$created books added, $failed failed';
  }

  @override
  String inventorySelectedCount(int count) {
    return '$count selected';
  }

  @override
  String get inventoryMarkUnavailable => 'Mark unavailable';

  @override
  String get inventoryChangePriceTitle => 'Change price';

  @override
  String inventoryPriceChangedCount(int count) {
    return 'Price changed on $count listings';
  }

  @override
  String get inventoryDeleteConfirmTitle => 'Delete the selected listings?';

  @override
  String inventoryDeleteConfirmBody(int count) {
    return 'This permanently deletes $count listings. This cannot be undone.';
  }

  @override
  String get inventoryBulkDone => 'Action applied';

  @override
  String get collectionsTitle => 'Collections';

  @override
  String get collectionsEmpty => 'No collections yet.';

  @override
  String get collectionsLoadError => 'Couldn\'t load collections.';

  @override
  String get collectionsCreateTitle => 'New collection';

  @override
  String get collectionsNameLabel => 'Name';

  @override
  String get collectionsPublicSwitch => 'Public';

  @override
  String collectionsBookCount(int count) {
    return '$count books';
  }

  @override
  String get collectionsEmptyItems => 'No books in this collection yet.';

  @override
  String get collectionsDeleteConfirmTitle => 'Delete this collection?';

  @override
  String get collectionsAddToTitle => 'Add to collection';

  @override
  String get collectionsNewInline => 'New collection...';

  @override
  String get groupsTitle => 'Groups';

  @override
  String get groupsTabDiscover => 'Discover';

  @override
  String get groupsTabMine => 'Mine';

  @override
  String get groupsEmpty => 'No groups yet.';

  @override
  String get groupsLoadError => 'Couldn\'t load the group.';

  @override
  String get groupsCreateTitle => 'New group';

  @override
  String get groupsNameLabel => 'Name';

  @override
  String get groupsDescriptionLabel => 'Description (optional)';

  @override
  String groupsMemberCount(int count) {
    return '$count members';
  }

  @override
  String get groupsJoin => 'Join';

  @override
  String get groupsLeave => 'Leave group';

  @override
  String get groupsDeleteConfirmTitle => 'Delete this group?';

  @override
  String get groupsEventsTitle => 'Events';

  @override
  String get groupsNoEvents => 'No events scheduled.';

  @override
  String get groupsAddEventTitle => 'Add event';

  @override
  String get groupsEventTitleLabel => 'Title';

  @override
  String get groupsEventLocationLabel => 'Location (optional)';

  @override
  String get groupsDiscussionTitle => 'Discussion';

  @override
  String get groupsPostHint => 'Write a message...';

  @override
  String get groupsNoPosts => 'No messages yet.';

  @override
  String get premiumBadgeTooltip => 'Premium member';

  @override
  String get adminGrantPremium => 'Grant Premium';

  @override
  String get adminRemovePremium => 'Remove Premium';

  @override
  String get premiumPromoteListing => 'Promote listing';

  @override
  String get premiumUnpromoteListing => 'Unpromote';

  @override
  String get premiumAnalyticsTitle => 'Advanced analytics';

  @override
  String get premiumAnalyticsTotalListings => 'Active listings';

  @override
  String get premiumAnalyticsTotalViews => 'Total views';

  @override
  String get premiumAnalyticsOffersReceived => 'Offers received';

  @override
  String get premiumAnalyticsConversionRate => 'Conversion rate';

  @override
  String get premiumAnalyticsRevenue => 'Total revenue';

  @override
  String get premiumAnalyticsTopListings => 'Most viewed listings';

  @override
  String get premiumAnalyticsLocked =>
      'Advanced analytics is a Premium feature.';

  @override
  String get premiumAnalyticsLoadError => 'Couldn\'t load the stats.';

  @override
  String get discoverMostWishedFor => 'Most wished for';

  @override
  String get discoverMostLookedFor => 'Most looked for';

  @override
  String get discoverSearchTooltip => 'Search books';

  @override
  String get discoverTopSearches => 'Top searches';

  @override
  String get discoverAuctions => 'Active auctions';

  @override
  String get discoverHiddenGems => 'Hidden gems';

  @override
  String get discoverSwapOnly => 'Swap only';

  @override
  String get discoverUnder30 => 'Under 30 lei';

  @override
  String get discoverRecommendedForYou => 'Recommended for you';

  @override
  String get discoverPopularAuthors => 'Popular authors';

  @override
  String get discoverQuickFilters => 'Quick filters';

  @override
  String get discoverNearYou => 'In your city';

  @override
  String get inventorySelectAll => 'Select all';

  @override
  String get myShelfShare => 'Share';

  @override
  String get inventoryMarkAvailable => 'Mark available';

  @override
  String get libraryTrashEmpty => 'Trash is empty';

  @override
  String get inventoryAppendText => 'Append to end';

  @override
  String get inventoryTransferred => 'Transferred';

  @override
  String inventoryDeletedDaysLeft(int days) {
    return 'Deletes in $days days';
  }

  @override
  String get libraryEmptiedShelves => 'Given or exchanged books';

  @override
  String get libraryRestored => 'Book restored';

  @override
  String get inventoryDescriptionDone => 'Descriptions updated';

  @override
  String get libraryTrashHint =>
      'Deleted books stay here for 7 days, then are permanently removed';

  @override
  String get inventoryBulkEditDescription => 'Bulk edit descriptions';

  @override
  String get libraryTrash => 'Trash';

  @override
  String get inventoryRemoveText => 'Remove from text';

  @override
  String get libraryRestore => 'Restore';

  @override
  String get libraryEmptiedShelvesEmpty => 'No transferred books yet';

  @override
  String get shareMaxTagsReached => 'You can add up to 5 tags';

  @override
  String get shareTitleHint => 'Book title';

  @override
  String get shareTagsHint => 'Tags (max 5)';

  @override
  String get shareEditionYear => 'Edition year';

  @override
  String get shareDescriptionHint => 'Description (max 256 characters)';

  @override
  String get shareMoreInfo => 'More information';

  @override
  String get shareAuthorHint => 'Author';

  @override
  String get sharePageCountCustom => 'Page count (overrides autofill)';

  @override
  String get shareTagAdd => 'Add tag';

  @override
  String get sharePublisher => 'Publisher';

  @override
  String get shareCityHint => 'City where the exchange happens';

  @override
  String get sharePublishedYear => 'Published year';

  @override
  String get shareSubmit => 'Publish';

  @override
  String get shareListingModeAuction => 'Auction';

  @override
  String get shareListingMode => 'Listing mode';

  @override
  String shareDescriptionCharsLeft(int n) {
    return '$n characters left';
  }

  @override
  String get shareListingModeSwap => 'Normal swap';

  @override
  String get shareListingModeSale => 'For sale';

  @override
  String get shareListingModeDonation => 'Donation';

  @override
  String get shareTitleAutocomplete => 'Start typing to see suggestions';

  @override
  String get shareGenreHint => 'Genre';

  @override
  String get shareAddPhotos => 'Add photos';

  @override
  String get preRegisterAlreadyLoggedIn =>
      'We\'ll use your account email if you leave this blank';

  @override
  String get preRegisterAndroidHeadline => 'Coming soon to your phone';

  @override
  String get preRegisterSuccess =>
      'You\'re on the list. We\'ll let you know when it\'s ready.';

  @override
  String get profilePreRegister => 'Pre-register for Android';

  @override
  String get preRegisterAndroidBody =>
      'Leave your email and we\'ll notify you the day the app is live on Google Play.';

  @override
  String get preRegisterSubmit => 'Add me to the list';

  @override
  String get preRegisterAndroidTitle => 'Pre-register for Android';

  @override
  String get preRegisterEmailHint => 'Email for the launch notice';

  @override
  String get preRegisterError =>
      'Could not register your email. Please try again.';

  @override
  String get profileSettingsSubtitle => 'All your account options in one place';

  @override
  String get profileRecentActivity => 'Recent activity';

  @override
  String get profileStatSwaps => 'swaps';

  @override
  String get profileActivityAdded => 'Added';

  @override
  String get profileMoreInSettings => 'More options in „⚙\" above';

  @override
  String profileLibraryAvailable(int n) {
    return '$n available';
  }

  @override
  String get profileStatRating => 'rating';

  @override
  String get profileStatBooks => 'books';

  @override
  String get profileSettings => 'Settings';

  @override
  String get profileKeepAlive => 'Keep the app alive';

  @override
  String get profileKeepAliveSubtitle =>
      'ShelfShare runs on a home server. A coffee helps.';

  @override
  String get aboutDevTitle => 'About dev';

  @override
  String get aboutDevHeadline => 'The person behind ShelfShare';

  @override
  String get aboutDevBodyWho =>
      'I\'m a small developer working at an IT company in Transylvania.';

  @override
  String get aboutDevBodyWhy =>
      'I made this app because I used to use an app just like this before, but it disappeared because… reasons? So I made one myself.';

  @override
  String get aboutDevBodyHosting =>
      'Please don\'t get upset about the possible hickups of the app, because everything is hosted by myself on my small home server ☹️';

  @override
  String get aboutDevSupportTitle => 'Keep the app alive';

  @override
  String get aboutDevSupportSubtitle =>
      'The server, the domain and the backups come out of my own pocket. Anything you chip in keeps the app running.';

  @override
  String get aboutDevCoffeeButton => 'Buy me a coffee';

  @override
  String get aboutDevOpenError => 'Couldn\'t open the link. Please try again.';

  @override
  String get loginMadeWithLove => 'Made with ❤️ in Transilvanya';

  @override
  String homeNearbyTitle(int km) {
    return 'Books around you ($km km)';
  }

  @override
  String get shareTagsSuggestions => 'Suggestions:';

  @override
  String get shareCityUnknown => 'Pick a city from the list';

  @override
  String get gamificationHowItWorks => 'How XP works';

  @override
  String gamificationXpIntro(int n) {
    return 'Every $n XP is a new level. XP is awarded automatically for things you do in the app:';
  }

  @override
  String get gamificationXpBookListed => 'List a book';

  @override
  String get gamificationXpExchangeCompleted => 'Complete a swap';

  @override
  String get gamificationXpSaleCompleted => 'Complete a sale';

  @override
  String get gamificationXpReviewWritten => 'Write a review';

  @override
  String get gamificationNoMaxLevel =>
      'There is no max level - the curve is linear, so you can keep climbing.';

  @override
  String get profileBirthdayDay => 'Day';

  @override
  String get profileBirthdayMonth => 'Birth month';

  @override
  String get profileBirthdayNone => '—';

  @override
  String get greetReaderFallback => 'Reader';

  @override
  String get greetMorningSun => 'Good morning, sunshine! ☀️';

  @override
  String greetMorningNamed(String name) {
    return 'Good morning, $name!';
  }

  @override
  String get greetMorningCoffeeBook => 'A coffee and a book?';

  @override
  String get greetMorningCoffee => 'Good morning, coffee time! ☕';

  @override
  String get greetMorningStartStory => 'Start the day with a story.';

  @override
  String get greetMorningAdventure => 'A new adventure is rising.';

  @override
  String get greetMorningSleptWell => 'Hope you slept well!';

  @override
  String get greetMorningPerfectBook =>
      'Today you might find the perfect book.';

  @override
  String get greetMorningNicer => 'Mornings are nicer with a book.';

  @override
  String greetDayNamed(String name) {
    return 'Hi, $name!';
  }

  @override
  String get greetDayDiscover => 'What book will you discover today?';

  @override
  String get greetDayAdventure => 'A new adventure awaits.';

  @override
  String get greetDayLibrary => 'The library is waiting.';

  @override
  String get greetDayCorporateCoffee => 'Time for the office coffee?';

  @override
  String get greetDayWhatsNext => 'What\'s next on your list?';

  @override
  String get greetDaySwappedToday => 'Swapped a book today?';

  @override
  String get greetDayNewReader => 'Every book has a new reader.';

  @override
  String get greetDayFindNext => 'Find your next read.';

  @override
  String get greetEveningHello => 'Good evening!';

  @override
  String get greetEveningHowWasDay => 'How was your day?';

  @override
  String get greetEveningPerfectNow => 'A book would be perfect right now.';

  @override
  String get greetEveningFewPages => 'Time for a few pages.';

  @override
  String get greetEveningRelax => 'Unwind with a story.';

  @override
  String get greetEveningQuiet => 'A quiet evening starts with a book.';

  @override
  String get greetEveningWhatTonight => 'What are you reading tonight?';

  @override
  String get greetEveningBeforeBed => 'Maybe find something new before bed.';

  @override
  String get greetNightGoodNight => 'Good night! 🌙';

  @override
  String get greetNightSandman => 'The sandman is on his way. 😴';

  @override
  String get greetNightCloseBook => 'Time to close the book.';

  @override
  String greetNightSleepWell(String name) {
    return 'Sleep well, $name!';
  }

  @override
  String get greetNightOneMoreChapter => 'One more chapter?';

  @override
  String get greetNightSeeYouTomorrow => 'See you tomorrow among the books.';

  @override
  String get greetNightNiceDay => 'Hope you had a lovely day.';

  @override
  String get greetNightQuiet => 'Have a peaceful night!';

  @override
  String get greetLateAwake => 'Still awake? 📖';

  @override
  String get greetLateNightOwl => 'Night owl?';

  @override
  String get greetLateMidnightReads => 'Midnight reads hit differently.';

  @override
  String get greetLateOneChapter => 'It\'s just one more chapter, right?';

  @override
  String get greetLateNeverSleeps => 'ShelfShare never sleeps.';

  @override
  String get greetLateCompany => 'Books keep you company at late hours too.';

  @override
  String get greetLateLastChapter =>
      'Good night... once you reach the last chapter.';

  @override
  String get greetLateForgotSleep => 'We hope you did not forget to sleep.';

  @override
  String get greetWeekend =>
      'It\'s the weekend! Which book are you taking along?';

  @override
  String get greetMonday => 'Monday... at least you have a good book.';

  @override
  String get greetFridayEvening => 'Friday evening? Perfect for reading.';

  @override
  String get greetBirthday => 'Happy birthday! 🎉';

  @override
  String get greetNationalDay => 'Happy National Day, Romania! 🇷🇴';

  @override
  String get greetChristmas => 'Merry Christmas! 🎄';

  @override
  String get greetEaster => 'Happy Easter! 🐰';

  @override
  String get greetNewYear => 'New year, new books! 🎆';

  @override
  String get greetBookDay => 'Today is World Book Day! 📚';
}
