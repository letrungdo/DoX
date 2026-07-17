import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_vi.dart';

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
    Locale('en'),
    Locale('vi'),
  ];

  /// No description provided for @ok.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get ok;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @logout.
  ///
  /// In en, this message translates to:
  /// **'Logout'**
  String get logout;

  /// No description provided for @login.
  ///
  /// In en, this message translates to:
  /// **'Login'**
  String get login;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @error.
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get error;

  /// No description provided for @crop.
  ///
  /// In en, this message translates to:
  /// **'Crop'**
  String get crop;

  /// No description provided for @addMessage.
  ///
  /// In en, this message translates to:
  /// **'Add a message'**
  String get addMessage;

  /// No description provided for @writeReview.
  ///
  /// In en, this message translates to:
  /// **'Write a review...'**
  String get writeReview;

  /// No description provided for @pleaseLoginAgain.
  ///
  /// In en, this message translates to:
  /// **'Please log in again!'**
  String get pleaseLoginAgain;

  /// No description provided for @sessionExpired.
  ///
  /// In en, this message translates to:
  /// **'Session expired'**
  String get sessionExpired;

  /// No description provided for @anErrorOccurred.
  ///
  /// In en, this message translates to:
  /// **'An error occurred.'**
  String get anErrorOccurred;

  /// No description provided for @meSystemMaintenance.
  ///
  /// In en, this message translates to:
  /// **'System maintenance!'**
  String get meSystemMaintenance;

  /// No description provided for @meRequestTimeout.
  ///
  /// In en, this message translates to:
  /// **'Request timeout!'**
  String get meRequestTimeout;

  /// No description provided for @meNetworkError.
  ///
  /// In en, this message translates to:
  /// **'Lost connect internet'**
  String get meNetworkError;

  /// No description provided for @videoTooLargeTitle.
  ///
  /// In en, this message translates to:
  /// **'Video too large'**
  String get videoTooLargeTitle;

  /// No description provided for @videoTooLargeMessage.
  ///
  /// In en, this message translates to:
  /// **'The compressed video is still {size}MB, over Locket\'s 6MB limit.\n\nReduce quality to 480p, or go back and shorten the video?'**
  String videoTooLargeMessage(String size);

  /// No description provided for @shortenVideo.
  ///
  /// In en, this message translates to:
  /// **'Shorten it'**
  String get shortenVideo;

  /// No description provided for @reduceTo480p.
  ///
  /// In en, this message translates to:
  /// **'Reduce to 480p'**
  String get reduceTo480p;

  /// No description provided for @videoStillTooLargeAt480p.
  ///
  /// In en, this message translates to:
  /// **'Still over 6MB at 480p — please shorten the video :('**
  String get videoStillTooLargeAt480p;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @showLocketTab.
  ///
  /// In en, this message translates to:
  /// **'Show Locket Tab'**
  String get showLocketTab;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @vietnamese.
  ///
  /// In en, this message translates to:
  /// **'Vietnamese'**
  String get vietnamese;

  /// No description provided for @english.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get english;

  /// No description provided for @menu.
  ///
  /// In en, this message translates to:
  /// **'Menu'**
  String get menu;

  /// No description provided for @news.
  ///
  /// In en, this message translates to:
  /// **'News'**
  String get news;

  /// No description provided for @chicken.
  ///
  /// In en, this message translates to:
  /// **'Chicken'**
  String get chicken;

  /// No description provided for @locket.
  ///
  /// In en, this message translates to:
  /// **'Locket'**
  String get locket;

  /// No description provided for @rebootRouter.
  ///
  /// In en, this message translates to:
  /// **'Wifi Management'**
  String get rebootRouter;

  /// No description provided for @about.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get about;

  /// No description provided for @loginDoX.
  ///
  /// In en, this message translates to:
  /// **'Login Do X'**
  String get loginDoX;

  /// No description provided for @logoutDoX.
  ///
  /// In en, this message translates to:
  /// **'Logout Do X'**
  String get logoutDoX;

  /// No description provided for @vaccinationNotifications.
  ///
  /// In en, this message translates to:
  /// **'Vaccination schedule notifications'**
  String get vaccinationNotifications;

  /// No description provided for @notificationPermissionDenied.
  ///
  /// In en, this message translates to:
  /// **'Unable to update the notification schedule. Please check notification permission in the device settings.'**
  String get notificationPermissionDenied;

  /// No description provided for @vaccinationNotificationTitle.
  ///
  /// In en, this message translates to:
  /// **'Vaccination: {vaccination}'**
  String vaccinationNotificationTitle(String vaccination);

  /// No description provided for @vaccinationNotificationBody.
  ///
  /// In en, this message translates to:
  /// **'Batch {batch} is due for vaccination today.'**
  String vaccinationNotificationBody(String batch);

  /// No description provided for @confirmLogout.
  ///
  /// In en, this message translates to:
  /// **'Confirm Logout'**
  String get confirmLogout;

  /// No description provided for @confirmLogoutMessage.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to log out?'**
  String get confirmLogoutMessage;

  /// No description provided for @themeMode.
  ///
  /// In en, this message translates to:
  /// **'Theme Mode'**
  String get themeMode;

  /// No description provided for @light.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get light;

  /// No description provided for @dark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get dark;

  /// No description provided for @system.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get system;

  /// No description provided for @wifiManagement.
  ///
  /// In en, this message translates to:
  /// **'Wifi Management'**
  String get wifiManagement;

  /// No description provided for @lanSpeed.
  ///
  /// In en, this message translates to:
  /// **'LAN Speed'**
  String get lanSpeed;

  /// No description provided for @internetSpeed.
  ///
  /// In en, this message translates to:
  /// **'Internet Speed'**
  String get internetSpeed;

  /// No description provided for @routerIpAddress.
  ///
  /// In en, this message translates to:
  /// **'Router IP Address'**
  String get routerIpAddress;

  /// No description provided for @adminPassword.
  ///
  /// In en, this message translates to:
  /// **'Admin Password'**
  String get adminPassword;

  /// No description provided for @rebootRouterXiaomi.
  ///
  /// In en, this message translates to:
  /// **'Reboot Router Xiaomi'**
  String get rebootRouterXiaomi;

  /// No description provided for @startSpeedTest.
  ///
  /// In en, this message translates to:
  /// **'Start Speed Test'**
  String get startSpeedTest;

  /// No description provided for @testing.
  ///
  /// In en, this message translates to:
  /// **'Testing...'**
  String get testing;

  /// No description provided for @speedMbps.
  ///
  /// In en, this message translates to:
  /// **'{speed} Mbps'**
  String speedMbps(String speed);

  /// No description provided for @goldPrice.
  ///
  /// In en, this message translates to:
  /// **'Gold Price'**
  String get goldPrice;

  /// No description provided for @index.
  ///
  /// In en, this message translates to:
  /// **'Index'**
  String get index;

  /// No description provided for @buy.
  ///
  /// In en, this message translates to:
  /// **'Buy'**
  String get buy;

  /// No description provided for @sell.
  ///
  /// In en, this message translates to:
  /// **'Sell'**
  String get sell;

  /// No description provided for @chickenManagement.
  ///
  /// In en, this message translates to:
  /// **'Chicken Management'**
  String get chickenManagement;

  /// No description provided for @sellRoosterMeat.
  ///
  /// In en, this message translates to:
  /// **'Sell rooster / meat'**
  String get sellRoosterMeat;

  /// No description provided for @profitStatistics.
  ///
  /// In en, this message translates to:
  /// **'Profit statistics'**
  String get profitStatistics;

  /// No description provided for @commonExpenses.
  ///
  /// In en, this message translates to:
  /// **'Common expenses'**
  String get commonExpenses;

  /// No description provided for @importData.
  ///
  /// In en, this message translates to:
  /// **'Import data (JSON)'**
  String get importData;

  /// No description provided for @noBatchesYet.
  ///
  /// In en, this message translates to:
  /// **'No batches yet. Press + to add.'**
  String get noBatchesYet;

  /// No description provided for @yearPrefix.
  ///
  /// In en, this message translates to:
  /// **'Year'**
  String get yearPrefix;

  /// No description provided for @yearLabel.
  ///
  /// In en, this message translates to:
  /// **'Year:'**
  String get yearLabel;

  /// No description provided for @all.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get all;

  /// No description provided for @expenseCount.
  ///
  /// In en, this message translates to:
  /// **'{count} expenses'**
  String expenseCount(int count);

  /// No description provided for @saleCount.
  ///
  /// In en, this message translates to:
  /// **'{count} sales'**
  String saleCount(int count);

  /// No description provided for @revenueAmount.
  ///
  /// In en, this message translates to:
  /// **'Revenue: {amount}'**
  String revenueAmount(String amount);

  /// No description provided for @profitAmount.
  ///
  /// In en, this message translates to:
  /// **'Profit: {amount}'**
  String profitAmount(String amount);

  /// No description provided for @totalAmount.
  ///
  /// In en, this message translates to:
  /// **'Total: {amount}'**
  String totalAmount(String amount);

  /// No description provided for @noBatchesInYear.
  ///
  /// In en, this message translates to:
  /// **'No chicken batches in {year}.'**
  String noBatchesInYear(int year);

  /// No description provided for @noCommonExpenses.
  ///
  /// In en, this message translates to:
  /// **'No common expenses yet.'**
  String get noCommonExpenses;

  /// No description provided for @noCommonExpensesInYear.
  ///
  /// In en, this message translates to:
  /// **'No common expenses in {year}.'**
  String noCommonExpensesInYear(int year);

  /// No description provided for @addFirstExpense.
  ///
  /// In en, this message translates to:
  /// **'Add the first expense'**
  String get addFirstExpense;

  /// No description provided for @addCommonExpense.
  ///
  /// In en, this message translates to:
  /// **'Add common expense'**
  String get addCommonExpense;

  /// No description provided for @editCommonExpense.
  ///
  /// In en, this message translates to:
  /// **'Edit common expense'**
  String get editCommonExpense;

  /// No description provided for @update.
  ///
  /// In en, this message translates to:
  /// **'Update'**
  String get update;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @expenseType.
  ///
  /// In en, this message translates to:
  /// **'Expense type'**
  String get expenseType;

  /// No description provided for @amountLabel.
  ///
  /// In en, this message translates to:
  /// **'Amount'**
  String get amountLabel;

  /// No description provided for @noteLabel.
  ///
  /// In en, this message translates to:
  /// **'Note'**
  String get noteLabel;

  /// No description provided for @expenseDate.
  ///
  /// In en, this message translates to:
  /// **'Expense date'**
  String get expenseDate;

  /// No description provided for @saveCommonExpenseFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not save expense: {error}'**
  String saveCommonExpenseFailed(String error);

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @deleteCommonExpense.
  ///
  /// In en, this message translates to:
  /// **'Delete expense'**
  String get deleteCommonExpense;

  /// No description provided for @confirmDeleteCommonExpense.
  ///
  /// In en, this message translates to:
  /// **'Delete the expense dated {date} ({amount})?'**
  String confirmDeleteCommonExpense(String date, String amount);

  /// No description provided for @deleteCommonExpenseFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not delete expense: {error}'**
  String deleteCommonExpenseFailed(String error);

  /// No description provided for @expenseFeed.
  ///
  /// In en, this message translates to:
  /// **'Feed'**
  String get expenseFeed;

  /// No description provided for @expenseMedicine.
  ///
  /// In en, this message translates to:
  /// **'Medicine / vaccine'**
  String get expenseMedicine;

  /// No description provided for @expenseElectricity.
  ///
  /// In en, this message translates to:
  /// **'Heating electricity'**
  String get expenseElectricity;

  /// No description provided for @expenseWater.
  ///
  /// In en, this message translates to:
  /// **'Water'**
  String get expenseWater;

  /// No description provided for @expenseOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get expenseOther;

  /// No description provided for @newUpdateAvailable.
  ///
  /// In en, this message translates to:
  /// **'New update available v{version}'**
  String newUpdateAvailable(String version);

  /// No description provided for @later.
  ///
  /// In en, this message translates to:
  /// **'Later'**
  String get later;

  /// No description provided for @appUpdate.
  ///
  /// In en, this message translates to:
  /// **'App Update'**
  String get appUpdate;

  /// No description provided for @downloadingUpdate.
  ///
  /// In en, this message translates to:
  /// **'Downloading update...'**
  String get downloadingUpdate;

  /// No description provided for @downloadComplete.
  ///
  /// In en, this message translates to:
  /// **'Download complete, opening installer...'**
  String get downloadComplete;

  /// No description provided for @preparing.
  ///
  /// In en, this message translates to:
  /// **'Preparing...'**
  String get preparing;

  /// No description provided for @resumeDownload.
  ///
  /// In en, this message translates to:
  /// **'Resume download'**
  String get resumeDownload;

  /// No description provided for @downloadErrorGeneric.
  ///
  /// In en, this message translates to:
  /// **'Could not download update. Please check your internet connection.'**
  String get downloadErrorGeneric;

  /// No description provided for @downloadErrorTimeout.
  ///
  /// In en, this message translates to:
  /// **'Connection timeout. Please try again.'**
  String get downloadErrorTimeout;

  /// No description provided for @downloadErrorNotFound.
  ///
  /// In en, this message translates to:
  /// **'Update file not found on server.'**
  String get downloadErrorNotFound;
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
      <String>['en', 'vi'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'vi':
      return AppLocalizationsVi();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
