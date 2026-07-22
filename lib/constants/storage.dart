class StorageKey {
  StorageKey._();
  // Secure storage keys
  static const accountInfo = "accountInfo";
  static const routerPassword = "routerPassword";
  static const supabaseAccount = "supabaseAccount";
  static const cpcAccounts = "cpcAccounts";

  // SharedPreferences
  static const themeMode = "themeMode";
  static const tabIndex = "tabIndex";
  static const routerIp = "routerIp";
  static const chickenNotifications = "chickenNotifications";
  static const chickenLunarDisplay = "chickenLunarDisplay";
  static const locale = "locale";
  static const showLocketTab = "showLocketTab";
  static const showElectricTab = "showElectricTab";
  static const showLunarTab = "showLunarTab";
  static const tabOrder = "tabOrder";
  static const electricReminder = "electricReminder";

  // Pending in-background app update (resumable across app restarts).
  static const pendingUpdateVersion = "pendingUpdateVersion";
  static const pendingUpdateUrl = "pendingUpdateUrl";
  static const pendingUpdateNotes = "pendingUpdateNotes";
  static const pendingUpdateDone = "pendingUpdateDone";
}
