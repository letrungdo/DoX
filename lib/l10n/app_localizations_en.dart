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
}
