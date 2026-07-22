// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get ok => 'OK';

  @override
  String get cancel => 'Cancel';

  @override
  String get logout => 'Logout';

  @override
  String get login => 'Login';

  @override
  String get close => 'Close';

  @override
  String get retry => 'Retry';

  @override
  String get error => 'Error';

  @override
  String get crop => 'Crop';

  @override
  String get addMessage => 'Add a message';

  @override
  String get writeReview => 'Write a review...';

  @override
  String get pleaseLoginAgain => 'Please log in again!';

  @override
  String get sessionExpired => 'Session expired';

  @override
  String get anErrorOccurred => 'An error occurred.';

  @override
  String get meSystemMaintenance => 'System maintenance!';

  @override
  String get meRequestTimeout => 'Request timeout!';

  @override
  String get meNetworkError => 'Lost connect internet';

  @override
  String get videoTooLargeTitle => 'Video too large';

  @override
  String videoTooLargeMessage(String size) {
    return 'The compressed video is still ${size}MB, over Locket\'s 6MB limit.\n\nReduce quality to 480p, or go back and shorten the video?';
  }

  @override
  String get shortenVideo => 'Shorten it';

  @override
  String get reduceTo480p => 'Reduce to 480p';

  @override
  String get videoStillTooLargeAt480p =>
      'Still over 6MB at 480p — please shorten the video :(';

  @override
  String get settings => 'Settings';

  @override
  String get language => 'Language';

  @override
  String get vietnamese => 'Vietnamese';

  @override
  String get english => 'English';

  @override
  String get menu => 'Menu';

  @override
  String get electricity => 'Electricity';

  @override
  String get electricityTitle => 'Electricity management';

  @override
  String get tabOrder => 'Tab order & visibility';

  @override
  String get electricReminder => 'Monthly electricity reminder';

  @override
  String get electricNotificationTitle => 'Electricity bill time ⚡';

  @override
  String get electricNotificationBody =>
      'Check last month\'s power usage and bill in the app!';

  @override
  String get electricLoginTitle => 'Sign in to CPC customer care';

  @override
  String get username => 'Username';

  @override
  String get password => 'Password';

  @override
  String get customerCode => 'Customer code';

  @override
  String get meterId => 'Meter ID';

  @override
  String get electricUsage => 'Power consumption';

  @override
  String get today => 'Today';

  @override
  String get yesterday => 'Yesterday';

  @override
  String get thisMonth => 'This month';

  @override
  String get lastMonth => 'Last month';

  @override
  String get latestMeterReading => 'Latest reading';

  @override
  String get spiderReadings => 'RF-SPIDER readings';

  @override
  String get dailyUsage => 'Daily consumption';

  @override
  String get seriesThisYear => 'This year';

  @override
  String get seriesLastYear => 'Same period last year';

  @override
  String get addAccount => 'Add account';

  @override
  String removeAccountConfirm(String name) {
    return 'Sign $name out of the app?';
  }

  @override
  String get billingHistory => 'Billing history';

  @override
  String monthLabel(String month, String year) {
    return '$month/$year';
  }

  @override
  String sameMonthLastYear(String value) {
    return 'Same month last year: $value';
  }

  @override
  String get news => 'News';

  @override
  String get chicken => 'Chicken';

  @override
  String get locket => 'Locket';

  @override
  String get lunar => 'Lunar';

  @override
  String get lunarCalendar => 'Lunar calendar';

  @override
  String get lunarToday => 'Today';

  @override
  String get lunarSolarDate => 'Solar';

  @override
  String get lunarLunarDate => 'Lunar';

  @override
  String get lunarLeapMonth => 'leap';

  @override
  String get lunarDayOfWeek => 'Day';

  @override
  String get lunarCanChiDay => 'Day';

  @override
  String get lunarCanChiMonth => 'Month';

  @override
  String get lunarCanChiYear => 'Year';

  @override
  String get lunarCanChiHour => 'Hour';

  @override
  String get lunarGoodDay => 'Auspicious day';

  @override
  String get lunarBadDay => 'Inauspicious day';

  @override
  String get lunarSolarTerm => 'Solar term';

  @override
  String get lunarTide => 'Tide';

  @override
  String get lunarGoodHours => 'Good hours';

  @override
  String get rebootRouter => 'Reboot Router';

  @override
  String get about => 'About';

  @override
  String get loginDoX => 'Login Do X';

  @override
  String get logoutDoX => 'Logout Do X';

  @override
  String get vaccinationNotifications => 'Vaccination schedule notifications';

  @override
  String get editSaleRound => 'Edit sale';

  @override
  String get lunarDatePickerTitle => 'Pick a date (Lunar)';

  @override
  String get lunarShort => 'Lunar';

  @override
  String get solarShort => 'Solar';

  @override
  String get chickenLunarCalendar => 'Lunar calendar (Chicken)';

  @override
  String get chickenLunarCalendarDesc =>
      'Show chicken dates on the lunar calendar';

  @override
  String get notificationPermissionDenied =>
      'Unable to update the notification schedule. Please check notification permission in the device settings.';

  @override
  String vaccinationNotificationTitle(String vaccination) {
    return 'Vaccination: $vaccination';
  }

  @override
  String vaccinationNotificationBody(String batch) {
    return 'Batch $batch is due for vaccination today.';
  }

  @override
  String get confirmLogout => 'Confirm Logout';

  @override
  String get confirmLogoutMessage => 'Are you sure you want to log out?';

  @override
  String get themeMode => 'Theme Mode';

  @override
  String get light => 'Light';

  @override
  String get dark => 'Dark';

  @override
  String get system => 'System';

  @override
  String get wifiManagement => 'Wifi Management';

  @override
  String get fengShuiCompass => 'Feng shui compass';

  @override
  String get fengShuiHouseFacing => 'House facing';

  @override
  String get fengShuiSitting => 'Sitting (back)';

  @override
  String get fengShuiTrigram => 'Trigram';

  @override
  String get fengShuiElement => 'Element';

  @override
  String get fengShuiMountain => 'Mountain';

  @override
  String get fengShuiCalibrateHint =>
      'Move the phone in a figure-8 to calibrate, and keep it away from metal or magnets.';

  @override
  String get fengShuiNoSensor => 'This device has no compass sensor.';

  @override
  String get fengShuiHoldFlat =>
      'Hold the phone flat, top edge pointing toward the house facing.';

  @override
  String get lanSpeed => 'LAN Speed';

  @override
  String get internetSpeed => 'Internet Speed';

  @override
  String get routerIpAddress => 'Router IP Address';

  @override
  String get adminPassword => 'Admin Password';

  @override
  String get rebootRouterXiaomi => 'Reboot Router Xiaomi';

  @override
  String get startSpeedTest => 'Start Speed Test';

  @override
  String get testing => 'Testing...';

  @override
  String speedMbps(String speed) {
    return '$speed Mbps';
  }

  @override
  String get goldPrice => 'Gold Price';

  @override
  String get index => 'Index';

  @override
  String get buy => 'Buy';

  @override
  String get sell => 'Sell';

  @override
  String get chickenManagement => 'Chicken Management';

  @override
  String get sellRoosterMeat => 'Sell rooster / meat';

  @override
  String get profitStatistics => 'Profit statistics';

  @override
  String get commonExpenses => 'Common expenses';

  @override
  String get importData => 'Import data (JSON)';

  @override
  String get noBatchesYet => 'No batches yet. Press + to add.';

  @override
  String get yearPrefix => 'Year';

  @override
  String get yearLabel => 'Year:';

  @override
  String get all => 'All';

  @override
  String saleCount(int count) {
    return '$count sales';
  }

  @override
  String noBatchesInYear(int year) {
    return 'No chicken batches in $year.';
  }

  @override
  String get noCommonExpenses => 'No common expenses yet.';

  @override
  String noCommonExpensesInYear(int year) {
    return 'No common expenses in $year.';
  }

  @override
  String get addFirstExpense => 'Add the first expense';

  @override
  String get addCommonExpense => 'Add common expense';

  @override
  String get editCommonExpense => 'Edit common expense';

  @override
  String get update => 'Update';

  @override
  String get save => 'Save';

  @override
  String get expenseType => 'Expense type';

  @override
  String get amountLabel => 'Amount';

  @override
  String get noteLabel => 'Note';

  @override
  String get expenseDate => 'Expense date';

  @override
  String saveCommonExpenseFailed(String error) {
    return 'Could not save expense: $error';
  }

  @override
  String get delete => 'Delete';

  @override
  String get deleteCommonExpense => 'Delete expense';

  @override
  String confirmDeleteCommonExpense(String date, String amount) {
    return 'Delete the expense dated $date ($amount)?';
  }

  @override
  String deleteCommonExpenseFailed(String error) {
    return 'Could not delete expense: $error';
  }

  @override
  String get expenseFeed => 'Feed';

  @override
  String get expenseMedicine => 'Medicine / vaccine';

  @override
  String get expenseElectricity => 'Heating electricity';

  @override
  String get expenseWater => 'Water';

  @override
  String get expenseOther => 'Other';

  @override
  String newUpdateAvailable(String version) {
    return 'New update available v$version';
  }

  @override
  String get later => 'Later';

  @override
  String get appUpdate => 'App Update';

  @override
  String get downloadingUpdate => 'Downloading update...';

  @override
  String get downloadComplete => 'Download complete, opening installer...';

  @override
  String get preparing => 'Preparing...';

  @override
  String get resumeDownload => 'Resume download';

  @override
  String get downloadErrorGeneric =>
      'Could not download update. Please check your internet connection.';

  @override
  String get downloadErrorTimeout => 'Connection timeout. Please try again.';

  @override
  String get downloadErrorNotFound => 'Update file not found on server.';

  @override
  String downloadingUpdateVersion(String version) {
    return 'Downloading update v$version';
  }

  @override
  String updateReadyToInstall(String version) {
    return 'Update v$version ready';
  }

  @override
  String get install => 'Install';

  @override
  String get add => 'Add';

  @override
  String get confirm => 'Confirm';

  @override
  String get pleaseWait => 'Please wait...';

  @override
  String get deleteAllChickenData => 'Delete all chicken data';

  @override
  String statusWaitingHatch(String date) {
    return 'Hatching - $date';
  }

  @override
  String get statusSoldOut => 'Sold out';

  @override
  String statusDaysOld(int days) {
    return '$days days old';
  }

  @override
  String statusMonthsOld(int months) {
    return '$months months old';
  }

  @override
  String statusMonthsDaysOld(int months, int days) {
    return '${months}mo ${days}d old';
  }

  @override
  String chickenQuantity(int count) {
    return '$count chickens';
  }

  @override
  String soldOfTotal(int sold, int total) {
    return 'Sold $sold/$total';
  }

  @override
  String hatchedOnDate(String date) {
    return 'Hatched $date';
  }

  @override
  String soldOnDate(String date) {
    return 'Sold $date';
  }

  @override
  String get badgeRevenue => 'Revenue';

  @override
  String get badgeExpense => 'Expense';

  @override
  String get badgeProfit => 'Profit';

  @override
  String importedRecords(int count, String file) {
    return 'Imported $count records from $file.';
  }

  @override
  String importFileFailed(String error) {
    return 'Import failed: $error';
  }

  @override
  String get importingData => 'Importing data';

  @override
  String get confirmDeleteAllChickenData => 'Delete all chicken data?';

  @override
  String get deleteData => 'Delete data';

  @override
  String get deleteAllChickenDataWarning =>
      'All batches, revenue and expenses of the current account will be permanently deleted. This action cannot be undone.';

  @override
  String get deletingData => 'Deleting data';

  @override
  String get noDataToDelete => 'No data to delete.';

  @override
  String deletedAllData(int count) {
    return 'Deleted all data ($count main records).';
  }

  @override
  String deleteDataFailed(String error) {
    return 'Delete failed: $error';
  }

  @override
  String get addNewBatch => 'Add new batch';

  @override
  String get batchName => 'Batch name';

  @override
  String get batchNameHint => 'e.g. Flock 31';

  @override
  String batchNamePrefill(int number) {
    return 'Flock $number';
  }

  @override
  String get eggQuantity => 'Number of eggs/chicks';

  @override
  String get incubationDate => 'Incubation date';

  @override
  String get batchDetailTitle => 'Batch details';

  @override
  String get batchNotFound => 'Batch not found.';

  @override
  String get deleteThisBatch => 'Delete this batch';

  @override
  String get initialQuantity => 'Initial quantity';

  @override
  String get soldRemainingLabel => 'Sold / remaining';

  @override
  String soldRemainingValue(int sold, int remaining) {
    return '$sold / $remaining';
  }

  @override
  String get incubationDay => 'Incubation date';

  @override
  String get expectedHatch => 'Expected hatch';

  @override
  String get actualHatchDateLabel => 'Actual hatch date';

  @override
  String get ageLabel => 'Age';

  @override
  String daysCount(int days) {
    return '$days days';
  }

  @override
  String get statusLabel => 'Status';

  @override
  String notHatchedYet(int days) {
    return 'Not hatched ($days days left)';
  }

  @override
  String get vaccinationSchedule => 'Vaccination schedule';

  @override
  String dateValue(String date) {
    return 'Date: $date';
  }

  @override
  String expensesSectionTitle(String amount) {
    return 'Expenses (Total: $amount)';
  }

  @override
  String get noExpensesYet => 'No expenses yet.';

  @override
  String get saleAndProfit => 'Sales & Profit';

  @override
  String get notSoldHint =>
      'Not sold yet. A batch can be sold in multiple rounds.';

  @override
  String get suggestedPrice => 'Suggested price';

  @override
  String pricePerChicken(String amount) {
    return '$amount/chicken';
  }

  @override
  String get chickenSale => 'Chicken sale';

  @override
  String get soldLabel => 'Sold';

  @override
  String soldAndRemaining(int sold, int remaining) {
    return '$sold sold, $remaining remaining';
  }

  @override
  String get totalRevenueLabel => 'Total revenue';

  @override
  String get totalExpensesLabel => 'Total expenses';

  @override
  String get profitUpper => 'PROFIT';

  @override
  String get recordNewSale => 'Record new sale';

  @override
  String get deleteSaleRound => 'Delete sale';

  @override
  String confirmDeleteSaleRound(String date, String amount) {
    return 'Delete the sale on $date ($amount)?';
  }

  @override
  String get addExpense => 'Add expense';

  @override
  String get editExpense => 'Edit expense';

  @override
  String get deleteExpense => 'Delete expense';

  @override
  String confirmDeleteExpense(String label, String amount) {
    return 'Delete the expense $label ($amount)?';
  }

  @override
  String get recordSale => 'Record sale';

  @override
  String get quantityLabel => 'Quantity';

  @override
  String get pricePerUnit => 'Price each';

  @override
  String get totalAutoCalculated => 'Total received (auto)';

  @override
  String get saleNoteHint => 'Note (sold to whom...)';

  @override
  String get saleDate => 'Sale date';

  @override
  String get deleteBatch => 'Delete batch';

  @override
  String confirmDeleteBatch(String name) {
    return 'Are you sure you want to delete batch \'$name\'? This action cannot be undone.';
  }

  @override
  String get editBatchInfo => 'Edit batch info';

  @override
  String get fightingChicken => 'Fighting rooster';

  @override
  String get meatChicken => 'Meat chicken';

  @override
  String get noCockSalesData => 'No sales data yet';

  @override
  String get noMatchingSales => 'No matching sales.';

  @override
  String noSalesInYear(int year) {
    return 'No sales in $year.';
  }

  @override
  String get enterFirstSale => 'Record your first sale';

  @override
  String get editSale => 'Edit sale';

  @override
  String get enterCockSale => 'Record chicken sale';

  @override
  String get soldMeatChickenNote => 'Meat chicken sale';

  @override
  String get soldFightingChickenNote => 'Fighting rooster sale';

  @override
  String saveFailed(String error) {
    return 'Save failed: $error';
  }

  @override
  String get fightingChickenFull => 'Fighting rooster';

  @override
  String get salePrice => 'Sale price';

  @override
  String get cockSaleNoteHint => 'Note (which chicken, condition...)';

  @override
  String get deleteSaleRecord => 'Delete sale';

  @override
  String confirmDeleteSaleRecord(String date, String amount) {
    return 'Delete the sale on $date ($amount)?';
  }

  @override
  String deleteFailed(String error) {
    return 'Delete failed: $error';
  }

  @override
  String get byMonth => 'Monthly';

  @override
  String get byYear => 'Yearly';

  @override
  String noDataInYear(int year) {
    return 'No data in $year.';
  }

  @override
  String get monthPrefix => 'Month';

  @override
  String get noStatsData => 'No statistics yet.';

  @override
  String get batchRevenue => 'Chick revenue';

  @override
  String get cockRevenue => 'Fighting rooster revenue';

  @override
  String get meatRevenue => 'Meat chicken revenue';

  @override
  String get profitLabel => 'Profit';

  @override
  String get errorEnterAmount => 'Please enter an amount';

  @override
  String get errorEnterQuantity => 'Please enter a quantity';

  @override
  String errorQuantityExceedsRemaining(int remaining) {
    return 'Only $remaining chickens left to sell';
  }

  @override
  String get errorEnterBatchName => 'Please enter a batch name';

  @override
  String get revenue => 'Revenue';

  @override
  String get totalLabel => 'Total';

  @override
  String get sellGrownChicken => 'Sell grown chickens';

  @override
  String get tabReboot => 'Reboot';

  @override
  String get tabDevices => 'Devices';

  @override
  String get tabSpeed => 'Speed';

  @override
  String get processing => 'Processing...';

  @override
  String get rebootSuccessStartSpeedTest =>
      'Reboot successful, starting speed test';

  @override
  String get connectionSpeedTest => 'Check connection speed';

  @override
  String get selectInternetServer => 'Select internet test server';

  @override
  String get serverLabel => 'Server';

  @override
  String ttfbMs(int ms) {
    return 'TTFB: ${ms}ms';
  }

  @override
  String get stopLabel => 'STOP';

  @override
  String get stopSpeedTest => 'Stop';

  @override
  String get deviceConfig => 'Device configuration';

  @override
  String get adminPasswordHelper =>
      'Login password for the router admin page (MiWiFi)';

  @override
  String get progressTitle => 'Progress:';

  @override
  String routerNoResponse(int seconds) {
    return 'Still no response from the router (${seconds}s)...';
  }

  @override
  String get reconnectingEstimate => 'Reconnecting... (Estimated ~90 seconds)';

  @override
  String get skipWaiting => 'Skip waiting';

  @override
  String get skipWaitingNote =>
      'Note: If the router changed IP or the light turned green, you can skip this step.';

  @override
  String get errorLabel => 'Error!';

  @override
  String get successLabel => 'Success!';

  @override
  String get consoleLog => 'Detailed log (Console Log)';

  @override
  String get speedAnalysisLanWeak =>
      'LAN connection is very weak. Check the network cable or the distance to the repeater.';

  @override
  String get speedAnalysisInternetSlow =>
      'LAN connection is good, but the Internet is slow. The issue may be from the ISP or the main router.';

  @override
  String get speedAnalysisPerfect => 'The network is working perfectly!';

  @override
  String get speedAnalysisStable => 'Network speed is stable.';

  @override
  String get localNetworkDevices => 'Local network devices';

  @override
  String get activeDevices => 'Active devices';

  @override
  String scanningAddresses(int scanned, int total) {
    return 'Scanning $scanned/$total addresses';
  }

  @override
  String devicesDetected(int count) {
    return '$count devices detected';
  }

  @override
  String get rescan => 'Rescan';

  @override
  String get noDevicesFound =>
      'No devices found. Make sure your phone is connected to Wi-Fi and scan again.';

  @override
  String get deviceScanHint =>
      'Results include devices that respond on common network ports. Devices blocking connections may not appear.';

  @override
  String get thisDevice => 'This device';

  @override
  String thisDeviceNamed(String name) {
    return '$name (This device)';
  }

  @override
  String get routerLabel => 'Router';

  @override
  String get networkDevice => 'Network device';

  @override
  String macLabel(String mac) {
    return 'MAC: $mac';
  }

  @override
  String portsLabel(String ports) {
    return 'Ports: $ports';
  }
}
