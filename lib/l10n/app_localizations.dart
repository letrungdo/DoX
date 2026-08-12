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

  /// No description provided for @priceOpen.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get priceOpen;

  /// No description provided for @priceHigh.
  ///
  /// In en, this message translates to:
  /// **'High'**
  String get priceHigh;

  /// No description provided for @priceLow.
  ///
  /// In en, this message translates to:
  /// **'Low'**
  String get priceLow;

  /// No description provided for @priceClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get priceClose;

  /// No description provided for @high52Week.
  ///
  /// In en, this message translates to:
  /// **'52W High'**
  String get high52Week;

  /// No description provided for @low52Week.
  ///
  /// In en, this message translates to:
  /// **'52W Low'**
  String get low52Week;

  /// No description provided for @priceRef.
  ///
  /// In en, this message translates to:
  /// **'Prev close'**
  String get priceRef;

  /// No description provided for @changeYear.
  ///
  /// In en, this message translates to:
  /// **'1Y change'**
  String get changeYear;

  /// No description provided for @marketCap.
  ///
  /// In en, this message translates to:
  /// **'Market cap'**
  String get marketCap;

  /// No description provided for @volume24h.
  ///
  /// In en, this message translates to:
  /// **'24h volume'**
  String get volume24h;

  /// No description provided for @tradeVolume.
  ///
  /// In en, this message translates to:
  /// **'Volume'**
  String get tradeVolume;

  /// No description provided for @tradeValue.
  ///
  /// In en, this message translates to:
  /// **'Turnover'**
  String get tradeValue;

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
  /// **'Write a review…'**
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
  /// **'The compressed video is still {size}MB, over My Life\'s 6MB limit.\n\nReduce quality to 480p, or go back and shorten the video?'**
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

  /// No description provided for @electricity.
  ///
  /// In en, this message translates to:
  /// **'Electricity'**
  String get electricity;

  /// No description provided for @electricityTitle.
  ///
  /// In en, this message translates to:
  /// **'Electricity management'**
  String get electricityTitle;

  /// No description provided for @pageLayout.
  ///
  /// In en, this message translates to:
  /// **'Tabs & menu'**
  String get pageLayout;

  /// No description provided for @menuTabAlwaysPinned.
  ///
  /// In en, this message translates to:
  /// **'The Menu tab is always shown.'**
  String get menuTabAlwaysPinned;

  /// No description provided for @bottomTabs.
  ///
  /// In en, this message translates to:
  /// **'Bottom tabs'**
  String get bottomTabs;

  /// No description provided for @moveToMenu.
  ///
  /// In en, this message translates to:
  /// **'Move to menu'**
  String get moveToMenu;

  /// No description provided for @moveToBottomTabs.
  ///
  /// In en, this message translates to:
  /// **'Move to bottom tabs'**
  String get moveToBottomTabs;

  /// No description provided for @noPagesHere.
  ///
  /// In en, this message translates to:
  /// **'Nothing here yet.'**
  String get noPagesHere;

  /// No description provided for @maxTabsReached.
  ///
  /// In en, this message translates to:
  /// **'The bottom bar holds up to {count} pages.'**
  String maxTabsReached(int count);

  /// No description provided for @electricReminder.
  ///
  /// In en, this message translates to:
  /// **'Monthly electricity reminder'**
  String get electricReminder;

  /// No description provided for @electricNotificationTitle.
  ///
  /// In en, this message translates to:
  /// **'Electricity bill time ⚡'**
  String get electricNotificationTitle;

  /// No description provided for @electricNotificationBody.
  ///
  /// In en, this message translates to:
  /// **'Check last month\'s power usage and bill in the app!'**
  String get electricNotificationBody;

  /// No description provided for @electricLoginTitle.
  ///
  /// In en, this message translates to:
  /// **'Sign in to CPC customer care'**
  String get electricLoginTitle;

  /// No description provided for @username.
  ///
  /// In en, this message translates to:
  /// **'Username'**
  String get username;

  /// No description provided for @password.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get password;

  /// No description provided for @customerCode.
  ///
  /// In en, this message translates to:
  /// **'Customer code'**
  String get customerCode;

  /// No description provided for @meterId.
  ///
  /// In en, this message translates to:
  /// **'Meter ID'**
  String get meterId;

  /// No description provided for @electricUsage.
  ///
  /// In en, this message translates to:
  /// **'Power consumption'**
  String get electricUsage;

  /// No description provided for @today.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get today;

  /// No description provided for @yesterday.
  ///
  /// In en, this message translates to:
  /// **'Yesterday'**
  String get yesterday;

  /// No description provided for @thisMonth.
  ///
  /// In en, this message translates to:
  /// **'This month'**
  String get thisMonth;

  /// No description provided for @lastMonth.
  ///
  /// In en, this message translates to:
  /// **'Last month'**
  String get lastMonth;

  /// No description provided for @latestMeterReading.
  ///
  /// In en, this message translates to:
  /// **'Latest reading'**
  String get latestMeterReading;

  /// No description provided for @spiderReadings.
  ///
  /// In en, this message translates to:
  /// **'RF-SPIDER readings'**
  String get spiderReadings;

  /// No description provided for @dailyUsage.
  ///
  /// In en, this message translates to:
  /// **'Daily consumption'**
  String get dailyUsage;

  /// No description provided for @seriesThisYear.
  ///
  /// In en, this message translates to:
  /// **'This year'**
  String get seriesThisYear;

  /// No description provided for @seriesLastYear.
  ///
  /// In en, this message translates to:
  /// **'Same period last year'**
  String get seriesLastYear;

  /// No description provided for @addAccount.
  ///
  /// In en, this message translates to:
  /// **'Add account'**
  String get addAccount;

  /// No description provided for @savedAccounts.
  ///
  /// In en, this message translates to:
  /// **'Saved accounts'**
  String get savedAccounts;

  /// No description provided for @forgetAccountConfirm.
  ///
  /// In en, this message translates to:
  /// **'Remove the saved account {name}? You will need to type the password again next time.'**
  String forgetAccountConfirm(String name);

  /// No description provided for @removeAccountConfirm.
  ///
  /// In en, this message translates to:
  /// **'Sign {name} out of the app?'**
  String removeAccountConfirm(String name);

  /// No description provided for @billingHistory.
  ///
  /// In en, this message translates to:
  /// **'Billing history'**
  String get billingHistory;

  /// No description provided for @monthLabel.
  ///
  /// In en, this message translates to:
  /// **'{month}/{year}'**
  String monthLabel(String month, String year);

  /// No description provided for @sameMonthLastYear.
  ///
  /// In en, this message translates to:
  /// **'Same month last year: {value}'**
  String sameMonthLastYear(String value);

  /// No description provided for @mergedTab.
  ///
  /// In en, this message translates to:
  /// **'Combined'**
  String get mergedTab;

  /// No description provided for @mergedTabSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Meters of one customer'**
  String get mergedTabSubtitle;

  /// No description provided for @mergedSavingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Saved by splitting the meters'**
  String get mergedSavingsTitle;

  /// No description provided for @mergedSavingsTotal.
  ///
  /// In en, this message translates to:
  /// **'Total saved'**
  String get mergedSavingsTotal;

  /// No description provided for @mergedSingleMeterCost.
  ///
  /// In en, this message translates to:
  /// **'On one household meter'**
  String get mergedSingleMeterCost;

  /// No description provided for @mergedActualCost.
  ///
  /// In en, this message translates to:
  /// **'Actually paid'**
  String get mergedActualCost;

  /// No description provided for @mergedAveragePerMonth.
  ///
  /// In en, this message translates to:
  /// **'Average per month'**
  String get mergedAveragePerMonth;

  /// No description provided for @mergedMonthsCounted.
  ///
  /// In en, this message translates to:
  /// **'{count} months with both meters'**
  String mergedMonthsCounted(String count);

  /// No description provided for @mergedMeters.
  ///
  /// In en, this message translates to:
  /// **'{count} meters under the same customer name'**
  String mergedMeters(String count);

  /// No description provided for @mergedMonthlyTitle.
  ///
  /// In en, this message translates to:
  /// **'Combined bill by month'**
  String get mergedMonthlyTitle;

  /// No description provided for @mergedSavingsLabel.
  ///
  /// In en, this message translates to:
  /// **'Saved'**
  String get mergedSavingsLabel;

  /// No description provided for @mergedSplitLabel.
  ///
  /// In en, this message translates to:
  /// **'Household {residential} · Other {other}'**
  String mergedSplitLabel(String residential, String other);

  /// No description provided for @mergedNeedsBothMeters.
  ///
  /// In en, this message translates to:
  /// **'Sign in to both a household and a non-household account to compare.'**
  String get mergedNeedsBothMeters;

  /// No description provided for @mergedNoOverlap.
  ///
  /// In en, this message translates to:
  /// **'No month has a bill from both meters yet.'**
  String get mergedNoOverlap;

  /// No description provided for @mergedNoGroups.
  ///
  /// In en, this message translates to:
  /// **'No customer here holds more than one meter. This tab only adds up meters under the same customer name.'**
  String get mergedNoGroups;

  /// No description provided for @mergedEstimateNote.
  ///
  /// In en, this message translates to:
  /// **'Estimated with the progressive household tariff (one allowance), calibrated against the same month\'s real household bill.'**
  String get mergedEstimateNote;

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

  /// No description provided for @myLife.
  ///
  /// In en, this message translates to:
  /// **'My Life'**
  String get myLife;

  /// No description provided for @lunar.
  ///
  /// In en, this message translates to:
  /// **'Lunar'**
  String get lunar;

  /// No description provided for @lunarTab.
  ///
  /// In en, this message translates to:
  /// **'Calendar'**
  String get lunarTab;

  /// No description provided for @lunarCalendar.
  ///
  /// In en, this message translates to:
  /// **'Lunar calendar'**
  String get lunarCalendar;

  /// No description provided for @lunarToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get lunarToday;

  /// No description provided for @lunarSolarDate.
  ///
  /// In en, this message translates to:
  /// **'Solar'**
  String get lunarSolarDate;

  /// No description provided for @lunarLunarDate.
  ///
  /// In en, this message translates to:
  /// **'Lunar'**
  String get lunarLunarDate;

  /// No description provided for @lunarLeapMonth.
  ///
  /// In en, this message translates to:
  /// **'leap'**
  String get lunarLeapMonth;

  /// No description provided for @lunarDayOfWeek.
  ///
  /// In en, this message translates to:
  /// **'Day'**
  String get lunarDayOfWeek;

  /// No description provided for @lunarCanChiDay.
  ///
  /// In en, this message translates to:
  /// **'Day'**
  String get lunarCanChiDay;

  /// No description provided for @lunarCanChiMonth.
  ///
  /// In en, this message translates to:
  /// **'Month'**
  String get lunarCanChiMonth;

  /// No description provided for @lunarCanChiYear.
  ///
  /// In en, this message translates to:
  /// **'Year'**
  String get lunarCanChiYear;

  /// No description provided for @lunarCanChiHour.
  ///
  /// In en, this message translates to:
  /// **'Hour'**
  String get lunarCanChiHour;

  /// No description provided for @lunarGoodDay.
  ///
  /// In en, this message translates to:
  /// **'Auspicious day'**
  String get lunarGoodDay;

  /// No description provided for @lunarBadDay.
  ///
  /// In en, this message translates to:
  /// **'Inauspicious day'**
  String get lunarBadDay;

  /// No description provided for @lunarSolarTerm.
  ///
  /// In en, this message translates to:
  /// **'Solar term'**
  String get lunarSolarTerm;

  /// No description provided for @lunarTide.
  ///
  /// In en, this message translates to:
  /// **'Tide'**
  String get lunarTide;

  /// No description provided for @lunarGoodHours.
  ///
  /// In en, this message translates to:
  /// **'Good hours'**
  String get lunarGoodHours;

  /// No description provided for @rebootRouter.
  ///
  /// In en, this message translates to:
  /// **'Reboot Router'**
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

  /// No description provided for @editSaleRound.
  ///
  /// In en, this message translates to:
  /// **'Edit sale'**
  String get editSaleRound;

  /// No description provided for @lunarDatePickerTitle.
  ///
  /// In en, this message translates to:
  /// **'Pick a date (Lunar)'**
  String get lunarDatePickerTitle;

  /// No description provided for @lunarShort.
  ///
  /// In en, this message translates to:
  /// **'Lunar'**
  String get lunarShort;

  /// No description provided for @solarShort.
  ///
  /// In en, this message translates to:
  /// **'Solar'**
  String get solarShort;

  /// No description provided for @chickenLunarCalendarDesc.
  ///
  /// In en, this message translates to:
  /// **'Show chicken dates on the lunar calendar'**
  String get chickenLunarCalendarDesc;

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

  /// No description provided for @wifiShort.
  ///
  /// In en, this message translates to:
  /// **'Wifi'**
  String get wifiShort;

  /// No description provided for @fengShuiCompass.
  ///
  /// In en, this message translates to:
  /// **'Feng shui compass'**
  String get fengShuiCompass;

  /// No description provided for @compass.
  ///
  /// In en, this message translates to:
  /// **'Compass'**
  String get compass;

  /// No description provided for @fengShuiHouseFacing.
  ///
  /// In en, this message translates to:
  /// **'House facing'**
  String get fengShuiHouseFacing;

  /// No description provided for @fengShuiSitting.
  ///
  /// In en, this message translates to:
  /// **'Sitting (back)'**
  String get fengShuiSitting;

  /// No description provided for @fengShuiTrigram.
  ///
  /// In en, this message translates to:
  /// **'Trigram'**
  String get fengShuiTrigram;

  /// No description provided for @fengShuiElement.
  ///
  /// In en, this message translates to:
  /// **'Element'**
  String get fengShuiElement;

  /// No description provided for @fengShuiMountain.
  ///
  /// In en, this message translates to:
  /// **'Mountain'**
  String get fengShuiMountain;

  /// No description provided for @fengShuiCalibrateHint.
  ///
  /// In en, this message translates to:
  /// **'Move the phone in a figure-8 to calibrate, and keep it away from metal or magnets.'**
  String get fengShuiCalibrateHint;

  /// No description provided for @fengShuiNoSensor.
  ///
  /// In en, this message translates to:
  /// **'This device has no compass sensor.'**
  String get fengShuiNoSensor;

  /// No description provided for @fengShuiHoldFlat.
  ///
  /// In en, this message translates to:
  /// **'Hold the phone flat, top edge pointing toward the house facing.'**
  String get fengShuiHoldFlat;

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
  /// **'Testing…'**
  String get testing;

  /// No description provided for @speedMbps.
  ///
  /// In en, this message translates to:
  /// **'{speed} Mbps'**
  String speedMbps(String speed);

  /// No description provided for @marketPicker.
  ///
  /// In en, this message translates to:
  /// **'Choose markets'**
  String get marketPicker;

  /// No description provided for @marketSelected.
  ///
  /// In en, this message translates to:
  /// **'{count} selected'**
  String marketSelected(int count);

  /// No description provided for @marketEmpty.
  ///
  /// In en, this message translates to:
  /// **'No market selected yet.'**
  String get marketEmpty;

  /// No description provided for @selectAll.
  ///
  /// In en, this message translates to:
  /// **'Select all'**
  String get selectAll;

  /// No description provided for @unselectAll.
  ///
  /// In en, this message translates to:
  /// **'Clear all'**
  String get unselectAll;

  /// No description provided for @marketGroupCommodity.
  ///
  /// In en, this message translates to:
  /// **'Commodities'**
  String get marketGroupCommodity;

  /// No description provided for @marketGroupCrypto.
  ///
  /// In en, this message translates to:
  /// **'Crypto'**
  String get marketGroupCrypto;

  /// No description provided for @marketGroupVnIndex.
  ///
  /// In en, this message translates to:
  /// **'Vietnam indices'**
  String get marketGroupVnIndex;

  /// No description provided for @marketGroupWorldIndex.
  ///
  /// In en, this message translates to:
  /// **'World indices'**
  String get marketGroupWorldIndex;

  /// No description provided for @marketGroupUsStock.
  ///
  /// In en, this message translates to:
  /// **'US stocks'**
  String get marketGroupUsStock;

  /// No description provided for @goldPrice.
  ///
  /// In en, this message translates to:
  /// **'Gold Price'**
  String get goldPrice;

  /// No description provided for @exchangeRate.
  ///
  /// In en, this message translates to:
  /// **'Exchange rate'**
  String get exchangeRate;

  /// No description provided for @market.
  ///
  /// In en, this message translates to:
  /// **'Market'**
  String get market;

  /// No description provided for @goldNews.
  ///
  /// In en, this message translates to:
  /// **'Gold price drivers'**
  String get goldNews;

  /// No description provided for @goldNewsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No digest for today yet.'**
  String get goldNewsEmpty;

  /// No description provided for @goldNewsSources.
  ///
  /// In en, this message translates to:
  /// **'Sources'**
  String get goldNewsSources;

  /// No description provided for @goldNewsDetails.
  ///
  /// In en, this message translates to:
  /// **'Details ({count})'**
  String goldNewsDetails(int count);

  /// No description provided for @goldNewsCollapse.
  ///
  /// In en, this message translates to:
  /// **'Collapse'**
  String get goldNewsCollapse;

  /// No description provided for @goldNewsUpdatedAt.
  ///
  /// In en, this message translates to:
  /// **'Compiled {time}'**
  String goldNewsUpdatedAt(String time);

  /// No description provided for @trendUp.
  ///
  /// In en, this message translates to:
  /// **'Trending up'**
  String get trendUp;

  /// No description provided for @trendDown.
  ///
  /// In en, this message translates to:
  /// **'Trending down'**
  String get trendDown;

  /// No description provided for @trendNeutral.
  ///
  /// In en, this message translates to:
  /// **'Sideways'**
  String get trendNeutral;

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

  /// No description provided for @chickenSharing.
  ///
  /// In en, this message translates to:
  /// **'Share chicken data'**
  String get chickenSharing;

  /// No description provided for @chickenSharingDescription.
  ///
  /// In en, this message translates to:
  /// **'People you add can view all chicken data, but cannot add, edit, or delete anything.'**
  String get chickenSharingDescription;

  /// No description provided for @shareWithEmail.
  ///
  /// In en, this message translates to:
  /// **'Share with email'**
  String get shareWithEmail;

  /// No description provided for @shareAction.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get shareAction;

  /// No description provided for @sharedWith.
  ///
  /// In en, this message translates to:
  /// **'People with access'**
  String get sharedWith;

  /// No description provided for @notSharedYet.
  ///
  /// In en, this message translates to:
  /// **'Not shared with anyone yet.'**
  String get notSharedYet;

  /// No description provided for @shareAccessAdded.
  ///
  /// In en, this message translates to:
  /// **'Read-only access granted.'**
  String get shareAccessAdded;

  /// No description provided for @shareAccessAddedEmailSent.
  ///
  /// In en, this message translates to:
  /// **'Read-only access granted and notification email sent.'**
  String get shareAccessAddedEmailSent;

  /// No description provided for @shareAccessAddedEmailFailed.
  ///
  /// In en, this message translates to:
  /// **'Read-only access granted, but the notification email could not be sent.'**
  String get shareAccessAddedEmailFailed;

  /// No description provided for @shareEmailNotRegistered.
  ///
  /// In en, this message translates to:
  /// **'No Do X account uses that email yet — ask them to sign up first.'**
  String get shareEmailNotRegistered;

  /// No description provided for @shareEmailIsYourself.
  ///
  /// In en, this message translates to:
  /// **'That is your own email — the data is already yours.'**
  String get shareEmailIsYourself;

  /// No description provided for @shareAccessFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not share: {error}'**
  String shareAccessFailed(String error);

  /// No description provided for @revokeAccess.
  ///
  /// In en, this message translates to:
  /// **'Revoke access'**
  String get revokeAccess;

  /// No description provided for @viewChickenDataFrom.
  ///
  /// In en, this message translates to:
  /// **'View chicken data from'**
  String get viewChickenDataFrom;

  /// No description provided for @myChickenData.
  ///
  /// In en, this message translates to:
  /// **'My data'**
  String get myChickenData;

  /// No description provided for @sharedReadOnly.
  ///
  /// In en, this message translates to:
  /// **'Viewing {email} · Read only'**
  String sharedReadOnly(String email);

  /// No description provided for @readOnly.
  ///
  /// In en, this message translates to:
  /// **'Read only'**
  String get readOnly;

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

  /// No description provided for @exportData.
  ///
  /// In en, this message translates to:
  /// **'Export data (JSON)'**
  String get exportData;

  /// No description provided for @exportDataSubtitle.
  ///
  /// In en, this message translates to:
  /// **'A file you can import back later.'**
  String get exportDataSubtitle;

  /// No description provided for @exportDataSuccess.
  ///
  /// In en, this message translates to:
  /// **'Chicken data exported.'**
  String get exportDataSuccess;

  /// No description provided for @exportFileFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not export the data: {error}'**
  String exportFileFailed(String error);

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
  /// **'Year'**
  String get yearLabel;

  /// No description provided for @selectYear.
  ///
  /// In en, this message translates to:
  /// **'Select year'**
  String get selectYear;

  /// No description provided for @all.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get all;

  /// No description provided for @saleCount.
  ///
  /// In en, this message translates to:
  /// **'{count} sales'**
  String saleCount(int count);

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
  /// **'Downloading update…'**
  String get downloadingUpdate;

  /// No description provided for @downloadComplete.
  ///
  /// In en, this message translates to:
  /// **'Download complete, opening installer…'**
  String get downloadComplete;

  /// No description provided for @preparing.
  ///
  /// In en, this message translates to:
  /// **'Preparing…'**
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

  /// No description provided for @downloadingUpdateVersion.
  ///
  /// In en, this message translates to:
  /// **'Downloading update v{version}'**
  String downloadingUpdateVersion(String version);

  /// No description provided for @updateReadyToInstall.
  ///
  /// In en, this message translates to:
  /// **'Update v{version} ready'**
  String updateReadyToInstall(String version);

  /// No description provided for @install.
  ///
  /// In en, this message translates to:
  /// **'Install'**
  String get install;

  /// No description provided for @add.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get add;

  /// No description provided for @confirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get confirm;

  /// No description provided for @pleaseWait.
  ///
  /// In en, this message translates to:
  /// **'Please wait…'**
  String get pleaseWait;

  /// No description provided for @deleteAllChickenData.
  ///
  /// In en, this message translates to:
  /// **'Delete all chicken data'**
  String get deleteAllChickenData;

  /// No description provided for @statusWaitingHatch.
  ///
  /// In en, this message translates to:
  /// **'Hatching - {date}'**
  String statusWaitingHatch(String date);

  /// No description provided for @statusSoldOut.
  ///
  /// In en, this message translates to:
  /// **'Sold out'**
  String get statusSoldOut;

  /// No description provided for @statusDaysOld.
  ///
  /// In en, this message translates to:
  /// **'{days} days old'**
  String statusDaysOld(int days);

  /// No description provided for @statusMonthsOld.
  ///
  /// In en, this message translates to:
  /// **'{months} months old'**
  String statusMonthsOld(int months);

  /// No description provided for @statusMonthsDaysOld.
  ///
  /// In en, this message translates to:
  /// **'{months}mo {days}d old'**
  String statusMonthsDaysOld(int months, int days);

  /// No description provided for @chickenQuantity.
  ///
  /// In en, this message translates to:
  /// **'{count} chickens'**
  String chickenQuantity(int count);

  /// No description provided for @soldOfTotal.
  ///
  /// In en, this message translates to:
  /// **'Sold {sold}/{total}'**
  String soldOfTotal(int sold, int total);

  /// No description provided for @hatchedOnDate.
  ///
  /// In en, this message translates to:
  /// **'Hatched {date}'**
  String hatchedOnDate(String date);

  /// No description provided for @soldOnDate.
  ///
  /// In en, this message translates to:
  /// **'Sold {date}'**
  String soldOnDate(String date);

  /// No description provided for @badgeRevenue.
  ///
  /// In en, this message translates to:
  /// **'Revenue'**
  String get badgeRevenue;

  /// No description provided for @badgeExpense.
  ///
  /// In en, this message translates to:
  /// **'Expense'**
  String get badgeExpense;

  /// No description provided for @badgeProfit.
  ///
  /// In en, this message translates to:
  /// **'Profit'**
  String get badgeProfit;

  /// No description provided for @importedRecords.
  ///
  /// In en, this message translates to:
  /// **'Imported {count} records from {file}.'**
  String importedRecords(int count, String file);

  /// No description provided for @importFileFailed.
  ///
  /// In en, this message translates to:
  /// **'Import failed: {error}'**
  String importFileFailed(String error);

  /// No description provided for @importingData.
  ///
  /// In en, this message translates to:
  /// **'Importing data'**
  String get importingData;

  /// No description provided for @confirmDeleteAllChickenData.
  ///
  /// In en, this message translates to:
  /// **'Delete all chicken data?'**
  String get confirmDeleteAllChickenData;

  /// No description provided for @deleteData.
  ///
  /// In en, this message translates to:
  /// **'Delete data'**
  String get deleteData;

  /// No description provided for @deleteAllChickenDataWarning.
  ///
  /// In en, this message translates to:
  /// **'All batches, revenue and expenses of the current account will be permanently deleted. This action cannot be undone.'**
  String get deleteAllChickenDataWarning;

  /// No description provided for @confirmPasswordToDelete.
  ///
  /// In en, this message translates to:
  /// **'Enter your password to confirm the deletion.'**
  String get confirmPasswordToDelete;

  /// No description provided for @passwordRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter your password.'**
  String get passwordRequired;

  /// No description provided for @passwordIncorrect.
  ///
  /// In en, this message translates to:
  /// **'That password is not correct.'**
  String get passwordIncorrect;

  /// No description provided for @deletingData.
  ///
  /// In en, this message translates to:
  /// **'Deleting data'**
  String get deletingData;

  /// No description provided for @noDataToDelete.
  ///
  /// In en, this message translates to:
  /// **'No data to delete.'**
  String get noDataToDelete;

  /// No description provided for @deletedAllData.
  ///
  /// In en, this message translates to:
  /// **'Deleted all data ({count} main records).'**
  String deletedAllData(int count);

  /// No description provided for @deleteDataFailed.
  ///
  /// In en, this message translates to:
  /// **'Delete failed: {error}'**
  String deleteDataFailed(String error);

  /// No description provided for @addNewBatch.
  ///
  /// In en, this message translates to:
  /// **'Add new batch'**
  String get addNewBatch;

  /// No description provided for @batchName.
  ///
  /// In en, this message translates to:
  /// **'Batch name'**
  String get batchName;

  /// No description provided for @batchNameHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Flock 31'**
  String get batchNameHint;

  /// No description provided for @batchNamePrefill.
  ///
  /// In en, this message translates to:
  /// **'Flock {number}'**
  String batchNamePrefill(int number);

  /// No description provided for @eggQuantity.
  ///
  /// In en, this message translates to:
  /// **'Number of eggs/chicks'**
  String get eggQuantity;

  /// No description provided for @incubationDate.
  ///
  /// In en, this message translates to:
  /// **'Incubation date'**
  String get incubationDate;

  /// No description provided for @batchDetailTitle.
  ///
  /// In en, this message translates to:
  /// **'Batch details'**
  String get batchDetailTitle;

  /// No description provided for @batchNotFound.
  ///
  /// In en, this message translates to:
  /// **'Batch not found.'**
  String get batchNotFound;

  /// No description provided for @deleteThisBatch.
  ///
  /// In en, this message translates to:
  /// **'Delete this batch'**
  String get deleteThisBatch;

  /// No description provided for @initialQuantity.
  ///
  /// In en, this message translates to:
  /// **'Quantity'**
  String get initialQuantity;

  /// No description provided for @soldRemainingLabel.
  ///
  /// In en, this message translates to:
  /// **'Sold / remaining'**
  String get soldRemainingLabel;

  /// No description provided for @remainingLabel.
  ///
  /// In en, this message translates to:
  /// **'Remaining'**
  String get remainingLabel;

  /// No description provided for @soldRemainingValue.
  ///
  /// In en, this message translates to:
  /// **'{sold} / {remaining}'**
  String soldRemainingValue(int sold, int remaining);

  /// No description provided for @incubationDay.
  ///
  /// In en, this message translates to:
  /// **'Incubation date'**
  String get incubationDay;

  /// No description provided for @expectedHatch.
  ///
  /// In en, this message translates to:
  /// **'Expected hatch'**
  String get expectedHatch;

  /// No description provided for @actualHatchDateLabel.
  ///
  /// In en, this message translates to:
  /// **'Actual hatch date'**
  String get actualHatchDateLabel;

  /// No description provided for @ageLabel.
  ///
  /// In en, this message translates to:
  /// **'Age'**
  String get ageLabel;

  /// No description provided for @daysCount.
  ///
  /// In en, this message translates to:
  /// **'{days} days'**
  String daysCount(int days);

  /// No description provided for @statusLabel.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get statusLabel;

  /// No description provided for @notHatchedYet.
  ///
  /// In en, this message translates to:
  /// **'Not hatched ({days} days left)'**
  String notHatchedYet(int days);

  /// No description provided for @vaccinationSchedule.
  ///
  /// In en, this message translates to:
  /// **'Vaccination schedule'**
  String get vaccinationSchedule;

  /// No description provided for @dateValue.
  ///
  /// In en, this message translates to:
  /// **'Date: {date}'**
  String dateValue(String date);

  /// No description provided for @expensesSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Expenses (Total: {amount})'**
  String expensesSectionTitle(String amount);

  /// No description provided for @expensesTitle.
  ///
  /// In en, this message translates to:
  /// **'Expenses'**
  String get expensesTitle;

  /// No description provided for @noExpensesYet.
  ///
  /// In en, this message translates to:
  /// **'No expenses yet.'**
  String get noExpensesYet;

  /// No description provided for @saleAndProfit.
  ///
  /// In en, this message translates to:
  /// **'Sales & Profit'**
  String get saleAndProfit;

  /// No description provided for @notSoldHint.
  ///
  /// In en, this message translates to:
  /// **'Not sold yet. A batch can be sold in multiple rounds.'**
  String get notSoldHint;

  /// No description provided for @suggestedPrice.
  ///
  /// In en, this message translates to:
  /// **'Suggested price'**
  String get suggestedPrice;

  /// No description provided for @pricePerChicken.
  ///
  /// In en, this message translates to:
  /// **'{amount}/chicken'**
  String pricePerChicken(String amount);

  /// No description provided for @chickenSale.
  ///
  /// In en, this message translates to:
  /// **'Chicken sale'**
  String get chickenSale;

  /// No description provided for @soldLabel.
  ///
  /// In en, this message translates to:
  /// **'Sold'**
  String get soldLabel;

  /// No description provided for @soldAndRemaining.
  ///
  /// In en, this message translates to:
  /// **'{sold} sold, {remaining} remaining'**
  String soldAndRemaining(int sold, int remaining);

  /// No description provided for @totalRevenueLabel.
  ///
  /// In en, this message translates to:
  /// **'Total revenue'**
  String get totalRevenueLabel;

  /// No description provided for @totalExpensesLabel.
  ///
  /// In en, this message translates to:
  /// **'Total expenses'**
  String get totalExpensesLabel;

  /// No description provided for @profitUpper.
  ///
  /// In en, this message translates to:
  /// **'PROFIT'**
  String get profitUpper;

  /// No description provided for @recordNewSale.
  ///
  /// In en, this message translates to:
  /// **'Record new sale'**
  String get recordNewSale;

  /// No description provided for @deleteSaleRound.
  ///
  /// In en, this message translates to:
  /// **'Delete sale'**
  String get deleteSaleRound;

  /// No description provided for @confirmDeleteSaleRound.
  ///
  /// In en, this message translates to:
  /// **'Delete the sale on {date} ({amount})?'**
  String confirmDeleteSaleRound(String date, String amount);

  /// No description provided for @addExpense.
  ///
  /// In en, this message translates to:
  /// **'Add expense'**
  String get addExpense;

  /// No description provided for @editExpense.
  ///
  /// In en, this message translates to:
  /// **'Edit expense'**
  String get editExpense;

  /// No description provided for @deleteExpense.
  ///
  /// In en, this message translates to:
  /// **'Delete expense'**
  String get deleteExpense;

  /// No description provided for @confirmDeleteExpense.
  ///
  /// In en, this message translates to:
  /// **'Delete the expense {label} ({amount})?'**
  String confirmDeleteExpense(String label, String amount);

  /// No description provided for @recordSale.
  ///
  /// In en, this message translates to:
  /// **'Record sale'**
  String get recordSale;

  /// No description provided for @quantityLabel.
  ///
  /// In en, this message translates to:
  /// **'Quantity'**
  String get quantityLabel;

  /// No description provided for @pricePerUnit.
  ///
  /// In en, this message translates to:
  /// **'Price each'**
  String get pricePerUnit;

  /// No description provided for @totalAutoCalculated.
  ///
  /// In en, this message translates to:
  /// **'Total received (auto)'**
  String get totalAutoCalculated;

  /// No description provided for @priceSuggestion.
  ///
  /// In en, this message translates to:
  /// **'Suggested {price}/chicken'**
  String priceSuggestion(String price);

  /// No description provided for @priceSuggestionBasis.
  ///
  /// In en, this message translates to:
  /// **'From {count} past sales around day {age}'**
  String priceSuggestionBasis(int count, int age);

  /// No description provided for @priceSuggestionBasisAll.
  ///
  /// In en, this message translates to:
  /// **'From all {count} past sales ({min} - {max})'**
  String priceSuggestionBasisAll(int count, String min, String max);

  /// No description provided for @saleNoteHint.
  ///
  /// In en, this message translates to:
  /// **'Note (sold to whom…)'**
  String get saleNoteHint;

  /// No description provided for @saleDate.
  ///
  /// In en, this message translates to:
  /// **'Sale date'**
  String get saleDate;

  /// No description provided for @deleteBatch.
  ///
  /// In en, this message translates to:
  /// **'Delete batch'**
  String get deleteBatch;

  /// No description provided for @confirmDeleteBatch.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete batch \'{name}\'? This action cannot be undone.'**
  String confirmDeleteBatch(String name);

  /// No description provided for @editBatchInfo.
  ///
  /// In en, this message translates to:
  /// **'Edit batch info'**
  String get editBatchInfo;

  /// No description provided for @fightingChicken.
  ///
  /// In en, this message translates to:
  /// **'Fighting rooster'**
  String get fightingChicken;

  /// No description provided for @meatChicken.
  ///
  /// In en, this message translates to:
  /// **'Meat chicken'**
  String get meatChicken;

  /// No description provided for @noCockSalesData.
  ///
  /// In en, this message translates to:
  /// **'No sales data yet'**
  String get noCockSalesData;

  /// No description provided for @noMatchingSales.
  ///
  /// In en, this message translates to:
  /// **'No matching sales.'**
  String get noMatchingSales;

  /// No description provided for @noSalesInYear.
  ///
  /// In en, this message translates to:
  /// **'No sales in {year}.'**
  String noSalesInYear(int year);

  /// No description provided for @enterFirstSale.
  ///
  /// In en, this message translates to:
  /// **'Record your first sale'**
  String get enterFirstSale;

  /// No description provided for @editSale.
  ///
  /// In en, this message translates to:
  /// **'Edit sale'**
  String get editSale;

  /// No description provided for @enterCockSale.
  ///
  /// In en, this message translates to:
  /// **'Record chicken sale'**
  String get enterCockSale;

  /// No description provided for @soldMeatChickenNote.
  ///
  /// In en, this message translates to:
  /// **'Meat chicken sale'**
  String get soldMeatChickenNote;

  /// No description provided for @soldFightingChickenNote.
  ///
  /// In en, this message translates to:
  /// **'Fighting rooster sale'**
  String get soldFightingChickenNote;

  /// No description provided for @saveFailed.
  ///
  /// In en, this message translates to:
  /// **'Save failed: {error}'**
  String saveFailed(String error);

  /// No description provided for @fightingChickenFull.
  ///
  /// In en, this message translates to:
  /// **'Fighting rooster'**
  String get fightingChickenFull;

  /// No description provided for @salePrice.
  ///
  /// In en, this message translates to:
  /// **'Sale price'**
  String get salePrice;

  /// No description provided for @cockSaleNoteHint.
  ///
  /// In en, this message translates to:
  /// **'Note (which chicken, condition…)'**
  String get cockSaleNoteHint;

  /// No description provided for @deleteSaleRecord.
  ///
  /// In en, this message translates to:
  /// **'Delete sale'**
  String get deleteSaleRecord;

  /// No description provided for @confirmDeleteSaleRecord.
  ///
  /// In en, this message translates to:
  /// **'Delete the sale on {date} ({amount})?'**
  String confirmDeleteSaleRecord(String date, String amount);

  /// No description provided for @deleteFailed.
  ///
  /// In en, this message translates to:
  /// **'Delete failed: {error}'**
  String deleteFailed(String error);

  /// No description provided for @byMonth.
  ///
  /// In en, this message translates to:
  /// **'Monthly'**
  String get byMonth;

  /// No description provided for @byYear.
  ///
  /// In en, this message translates to:
  /// **'Yearly'**
  String get byYear;

  /// No description provided for @noDataInYear.
  ///
  /// In en, this message translates to:
  /// **'No data in {year}.'**
  String noDataInYear(int year);

  /// No description provided for @monthPrefix.
  ///
  /// In en, this message translates to:
  /// **'Month'**
  String get monthPrefix;

  /// No description provided for @noStatsData.
  ///
  /// In en, this message translates to:
  /// **'No statistics yet.'**
  String get noStatsData;

  /// No description provided for @batchRevenue.
  ///
  /// In en, this message translates to:
  /// **'Chick revenue'**
  String get batchRevenue;

  /// No description provided for @cockRevenue.
  ///
  /// In en, this message translates to:
  /// **'Fighting rooster revenue'**
  String get cockRevenue;

  /// No description provided for @meatRevenue.
  ///
  /// In en, this message translates to:
  /// **'Meat chicken revenue'**
  String get meatRevenue;

  /// No description provided for @profitLabel.
  ///
  /// In en, this message translates to:
  /// **'Profit'**
  String get profitLabel;

  /// No description provided for @profitMargin.
  ///
  /// In en, this message translates to:
  /// **'Profit margin'**
  String get profitMargin;

  /// No description provided for @revenueVsExpense.
  ///
  /// In en, this message translates to:
  /// **'Revenue vs expense'**
  String get revenueVsExpense;

  /// No description provided for @revenueBreakdown.
  ///
  /// In en, this message translates to:
  /// **'Revenue breakdown'**
  String get revenueBreakdown;

  /// No description provided for @monthlyDetails.
  ///
  /// In en, this message translates to:
  /// **'Monthly breakdown'**
  String get monthlyDetails;

  /// No description provided for @yearlyDetails.
  ///
  /// In en, this message translates to:
  /// **'Yearly breakdown'**
  String get yearlyDetails;

  /// No description provided for @averagePerMonth.
  ///
  /// In en, this message translates to:
  /// **'Avg / month'**
  String get averagePerMonth;

  /// No description provided for @averagePerYear.
  ///
  /// In en, this message translates to:
  /// **'Avg / year'**
  String get averagePerYear;

  /// No description provided for @bestMonth.
  ///
  /// In en, this message translates to:
  /// **'Best month'**
  String get bestMonth;

  /// No description provided for @bestYear.
  ///
  /// In en, this message translates to:
  /// **'Best year'**
  String get bestYear;

  /// No description provided for @allYearsLabel.
  ///
  /// In en, this message translates to:
  /// **'All years'**
  String get allYearsLabel;

  /// No description provided for @monthShort.
  ///
  /// In en, this message translates to:
  /// **'M{month}'**
  String monthShort(int month);

  /// No description provided for @activeMonths.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 month with data} other{{count} months with data}}'**
  String activeMonths(int count);

  /// No description provided for @activeYears.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 year with data} other{{count} years with data}}'**
  String activeYears(int count);

  /// No description provided for @errorEnterAmount.
  ///
  /// In en, this message translates to:
  /// **'Please enter an amount'**
  String get errorEnterAmount;

  /// No description provided for @errorEnterQuantity.
  ///
  /// In en, this message translates to:
  /// **'Please enter a quantity'**
  String get errorEnterQuantity;

  /// No description provided for @errorQuantityExceedsRemaining.
  ///
  /// In en, this message translates to:
  /// **'Only {remaining} chickens left to sell'**
  String errorQuantityExceedsRemaining(int remaining);

  /// No description provided for @errorEnterBatchName.
  ///
  /// In en, this message translates to:
  /// **'Please enter a batch name'**
  String get errorEnterBatchName;

  /// No description provided for @revenue.
  ///
  /// In en, this message translates to:
  /// **'Revenue'**
  String get revenue;

  /// No description provided for @totalLabel.
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get totalLabel;

  /// No description provided for @sellGrownChicken.
  ///
  /// In en, this message translates to:
  /// **'Sell grown chickens'**
  String get sellGrownChicken;

  /// No description provided for @tabReboot.
  ///
  /// In en, this message translates to:
  /// **'Reboot'**
  String get tabReboot;

  /// No description provided for @tabDevices.
  ///
  /// In en, this message translates to:
  /// **'Devices'**
  String get tabDevices;

  /// No description provided for @tabSpeed.
  ///
  /// In en, this message translates to:
  /// **'Speed'**
  String get tabSpeed;

  /// No description provided for @processing.
  ///
  /// In en, this message translates to:
  /// **'Processing…'**
  String get processing;

  /// No description provided for @rebootSuccessStartSpeedTest.
  ///
  /// In en, this message translates to:
  /// **'Reboot successful, starting speed test'**
  String get rebootSuccessStartSpeedTest;

  /// No description provided for @connectionSpeedTest.
  ///
  /// In en, this message translates to:
  /// **'Check connection speed'**
  String get connectionSpeedTest;

  /// No description provided for @selectInternetServer.
  ///
  /// In en, this message translates to:
  /// **'Select internet test server'**
  String get selectInternetServer;

  /// No description provided for @serverLabel.
  ///
  /// In en, this message translates to:
  /// **'Server'**
  String get serverLabel;

  /// No description provided for @ttfbMs.
  ///
  /// In en, this message translates to:
  /// **'TTFB: {ms}ms'**
  String ttfbMs(int ms);

  /// No description provided for @stopLabel.
  ///
  /// In en, this message translates to:
  /// **'STOP'**
  String get stopLabel;

  /// No description provided for @stopSpeedTest.
  ///
  /// In en, this message translates to:
  /// **'Stop'**
  String get stopSpeedTest;

  /// No description provided for @deviceConfig.
  ///
  /// In en, this message translates to:
  /// **'Device configuration'**
  String get deviceConfig;

  /// No description provided for @adminPasswordHelper.
  ///
  /// In en, this message translates to:
  /// **'Login password for the router admin page (MiWiFi)'**
  String get adminPasswordHelper;

  /// No description provided for @progressTitle.
  ///
  /// In en, this message translates to:
  /// **'Progress:'**
  String get progressTitle;

  /// No description provided for @routerNoResponse.
  ///
  /// In en, this message translates to:
  /// **'Still no response from the router ({seconds}s)…'**
  String routerNoResponse(int seconds);

  /// No description provided for @reconnectingEstimate.
  ///
  /// In en, this message translates to:
  /// **'Reconnecting… (Estimated ~90 seconds)'**
  String get reconnectingEstimate;

  /// No description provided for @skipWaiting.
  ///
  /// In en, this message translates to:
  /// **'Skip waiting'**
  String get skipWaiting;

  /// No description provided for @skipWaitingNote.
  ///
  /// In en, this message translates to:
  /// **'Note: If the router changed IP or the light turned green, you can skip this step.'**
  String get skipWaitingNote;

  /// No description provided for @errorLabel.
  ///
  /// In en, this message translates to:
  /// **'Error!'**
  String get errorLabel;

  /// No description provided for @successLabel.
  ///
  /// In en, this message translates to:
  /// **'Success!'**
  String get successLabel;

  /// No description provided for @consoleLog.
  ///
  /// In en, this message translates to:
  /// **'Detailed log (Console Log)'**
  String get consoleLog;

  /// No description provided for @speedAnalysisLanWeak.
  ///
  /// In en, this message translates to:
  /// **'LAN connection is very weak. Check the network cable or the distance to the repeater.'**
  String get speedAnalysisLanWeak;

  /// No description provided for @speedAnalysisInternetSlow.
  ///
  /// In en, this message translates to:
  /// **'LAN connection is good, but the Internet is slow. The issue may be from the ISP or the main router.'**
  String get speedAnalysisInternetSlow;

  /// No description provided for @speedAnalysisPerfect.
  ///
  /// In en, this message translates to:
  /// **'The network is working perfectly!'**
  String get speedAnalysisPerfect;

  /// No description provided for @speedAnalysisStable.
  ///
  /// In en, this message translates to:
  /// **'Network speed is stable.'**
  String get speedAnalysisStable;

  /// No description provided for @localNetworkDevices.
  ///
  /// In en, this message translates to:
  /// **'Local network devices'**
  String get localNetworkDevices;

  /// No description provided for @activeDevices.
  ///
  /// In en, this message translates to:
  /// **'Active devices'**
  String get activeDevices;

  /// No description provided for @scanningAddresses.
  ///
  /// In en, this message translates to:
  /// **'Scanning {scanned}/{total} addresses'**
  String scanningAddresses(int scanned, int total);

  /// No description provided for @devicesDetected.
  ///
  /// In en, this message translates to:
  /// **'{count} devices detected'**
  String devicesDetected(int count);

  /// No description provided for @rescan.
  ///
  /// In en, this message translates to:
  /// **'Rescan'**
  String get rescan;

  /// No description provided for @noDevicesFound.
  ///
  /// In en, this message translates to:
  /// **'No devices found. Make sure your phone is connected to Wi-Fi and scan again.'**
  String get noDevicesFound;

  /// No description provided for @deviceScanHint.
  ///
  /// In en, this message translates to:
  /// **'Results include devices that respond on common network ports. Devices blocking connections may not appear.'**
  String get deviceScanHint;

  /// No description provided for @thisDevice.
  ///
  /// In en, this message translates to:
  /// **'This device'**
  String get thisDevice;

  /// No description provided for @thisDeviceNamed.
  ///
  /// In en, this message translates to:
  /// **'{name} (This device)'**
  String thisDeviceNamed(String name);

  /// No description provided for @routerLabel.
  ///
  /// In en, this message translates to:
  /// **'Router'**
  String get routerLabel;

  /// No description provided for @networkDevice.
  ///
  /// In en, this message translates to:
  /// **'Network device'**
  String get networkDevice;

  /// No description provided for @macLabel.
  ///
  /// In en, this message translates to:
  /// **'MAC: {mac}'**
  String macLabel(String mac);

  /// No description provided for @portsLabel.
  ///
  /// In en, this message translates to:
  /// **'Ports: {ports}'**
  String portsLabel(String ports);

  /// No description provided for @dataAsOf.
  ///
  /// In en, this message translates to:
  /// **'Data from {time} — couldn\'t refresh'**
  String dataAsOf(String time);

  /// No description provided for @pendingChanges.
  ///
  /// In en, this message translates to:
  /// **'{count} changes waiting to sync — saved on this device'**
  String pendingChanges(int count);

  /// No description provided for @syncingChanges.
  ///
  /// In en, this message translates to:
  /// **'Syncing {count} changes…'**
  String syncingChanges(int count);

  /// No description provided for @changesDiscarded.
  ///
  /// In en, this message translates to:
  /// **'{count} changes could not be synced and were dropped'**
  String changesDiscarded(int count);

  /// No description provided for @refreshFailedNoData.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load data'**
  String get refreshFailedNoData;

  /// No description provided for @lowPriceWarningTitle.
  ///
  /// In en, this message translates to:
  /// **'Double-check the price'**
  String get lowPriceWarningTitle;

  /// No description provided for @lowPriceWarningMessage.
  ///
  /// In en, this message translates to:
  /// **'{price} looks unusually low. Did you miss a zero?'**
  String lowPriceWarningMessage(String price);

  /// No description provided for @badgeNew.
  ///
  /// In en, this message translates to:
  /// **'New'**
  String get badgeNew;

  /// No description provided for @badgeUpdated.
  ///
  /// In en, this message translates to:
  /// **'Edited'**
  String get badgeUpdated;

  /// No description provided for @lowPriceWarningEdit.
  ///
  /// In en, this message translates to:
  /// **'Fix the price'**
  String get lowPriceWarningEdit;

  /// No description provided for @lowPriceWarningSaveAnyway.
  ///
  /// In en, this message translates to:
  /// **'Save anyway'**
  String get lowPriceWarningSaveAnyway;

  /// No description provided for @movie.
  ///
  /// In en, this message translates to:
  /// **'Movies'**
  String get movie;

  /// No description provided for @movieTab.
  ///
  /// In en, this message translates to:
  /// **'Movie Tab'**
  String get movieTab;

  /// No description provided for @movieCountStatus.
  ///
  /// In en, this message translates to:
  /// **'Loaded: {count}/{total}'**
  String movieCountStatus(int count, String total);

  /// No description provided for @searchMoviesPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Search movies, actors…'**
  String get searchMoviesPlaceholder;

  /// No description provided for @noMoviesFound.
  ///
  /// In en, this message translates to:
  /// **'No movies found'**
  String get noMoviesFound;

  /// No description provided for @loadMoviesFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not load movie library.'**
  String get loadMoviesFailed;

  /// No description provided for @invalidMovieServerUrl.
  ///
  /// In en, this message translates to:
  /// **'Invalid Movie Server URL.'**
  String get invalidMovieServerUrl;

  /// No description provided for @movieServerUrlUpdated.
  ///
  /// In en, this message translates to:
  /// **'Movie Server URL updated.'**
  String get movieServerUrlUpdated;

  /// No description provided for @updateMovieServerFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not update movie server.'**
  String get updateMovieServerFailed;

  /// No description provided for @movieServerUrl.
  ///
  /// In en, this message translates to:
  /// **'Movie Server URL'**
  String get movieServerUrl;

  /// No description provided for @addMovieServerUrl.
  ///
  /// In en, this message translates to:
  /// **'Add Movie Server URL'**
  String get addMovieServerUrl;

  /// No description provided for @editMovieServerUrl.
  ///
  /// In en, this message translates to:
  /// **'Edit Movie Server URL'**
  String get editMovieServerUrl;

  /// No description provided for @noServersFound.
  ///
  /// In en, this message translates to:
  /// **'No servers found'**
  String get noServersFound;

  /// No description provided for @serverUrlHint.
  ///
  /// In en, this message translates to:
  /// **'example.com'**
  String get serverUrlHint;

  /// No description provided for @serverUrlHelperText.
  ///
  /// In en, this message translates to:
  /// **'Label and categories will be synced automatically.'**
  String get serverUrlHelperText;

  /// No description provided for @saveAndSync.
  ///
  /// In en, this message translates to:
  /// **'Save & sync'**
  String get saveAndSync;

  /// No description provided for @noWatchedMovies.
  ///
  /// In en, this message translates to:
  /// **'No watched movies yet.'**
  String get noWatchedMovies;

  /// No description provided for @noFavoriteMovies.
  ///
  /// In en, this message translates to:
  /// **'No favorite movies yet.'**
  String get noFavoriteMovies;

  /// No description provided for @watchedMovies.
  ///
  /// In en, this message translates to:
  /// **'Watched movies'**
  String get watchedMovies;

  /// No description provided for @favoriteMovies.
  ///
  /// In en, this message translates to:
  /// **'Favorite movies'**
  String get favoriteMovies;

  /// No description provided for @minimize.
  ///
  /// In en, this message translates to:
  /// **'Minimize'**
  String get minimize;

  /// No description provided for @scrollToTop.
  ///
  /// In en, this message translates to:
  /// **'Scroll to top'**
  String get scrollToTop;

  /// No description provided for @noCategoriesConfigured.
  ///
  /// In en, this message translates to:
  /// **'No categories configured.'**
  String get noCategoriesConfigured;

  /// No description provided for @enterMovieServerUrl.
  ///
  /// In en, this message translates to:
  /// **'Enter Movie Server URL to load categories.'**
  String get enterMovieServerUrl;

  /// No description provided for @syncing.
  ///
  /// In en, this message translates to:
  /// **'Syncing…'**
  String get syncing;

  /// No description provided for @vietsub.
  ///
  /// In en, this message translates to:
  /// **'Vietsub'**
  String get vietsub;

  /// No description provided for @updateFavoriteFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not update favorite.'**
  String get updateFavoriteFailed;

  /// No description provided for @videoStreamError.
  ///
  /// In en, this message translates to:
  /// **'Video stream connection error.'**
  String get videoStreamError;

  /// No description provided for @serverNotResponding.
  ///
  /// In en, this message translates to:
  /// **'Server {index} not responding.'**
  String serverNotResponding(int index);

  /// No description provided for @removeFromFavorites.
  ///
  /// In en, this message translates to:
  /// **'Remove from favorites'**
  String get removeFromFavorites;

  /// No description provided for @addToFavorites.
  ///
  /// In en, this message translates to:
  /// **'Add to favorites'**
  String get addToFavorites;

  /// No description provided for @serverName.
  ///
  /// In en, this message translates to:
  /// **'Server {name}'**
  String serverName(String name);

  /// No description provided for @relatedMovies.
  ///
  /// In en, this message translates to:
  /// **'Related movies'**
  String get relatedMovies;

  /// No description provided for @categoryNew.
  ///
  /// In en, this message translates to:
  /// **'New Updates'**
  String get categoryNew;

  /// No description provided for @categorySingle.
  ///
  /// In en, this message translates to:
  /// **'Feature Films'**
  String get categorySingle;

  /// No description provided for @categorySeries.
  ///
  /// In en, this message translates to:
  /// **'TV Series'**
  String get categorySeries;

  /// No description provided for @categoryAnime.
  ///
  /// In en, this message translates to:
  /// **'Animation'**
  String get categoryAnime;

  /// No description provided for @categoryTVShow.
  ///
  /// In en, this message translates to:
  /// **'TV Shows'**
  String get categoryTVShow;

  /// No description provided for @loadStream.
  ///
  /// In en, this message translates to:
  /// **'Load stream'**
  String get loadStream;

  /// No description provided for @resolutionQuality.
  ///
  /// In en, this message translates to:
  /// **'Resolution quality'**
  String get resolutionQuality;

  /// No description provided for @volume.
  ///
  /// In en, this message translates to:
  /// **'Volume'**
  String get volume;

  /// No description provided for @playbackSpeed.
  ///
  /// In en, this message translates to:
  /// **'Playback speed'**
  String get playbackSpeed;

  /// No description provided for @unlockRotation.
  ///
  /// In en, this message translates to:
  /// **'Unlock rotation'**
  String get unlockRotation;

  /// No description provided for @lockRotation.
  ///
  /// In en, this message translates to:
  /// **'Lock rotation'**
  String get lockRotation;

  /// No description provided for @zoomToFill.
  ///
  /// In en, this message translates to:
  /// **'Fill screen'**
  String get zoomToFill;

  /// No description provided for @zoomToFit.
  ///
  /// In en, this message translates to:
  /// **'Fit screen'**
  String get zoomToFit;

  /// No description provided for @episodeLabel.
  ///
  /// In en, this message translates to:
  /// **'Episodes'**
  String get episodeLabel;

  /// No description provided for @episodeFull.
  ///
  /// In en, this message translates to:
  /// **'Full'**
  String get episodeFull;

  /// No description provided for @episodeDefaultName.
  ///
  /// In en, this message translates to:
  /// **'Episode'**
  String get episodeDefaultName;

  /// No description provided for @unmute.
  ///
  /// In en, this message translates to:
  /// **'Unmute'**
  String get unmute;

  /// No description provided for @mute.
  ///
  /// In en, this message translates to:
  /// **'Mute'**
  String get mute;

  /// No description provided for @previousEpisode.
  ///
  /// In en, this message translates to:
  /// **'Previous episode'**
  String get previousEpisode;

  /// No description provided for @nextEpisode.
  ///
  /// In en, this message translates to:
  /// **'Next episode'**
  String get nextEpisode;

  /// No description provided for @removeFromHistory.
  ///
  /// In en, this message translates to:
  /// **'Remove from history'**
  String get removeFromHistory;

  /// No description provided for @confirmRemoveFromHistory.
  ///
  /// In en, this message translates to:
  /// **'Remove \'{title}\' from your watched history?'**
  String confirmRemoveFromHistory(String title);

  /// No description provided for @directorLabel.
  ///
  /// In en, this message translates to:
  /// **'Director'**
  String get directorLabel;

  /// No description provided for @actorsLabel.
  ///
  /// In en, this message translates to:
  /// **'Cast'**
  String get actorsLabel;

  /// No description provided for @countryLabel.
  ///
  /// In en, this message translates to:
  /// **'Country'**
  String get countryLabel;

  /// No description provided for @genreLabel.
  ///
  /// In en, this message translates to:
  /// **'Genre'**
  String get genreLabel;

  /// No description provided for @accountTitle.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get accountTitle;

  /// No description provided for @accountSectionSecurity.
  ///
  /// In en, this message translates to:
  /// **'Security'**
  String get accountSectionSecurity;

  /// No description provided for @accountSectionDanger.
  ///
  /// In en, this message translates to:
  /// **'Danger zone'**
  String get accountSectionDanger;

  /// No description provided for @accountEmailVerified.
  ///
  /// In en, this message translates to:
  /// **'Email verified'**
  String get accountEmailVerified;

  /// No description provided for @accountEmailUnverified.
  ///
  /// In en, this message translates to:
  /// **'Email not verified'**
  String get accountEmailUnverified;

  /// No description provided for @accountMemberSince.
  ///
  /// In en, this message translates to:
  /// **'Member since'**
  String get accountMemberSince;

  /// No description provided for @accountLastSignIn.
  ///
  /// In en, this message translates to:
  /// **'Last sign-in'**
  String get accountLastSignIn;

  /// No description provided for @resendConfirmationEmail.
  ///
  /// In en, this message translates to:
  /// **'Resend confirmation email'**
  String get resendConfirmationEmail;

  /// No description provided for @confirmationEmailSent.
  ///
  /// In en, this message translates to:
  /// **'Confirmation email sent — check your inbox.'**
  String get confirmationEmailSent;

  /// No description provided for @changePassword.
  ///
  /// In en, this message translates to:
  /// **'Change password'**
  String get changePassword;

  /// No description provided for @changePasswordSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Use a password you don\'t use anywhere else.'**
  String get changePasswordSubtitle;

  /// No description provided for @currentPassword.
  ///
  /// In en, this message translates to:
  /// **'Current password'**
  String get currentPassword;

  /// No description provided for @newPassword.
  ///
  /// In en, this message translates to:
  /// **'New password'**
  String get newPassword;

  /// No description provided for @confirmPassword.
  ///
  /// In en, this message translates to:
  /// **'Confirm password'**
  String get confirmPassword;

  /// No description provided for @passwordTooShort.
  ///
  /// In en, this message translates to:
  /// **'Password must be at least 6 characters.'**
  String get passwordTooShort;

  /// No description provided for @passwordMismatch.
  ///
  /// In en, this message translates to:
  /// **'The two passwords don\'t match.'**
  String get passwordMismatch;

  /// No description provided for @passwordUpdated.
  ///
  /// In en, this message translates to:
  /// **'Your password has been updated.'**
  String get passwordUpdated;

  /// No description provided for @passwordSameAsOld.
  ///
  /// In en, this message translates to:
  /// **'The new password has to differ from the current one.'**
  String get passwordSameAsOld;

  /// No description provided for @updatePassword.
  ///
  /// In en, this message translates to:
  /// **'Update password'**
  String get updatePassword;

  /// No description provided for @setNewPassword.
  ///
  /// In en, this message translates to:
  /// **'Set a new password'**
  String get setNewPassword;

  /// No description provided for @setNewPasswordMessage.
  ///
  /// In en, this message translates to:
  /// **'Choose the new password for your Do X account.'**
  String get setNewPasswordMessage;

  /// No description provided for @deleteAccount.
  ///
  /// In en, this message translates to:
  /// **'Delete account'**
  String get deleteAccount;

  /// No description provided for @deleteAccountSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Permanently remove your account and all of its data.'**
  String get deleteAccountSubtitle;

  /// No description provided for @deleteAccountWarning.
  ///
  /// In en, this message translates to:
  /// **'Your account and every batch, sale, expense and watch record tied to it will be deleted for good. This cannot be undone.'**
  String get deleteAccountWarning;

  /// No description provided for @deleteAccountPasswordPrompt.
  ///
  /// In en, this message translates to:
  /// **'Enter your password to confirm.'**
  String get deleteAccountPasswordPrompt;

  /// No description provided for @accountDeleted.
  ///
  /// In en, this message translates to:
  /// **'Your account has been deleted.'**
  String get accountDeleted;

  /// No description provided for @signUp.
  ///
  /// In en, this message translates to:
  /// **'Sign up'**
  String get signUp;

  /// No description provided for @noAccountSignUp.
  ///
  /// In en, this message translates to:
  /// **'No account yet? Sign up'**
  String get noAccountSignUp;

  /// No description provided for @haveAccountSignIn.
  ///
  /// In en, this message translates to:
  /// **'Already have an account? Sign in'**
  String get haveAccountSignIn;

  /// No description provided for @forgotPassword.
  ///
  /// In en, this message translates to:
  /// **'Forgot password?'**
  String get forgotPassword;

  /// No description provided for @forgotPasswordSent.
  ///
  /// In en, this message translates to:
  /// **'We sent a reset link to {email}.'**
  String forgotPasswordSent(String email);

  /// No description provided for @signUpCheckEmail.
  ///
  /// In en, this message translates to:
  /// **'Almost there — open the link we sent to {email} to activate your account.'**
  String signUpCheckEmail(String email);

  /// No description provided for @emailRequired.
  ///
  /// In en, this message translates to:
  /// **'Please enter your email.'**
  String get emailRequired;

  /// No description provided for @emailInvalid.
  ///
  /// In en, this message translates to:
  /// **'That email address doesn\'t look right.'**
  String get emailInvalid;

  /// No description provided for @authInvalidCredentials.
  ///
  /// In en, this message translates to:
  /// **'Wrong email or password.'**
  String get authInvalidCredentials;

  /// No description provided for @authEmailNotConfirmed.
  ///
  /// In en, this message translates to:
  /// **'This email isn\'t confirmed yet. Open the activation link we sent you.'**
  String get authEmailNotConfirmed;

  /// No description provided for @authUserAlreadyExists.
  ///
  /// In en, this message translates to:
  /// **'That email is already registered — sign in instead.'**
  String get authUserAlreadyExists;

  /// No description provided for @authWeakPassword.
  ///
  /// In en, this message translates to:
  /// **'That password is too weak. Use at least 6 characters.'**
  String get authWeakPassword;

  /// No description provided for @authRateLimited.
  ///
  /// In en, this message translates to:
  /// **'Too many attempts. Try again in a few minutes.'**
  String get authRateLimited;

  /// No description provided for @authUnknownError.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Please try again.'**
  String get authUnknownError;

  /// No description provided for @emailLabel.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get emailLabel;

  /// No description provided for @passwordLabel.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get passwordLabel;

  /// No description provided for @showPassword.
  ///
  /// In en, this message translates to:
  /// **'Show password'**
  String get showPassword;

  /// No description provided for @hidePassword.
  ///
  /// In en, this message translates to:
  /// **'Hide password'**
  String get hidePassword;

  /// No description provided for @verifyCodeTitle.
  ///
  /// In en, this message translates to:
  /// **'Enter your code'**
  String get verifyCodeTitle;

  /// No description provided for @verifyCodeMessage.
  ///
  /// In en, this message translates to:
  /// **'Type the code we emailed to {email}. It expires in an hour.'**
  String verifyCodeMessage(String email);

  /// No description provided for @verifyCodeLabel.
  ///
  /// In en, this message translates to:
  /// **'Verification code'**
  String get verifyCodeLabel;

  /// No description provided for @verifyCodeRequired.
  ///
  /// In en, this message translates to:
  /// **'Please enter the code from the email.'**
  String get verifyCodeRequired;

  /// No description provided for @verifyCodeAction.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get verifyCodeAction;

  /// No description provided for @enterCodeInstead.
  ///
  /// In en, this message translates to:
  /// **'Enter the code from the email'**
  String get enterCodeInstead;

  /// No description provided for @resendCode.
  ///
  /// In en, this message translates to:
  /// **'Send a new code'**
  String get resendCode;

  /// No description provided for @codeSent.
  ///
  /// In en, this message translates to:
  /// **'A new code is on its way.'**
  String get codeSent;

  /// No description provided for @authOtpExpired.
  ///
  /// In en, this message translates to:
  /// **'That code has expired or was already used. Ask for a new one.'**
  String get authOtpExpired;

  /// No description provided for @changeAvatar.
  ///
  /// In en, this message translates to:
  /// **'Change picture'**
  String get changeAvatar;

  /// No description provided for @chooseFromGallery.
  ///
  /// In en, this message translates to:
  /// **'Choose from gallery'**
  String get chooseFromGallery;

  /// No description provided for @takePhoto.
  ///
  /// In en, this message translates to:
  /// **'Take a photo'**
  String get takePhoto;

  /// No description provided for @removeAvatar.
  ///
  /// In en, this message translates to:
  /// **'Remove picture'**
  String get removeAvatar;

  /// No description provided for @avatarUpdated.
  ///
  /// In en, this message translates to:
  /// **'Your picture has been updated.'**
  String get avatarUpdated;

  /// No description provided for @avatarRemoved.
  ///
  /// In en, this message translates to:
  /// **'Your picture has been removed.'**
  String get avatarRemoved;

  /// No description provided for @avatarUploadFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t upload that picture. Please try again.'**
  String get avatarUploadFailed;

  /// Resume video playback from a saved position
  ///
  /// In en, this message translates to:
  /// **'Resume from {time}'**
  String resumePlayback(String time);
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
