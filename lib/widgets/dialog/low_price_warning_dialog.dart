import 'package:do_x/extensions/context_extensions.dart';
import 'package:do_x/extensions/number_extensions.dart';
import 'package:do_x/gen/assets.gen.dart';
import 'package:do_x/l10n/app_localizations.dart';
import 'package:do_x/widgets/cute_dialog.dart';
import 'package:do_x/widgets/dialog/app_modal.dart';
import 'package:flutter/material.dart';

/// Anything under this is almost certainly a typo (a missing zero) rather than
/// a real selling price.
const kSuspiciousPriceThreshold = 10000;

/// Asks the user to confirm a suspiciously low selling price.
///
/// Returns true when the price should be saved as typed, false when the user
/// wants to go back and fix it (also on dismiss, so an accidental tap outside
/// never saves the wrong number).
Future<bool> confirmSuspiciousPrice(
  BuildContext context,
  num price, {
  SvgGenImage? icon,
}) async {
  final l10n = AppLocalizations.of(context);
  // This waits on the user, so the dialog underneath must not sit there
  // spinning as if it were saving.
  final confirmed = await CuteDialog.pauseLoading(
    () => showAppModal<bool>(
      context,
      builder: (context) => CuteDialog(
        icon: icon ?? Assets.images.coinCute,
        title: l10n.lowPriceWarningTitle,
        accent: context.colors.warning,
        cancelText: l10n.lowPriceWarningEdit,
        confirmText: l10n.lowPriceWarningSaveAnyway,
        onConfirm: () => Navigator.pop(context, true),
        children: [
          Text(
            l10n.lowPriceWarningMessage("${price.toCurrency()}đ"),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    ),
  );
  return confirmed ?? false;
}
