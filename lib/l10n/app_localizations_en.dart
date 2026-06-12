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
}
