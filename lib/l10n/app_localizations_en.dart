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
  String get showLocketTab => 'Show Locket Tab';

  @override
  String get language => 'Language';

  @override
  String get vietnamese => 'Vietnamese';

  @override
  String get english => 'English';

  @override
  String get menu => 'Menu';

  @override
  String get news => 'News';

  @override
  String get chicken => 'Chicken';

  @override
  String get locket => 'Locket';

  @override
  String get rebootRouter => 'Wifi Management';

  @override
  String get about => 'About';

  @override
  String get loginDoX => 'Login Do X';

  @override
  String get logoutDoX => 'Logout Do X';

  @override
  String get vaccinationNotifications => 'Vaccination schedule notifications';

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
  String expenseCount(int count) {
    return '$count expenses';
  }

  @override
  String saleCount(int count) {
    return '$count sales';
  }

  @override
  String revenueAmount(String amount) {
    return 'Revenue: $amount';
  }

  @override
  String profitAmount(String amount) {
    return 'Profit: $amount';
  }

  @override
  String totalAmount(String amount) {
    return 'Total: $amount';
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
  String get batchRevenue => 'Batch revenue';

  @override
  String get cockRevenue => 'Fighting rooster revenue';

  @override
  String get meatRevenue => 'Meat chicken revenue';

  @override
  String get profitLabel => 'Profit';
}
