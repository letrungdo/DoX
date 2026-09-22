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

  /// The music service token the Music page calls the personal endpoints with.
  static const musicAccount = "musicAccount";

  // SharedPreferences
  static const themeMode = "themeMode";

  /// Pages placed in the bottom bar / in the menu, in user order.
  static const tabPages = "tabPages";
  static const menuPages = "menuPages";

  /// Bottom tab to restore on launch, by page name.
  static const activeTabPage = "activeTabPage";
  static const routerIp = "routerIp";
  static const chickenNotifications = "chickenNotifications";
  static const chickenLunarDisplay = "chickenLunarDisplay";
  static const locale = "locale";

  // Superseded by [tabPages]/[menuPages]; only read to migrate old installs.
  static const tabIndex = "tabIndex";
  static const showMyLifeTab = "showMyLifeTab";
  static const showElectricTab = "showElectricTab";
  static const showLunarTab = "showLunarTab";
  static const tabOrder = "tabOrder";

  static const movieBaseUrl = "movieBaseUrl";
  static const primaryMovieServer = "primaryMovieServer";
  static const movieServers = "movieServers";
  static const movieServerLabels = "movieServerLabels";
  static const movieResolvedServers = "movieResolvedServers";
  static const movieCategories = "movieCategories";
  static const movieLabel = "movieLabel";
  static const movieSiteType = "movieSiteType";

  /// Last downloaded TV playlist (raw M3U), the source it was downloaded for
  /// and when it was stored, so the channel list is on screen before the
  /// network answers. One slot only: a playlist is up to a megabyte, so the
  /// picked country keeps it and every other country is re-fetched.
  static const tvPlaylist = "tvPlaylist";
  static const tvPlaylistSavedAt = "tvPlaylistSavedAt";
  static const tvPlaylistSource = "tvPlaylistSource";

  /// The country the TV page was left on.
  static const tvCountry = "tvCountry";

  /// The iptv-org country catalogue, cached with its date so the picker opens
  /// without waiting for the network.
  static const tvCountries = "tvCountries";
  static const tvCountriesSavedAt = "tvCountriesSavedAt";

  static const electricReminder = "electricReminder";

  /// Market codes shown on the news page, in user order.
  static const marketCodes = "marketCodes";

  /// Last known chicken data (batches + global sales/expenses), shown while the
  /// screens refresh from the API.
  static const chickenCache = "chickenCache";

  /// Chicken writes made while offline, waiting to be pushed to the server.
  static const chickenSyncQueue = "chickenSyncQueue";

  /// Last chicken-data owner selected by the signed-in account.
  static const chickenDataSourceSelection = "chickenDataSourceSelection";

  // Pending in-background app update (resumable across app restarts).
  static const pendingUpdateVersion = "pendingUpdateVersion";
  static const pendingUpdateUrl = "pendingUpdateUrl";
  static const pendingUpdateNotes = "pendingUpdateNotes";
  static const pendingUpdateDone = "pendingUpdateDone";
}
