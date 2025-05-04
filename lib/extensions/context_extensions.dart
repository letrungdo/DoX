import 'package:do_x/constants/app_const.dart';
import 'package:do_x/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

extension ContextExtensions on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);

  ThemeData get theme => Theme.of(this);

  String get loadingId => "${AppConst.loadingIdPrefix}$hashCode";
}
