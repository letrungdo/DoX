import 'package:flutter/foundation.dart';

/// Set by a page that needs the whole screen (full-screen video), so the
/// bottom tab bar steps aside while it is on.
///
/// A plain notifier rather than a view model: a page can be a bottom tab or be
/// pushed from the menu, and only the former sits under [MainViewModel]'s
/// provider.
final immersiveMode = ValueNotifier<bool>(false);
