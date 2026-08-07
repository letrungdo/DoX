class StorageKey {
  StorageKey._();
  // Secure storage keys
  static const accountInfo = "accountInfo";
  static const routerPassword = "routerPassword";
  static const supabaseAccount = "supabaseAccount";
  static const cpcAccounts = "cpcAccounts";

  /// Credentials of every CPC account ever logged in, kept after logout so it
  /// can be picked again without retyping the password.
  static const cpcSavedAccounts = "cpcSavedAccounts";

  // SharedPreferences
  static const themeMode = "themeMode";
  static const tabIndex = "tabIndex";
  static const routerIp = "routerIp";
  static const chickenNotifications = "chickenNotifications";
  static const chickenLunarDisplay = "chickenLunarDisplay";
  static const locale = "locale";
  static const showMyLifeTab = "showMyLifeTab";
  static const showElectricTab = "showElectricTab";
  static const showLunarTab = "showLunarTab";
  static const showMovieTab = "showMovieTab";
  static const movieBaseUrl = "movieBaseUrl";
  static const primaryMovieServer = "primaryMovieServer";
  static const movieServers = "movieServers";
  static const movieServerLabels = "movieServerLabels";
  static const movieCategories = "movieCategories";
  static const movieLabel = "movieLabel";
  static const movieSiteType = "movieSiteType";
  static const tabOrder = "tabOrder";
  static const electricReminder = "electricReminder";

  /// Last known chicken data (batches + global sales/expenses), shown while the
  /// screens refresh from the API.
  static const chickenCache = "chickenCache";

  /// Chicken writes made while offline, waiting to be pushed to the server.
  static const chickenSyncQueue = "chickenSyncQueue";

  /// When chicken records were last added/edited, for the "new"/"edited" badges.
  static const chickenRecentChanges = "chickenRecentChanges";

  // Pending in-background app update (resumable across app restarts).
  static const pendingUpdateVersion = "pendingUpdateVersion";
  static const pendingUpdateUrl = "pendingUpdateUrl";
  static const pendingUpdateNotes = "pendingUpdateNotes";
  static const pendingUpdateDone = "pendingUpdateDone";
}
