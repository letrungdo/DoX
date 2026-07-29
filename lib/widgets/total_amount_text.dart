import 'package:do_x/extensions/context_extensions.dart';
import 'package:do_x/extensions/number_extensions.dart';
import 'package:do_x/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

/// The `Tổng: <amount>đ` line that sits above a money list (chicken batches,
/// cock sales, common expenses). Shared so the three screens keep the same
/// size and colour instead of drifting apart.
///
/// Shrinks rather than overflowing when the figure gets long, so callers give
/// it a bounded width — usually by wrapping it in an [Expanded].
class TotalAmountText extends StatelessWidget {
  const TotalAmountText(this.amount, {super.key, this.color});

  final double amount;

  /// Colour of the figure; defaults to the money accent.
  final Color? color;

  static const fontSize = 17.0;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerRight,
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: "${l10n.totalLabel}: ",
              style: TextStyle(
                color: context.theme.colorScheme.onSurfaceVariant,
              ),
            ),
            TextSpan(
              text: "${amount.toCurrency()}đ",
              style: TextStyle(color: color ?? context.colors.money),
            ),
          ],
        ),
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: fontSize),
      ),
    );
  }
}
