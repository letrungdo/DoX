// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Vietnamese (`vi`).
class AppLocalizationsVi extends AppLocalizations {
  AppLocalizationsVi([String locale = 'vi']) : super(locale);

  @override
  String get ok => 'OK';

  @override
  String get cancel => 'Hủy';

  @override
  String get logout => 'Đăng xuất';

  @override
  String get login => 'Đăng nhập';

  @override
  String get close => 'Đóng';

  @override
  String get priceOpen => 'Mở cửa';

  @override
  String get priceHigh => 'Cao nhất';

  @override
  String get priceLow => 'Thấp nhất';

  @override
  String get priceClose => 'Đóng cửa';

  @override
  String get high52Week => 'Đỉnh 52T';

  @override
  String get low52Week => 'Đáy 52T';

  @override
  String get retry => 'Thử lại';

  @override
  String get error => 'Lỗi';

  @override
  String get crop => 'Cắt';

  @override
  String get addMessage => 'Thêm tin nhắn';

  @override
  String get writeReview => 'Viết nhận xét...';

  @override
  String get pleaseLoginAgain => 'Vui lòng đăng nhập lại!';

  @override
  String get sessionExpired => 'Hết phiên làm việc';

  @override
  String get anErrorOccurred => 'Đã có lỗi xảy ra.';

  @override
  String get meSystemMaintenance => 'Hệ thống đang bảo trì!';

  @override
  String get meRequestTimeout => 'Yêu cầu hết thời gian!';

  @override
  String get meNetworkError => 'Mất kết nối internet';

  @override
  String get videoTooLargeTitle => 'Video quá lớn';

  @override
  String videoTooLargeMessage(String size) {
    return 'Video sau khi nén vẫn còn ${size}MB, vượt giới hạn 6MB của MyLife.\n\nGiảm chất lượng xuống 480p, hoặc quay lại cắt ngắn video?';
  }

  @override
  String get shortenVideo => 'Cắt ngắn';

  @override
  String get reduceTo480p => 'Giảm xuống 480p';

  @override
  String get videoStillTooLargeAt480p =>
      'Vẫn trên 6MB ở 480p — vui lòng cắt ngắn video :(';

  @override
  String get settings => 'Cài đặt';

  @override
  String get language => 'Ngôn ngữ';

  @override
  String get vietnamese => 'Tiếng Việt';

  @override
  String get english => 'Tiếng Anh';

  @override
  String get menu => 'Menu';

  @override
  String get electricity => 'Điện';

  @override
  String get electricityTitle => 'Quản lý điện';

  @override
  String get pageLayout => 'Tab & menu';

  @override
  String get menuTabAlwaysPinned => 'Tab Menu luôn được hiển thị.';

  @override
  String get bottomTabs => 'Tab dưới màn hình';

  @override
  String get moveToMenu => 'Chuyển vào menu';

  @override
  String get moveToBottomTabs => 'Chuyển ra tab dưới';

  @override
  String get noPagesHere => 'Chưa có mục nào.';

  @override
  String maxTabsReached(int count) {
    return 'Thanh tab dưới chỉ chứa tối đa $count trang.';
  }

  @override
  String get electricReminder => 'Thông báo tiền điện hàng tháng';

  @override
  String get electricNotificationTitle => 'Đến kỳ chốt tiền điện ⚡';

  @override
  String get electricNotificationBody =>
      'Xem điện năng tiêu thụ và tiền điện tháng vừa rồi trong app nhé!';

  @override
  String get electricLoginTitle => 'Đăng nhập CSKH Điện lực (CPC)';

  @override
  String get username => 'Tên đăng nhập';

  @override
  String get password => 'Mật khẩu';

  @override
  String get customerCode => 'Mã khách hàng';

  @override
  String get meterId => 'Mã công tơ';

  @override
  String get electricUsage => 'Điện năng tiêu thụ';

  @override
  String get today => 'Hôm nay';

  @override
  String get yesterday => 'Hôm qua';

  @override
  String get thisMonth => 'Tháng này';

  @override
  String get lastMonth => 'Tháng trước';

  @override
  String get latestMeterReading => 'Chỉ số mới nhất';

  @override
  String get spiderReadings => 'Đo xa RF-SPIDER';

  @override
  String get dailyUsage => 'Tiêu thụ theo ngày';

  @override
  String get seriesThisYear => 'Năm nay';

  @override
  String get seriesLastYear => 'Cùng kỳ năm trước';

  @override
  String get addAccount => 'Thêm tài khoản';

  @override
  String get savedAccounts => 'Tài khoản đã lưu';

  @override
  String forgetAccountConfirm(String name) {
    return 'Xóa tài khoản $name đã lưu? Lần sau sẽ phải nhập lại mật khẩu.';
  }

  @override
  String removeAccountConfirm(String name) {
    return 'Đăng xuất tài khoản $name khỏi ứng dụng?';
  }

  @override
  String get billingHistory => 'Lịch sử tiền điện';

  @override
  String monthLabel(String month, String year) {
    return 'Tháng $month/$year';
  }

  @override
  String sameMonthLastYear(String value) {
    return 'Cùng kỳ năm trước: $value';
  }

  @override
  String get mergedTab => 'Tổng';

  @override
  String get mergedTabSubtitle => 'Đồng hồ cùng tên';

  @override
  String get mergedSavingsTitle => 'Tiết kiệm nhờ tách đồng hồ';

  @override
  String get mergedSavingsTotal => 'Tổng tiết kiệm';

  @override
  String get mergedSingleMeterCost => 'Nếu chỉ 1 đồng hồ sinh hoạt';

  @override
  String get mergedActualCost => 'Thực tế đã trả';

  @override
  String get mergedAveragePerMonth => 'Trung bình mỗi tháng';

  @override
  String mergedMonthsCounted(String count) {
    return '$count tháng có cả 2 đồng hồ';
  }

  @override
  String mergedMeters(String count) {
    return 'Gộp $count đồng hồ cùng tên khách hàng';
  }

  @override
  String get mergedMonthlyTitle => 'Tiền điện gộp theo tháng';

  @override
  String get mergedSavingsLabel => 'Tiết kiệm';

  @override
  String mergedSplitLabel(String residential, String other) {
    return 'Sinh hoạt $residential · Ngoài sinh hoạt $other';
  }

  @override
  String get mergedNeedsBothMeters =>
      'Cần đăng nhập cả tài khoản điện sinh hoạt và ngoài sinh hoạt để so sánh được.';

  @override
  String get mergedNoOverlap =>
      'Chưa có tháng nào có hóa đơn của cả 2 đồng hồ.';

  @override
  String get mergedNoGroups =>
      'Không có khách hàng nào đứng tên từ 2 đồng hồ trở lên. Tab này chỉ gộp các đồng hồ cùng tên khách hàng.';

  @override
  String get mergedEstimateNote =>
      'Ước tính theo giá bán lẻ điện sinh hoạt bậc thang (1 định mức), hiệu chỉnh theo hóa đơn sinh hoạt thực tế của chính tháng đó.';

  @override
  String get news => 'Tin tức';

  @override
  String get chicken => 'Gà';

  @override
  String get myLife => 'MyLife';

  @override
  String get lunar => 'Âm lịch';

  @override
  String get lunarTab => 'Lịch';

  @override
  String get lunarCalendar => 'Lịch âm';

  @override
  String get lunarToday => 'Hôm nay';

  @override
  String get lunarSolarDate => 'Dương lịch';

  @override
  String get lunarLunarDate => 'Âm lịch';

  @override
  String get lunarLeapMonth => 'nhuận';

  @override
  String get lunarDayOfWeek => 'Thứ';

  @override
  String get lunarCanChiDay => 'Ngày';

  @override
  String get lunarCanChiMonth => 'Tháng';

  @override
  String get lunarCanChiYear => 'Năm';

  @override
  String get lunarCanChiHour => 'Giờ';

  @override
  String get lunarGoodDay => 'Ngày hoàng đạo';

  @override
  String get lunarBadDay => 'Ngày hắc đạo';

  @override
  String get lunarSolarTerm => 'Tiết khí';

  @override
  String get lunarTide => 'Con nước';

  @override
  String get lunarGoodHours => 'Giờ tốt';

  @override
  String get rebootRouter => 'Khởi động lại router';

  @override
  String get about => 'Giới thiệu';

  @override
  String get loginDoX => 'Đăng nhập Do X';

  @override
  String get logoutDoX => 'Đăng xuất Do X';

  @override
  String get vaccinationNotifications => 'Thông báo lịch tiêm phòng';

  @override
  String get editSaleRound => 'Sửa đợt bán';

  @override
  String get lunarDatePickerTitle => 'Chọn ngày (Âm lịch)';

  @override
  String get lunarShort => 'ÂL';

  @override
  String get solarShort => 'DL';

  @override
  String get chickenLunarCalendar => 'Lịch âm (mục Gà)';

  @override
  String get chickenLunarCalendarDesc => 'Hiển thị ngày ở mục Gà theo lịch âm';

  @override
  String get notificationPermissionDenied =>
      'Không thể cập nhật lịch thông báo. Vui lòng kiểm tra quyền thông báo trong cài đặt thiết bị.';

  @override
  String vaccinationNotificationTitle(String vaccination) {
    return 'Lịch tiêm: $vaccination';
  }

  @override
  String vaccinationNotificationBody(String batch) {
    return 'Lứa $batch đến lịch tiêm phòng hôm nay.';
  }

  @override
  String get confirmLogout => 'Đăng xuất';

  @override
  String get confirmLogoutMessage => 'Bạn có chắc muốn đăng xuất không?';

  @override
  String get themeMode => 'Giao diện';

  @override
  String get light => 'Sáng';

  @override
  String get dark => 'Tối';

  @override
  String get system => 'Hệ thống';

  @override
  String get wifiManagement => 'Quản lý Wifi';

  @override
  String get wifiShort => 'Wifi';

  @override
  String get fengShuiCompass => 'La bàn phong thủy';

  @override
  String get compass => 'La bàn';

  @override
  String get fengShuiHouseFacing => 'Hướng nhà';

  @override
  String get fengShuiSitting => 'Tọa (lưng nhà)';

  @override
  String get fengShuiTrigram => 'Quái';

  @override
  String get fengShuiElement => 'Ngũ hành';

  @override
  String get fengShuiMountain => 'Sơn hướng';

  @override
  String get fengShuiCalibrateHint =>
      'Lắc điện thoại theo hình số 8 để hiệu chỉnh, tránh xa kim loại và nam châm.';

  @override
  String get fengShuiNoSensor => 'Thiết bị không có cảm biến la bàn.';

  @override
  String get fengShuiHoldFlat =>
      'Đặt điện thoại nằm ngang, cạnh trên hướng về mặt tiền nhà.';

  @override
  String get lanSpeed => 'Tốc độ LAN';

  @override
  String get internetSpeed => 'Tốc độ Internet';

  @override
  String get routerIpAddress => 'Địa chỉ IP Router';

  @override
  String get adminPassword => 'Mật khẩu Admin';

  @override
  String get rebootRouterXiaomi => 'Khởi động lại Router Xiaomi';

  @override
  String get startSpeedTest => 'Đo tốc độ';

  @override
  String get testing => 'Đang đo...';

  @override
  String speedMbps(String speed) {
    return '$speed Mbps';
  }

  @override
  String get goldPrice => 'Giá vàng';

  @override
  String get exchangeRate => 'Tỷ giá';

  @override
  String get market => 'Thị trường';

  @override
  String get goldNews => 'Tin ảnh hưởng giá vàng';

  @override
  String get goldNewsEmpty => 'Chưa có bản tin cho hôm nay.';

  @override
  String get goldNewsSources => 'Nguồn tham khảo';

  @override
  String goldNewsUpdatedAt(String time) {
    return 'Tổng hợp $time';
  }

  @override
  String get trendUp => 'Xu hướng tăng';

  @override
  String get trendDown => 'Xu hướng giảm';

  @override
  String get trendNeutral => 'Đi ngang';

  @override
  String get index => 'Chỉ số';

  @override
  String get buy => 'Mua vào';

  @override
  String get sell => 'Bán ra';

  @override
  String get chickenManagement => 'Quản lý gà';

  @override
  String get chickenSharing => 'Chia sẻ dữ liệu gà';

  @override
  String get chickenSharingDescription =>
      'Người được thêm có thể xem toàn bộ dữ liệu gà nhưng không thể thêm, sửa hoặc xóa.';

  @override
  String get shareWithEmail => 'Chia sẻ với email';

  @override
  String get shareAction => 'Chia sẻ';

  @override
  String get sharedWith => 'Người đang có quyền xem';

  @override
  String get notSharedYet => 'Chưa chia sẻ với ai.';

  @override
  String get shareAccessAdded => 'Đã cấp quyền chỉ xem.';

  @override
  String shareAccessFailed(String error) {
    return 'Không thể chia sẻ: $error';
  }

  @override
  String get revokeAccess => 'Thu hồi quyền';

  @override
  String get viewChickenDataFrom => 'Xem dữ liệu gà của';

  @override
  String get myChickenData => 'Dữ liệu của tôi';

  @override
  String sharedReadOnly(String email) {
    return 'Đang xem của $email · Chỉ xem';
  }

  @override
  String get readOnly => 'Chỉ xem';

  @override
  String get sellRoosterMeat => 'Bán gà đá / gà thịt';

  @override
  String get profitStatistics => 'Thống kê lợi nhuận';

  @override
  String get commonExpenses => 'Chi phí chung';

  @override
  String get importData => 'Nhập dữ liệu (JSON)';

  @override
  String get noBatchesYet => 'Chưa có lứa gà nào. Nhấn + để thêm.';

  @override
  String get yearPrefix => 'Năm';

  @override
  String get yearLabel => 'Năm';

  @override
  String get selectYear => 'Chọn năm';

  @override
  String get all => 'Tất cả';

  @override
  String saleCount(int count) {
    return '$count lượt bán';
  }

  @override
  String noBatchesInYear(int year) {
    return 'Không có lứa gà trong năm $year.';
  }

  @override
  String get noCommonExpenses => 'Chưa có chi phí chung nào.';

  @override
  String noCommonExpensesInYear(int year) {
    return 'Không có chi phí chung trong năm $year.';
  }

  @override
  String get addFirstExpense => 'Thêm chi phí đầu tiên';

  @override
  String get addCommonExpense => 'Thêm chi phí chung';

  @override
  String get editCommonExpense => 'Chỉnh sửa chi phí chung';

  @override
  String get update => 'Cập nhật';

  @override
  String get save => 'Lưu';

  @override
  String get expenseType => 'Loại chi phí';

  @override
  String get amountLabel => 'Số tiền';

  @override
  String get noteLabel => 'Ghi chú';

  @override
  String get expenseDate => 'Ngày chi';

  @override
  String saveCommonExpenseFailed(String error) {
    return 'Lưu chi phí thất bại: $error';
  }

  @override
  String get delete => 'Xóa';

  @override
  String get deleteCommonExpense => 'Xóa khoản chi';

  @override
  String confirmDeleteCommonExpense(String date, String amount) {
    return 'Xóa khoản chi ngày $date ($amount)?';
  }

  @override
  String deleteCommonExpenseFailed(String error) {
    return 'Xóa chi phí thất bại: $error';
  }

  @override
  String get expenseFeed => 'Cám / thức ăn';

  @override
  String get expenseMedicine => 'Thuốc / vắc xin';

  @override
  String get expenseElectricity => 'Điện sưởi';

  @override
  String get expenseWater => 'Nước';

  @override
  String get expenseOther => 'Khác';

  @override
  String newUpdateAvailable(String version) {
    return 'Có bản cập nhật mới v$version';
  }

  @override
  String get later => 'Để sau';

  @override
  String get appUpdate => 'Cập nhật ứng dụng';

  @override
  String get downloadingUpdate => 'Đang tải bản cập nhật...';

  @override
  String get downloadComplete => 'Tải hoàn tất, đang mở trình cài đặt...';

  @override
  String get preparing => 'Đang chuẩn bị...';

  @override
  String get resumeDownload => 'Tiếp tục tải';

  @override
  String get downloadErrorGeneric =>
      'Không thể tải bản cập nhật. Vui lòng kiểm tra kết nối mạng.';

  @override
  String get downloadErrorTimeout => 'Kết nối quá hạn. Vui lòng thử lại.';

  @override
  String get downloadErrorNotFound =>
      'Không tìm thấy file cập nhật trên máy chủ.';

  @override
  String downloadingUpdateVersion(String version) {
    return 'Đang tải bản cập nhật v$version';
  }

  @override
  String updateReadyToInstall(String version) {
    return 'Đã tải xong bản v$version';
  }

  @override
  String get install => 'Cài đặt';

  @override
  String get add => 'Thêm';

  @override
  String get confirm => 'Xác nhận';

  @override
  String get pleaseWait => 'Vui lòng chờ...';

  @override
  String get deleteAllChickenData => 'Xóa toàn bộ dữ liệu gà';

  @override
  String statusWaitingHatch(String date) {
    return 'Chờ nở - $date';
  }

  @override
  String get statusSoldOut => 'Đã bán hết';

  @override
  String statusDaysOld(int days) {
    return '$days ngày tuổi';
  }

  @override
  String statusMonthsOld(int months) {
    return '$months tháng tuổi';
  }

  @override
  String statusMonthsDaysOld(int months, int days) {
    return '$months tháng $days ngày tuổi';
  }

  @override
  String chickenQuantity(int count) {
    return '$count con';
  }

  @override
  String soldOfTotal(int sold, int total) {
    return 'Đã bán $sold/$total con';
  }

  @override
  String hatchedOnDate(String date) {
    return 'Nở $date';
  }

  @override
  String soldOnDate(String date) {
    return 'Bán $date';
  }

  @override
  String get badgeRevenue => 'Thu';

  @override
  String get badgeExpense => 'Chi';

  @override
  String get badgeProfit => 'Lãi';

  @override
  String importedRecords(int count, String file) {
    return 'Đã nhập $count bản ghi từ $file.';
  }

  @override
  String importFileFailed(String error) {
    return 'Nhập file thất bại: $error';
  }

  @override
  String get importingData => 'Đang import dữ liệu';

  @override
  String get confirmDeleteAllChickenData => 'Xóa toàn bộ dữ liệu gà?';

  @override
  String get deleteData => 'Xóa dữ liệu';

  @override
  String get deleteAllChickenDataWarning =>
      'Tất cả lứa gà, doanh thu và chi phí của tài khoản hiện tại sẽ bị xóa vĩnh viễn. Thao tác này không thể hoàn tác.';

  @override
  String get deletingData => 'Đang xóa dữ liệu';

  @override
  String get noDataToDelete => 'Không có dữ liệu để xóa.';

  @override
  String deletedAllData(int count) {
    return 'Đã xóa toàn bộ dữ liệu ($count bản ghi chính).';
  }

  @override
  String deleteDataFailed(String error) {
    return 'Xóa dữ liệu thất bại: $error';
  }

  @override
  String get addNewBatch => 'Thêm lứa gà mới';

  @override
  String get batchName => 'Tên lứa gà';

  @override
  String get batchNameHint => 'VD: Bầy 31';

  @override
  String batchNamePrefill(int number) {
    return 'Bầy $number';
  }

  @override
  String get eggQuantity => 'Số lượng trứng/con';

  @override
  String get incubationDate => 'Ngày ấp trứng';

  @override
  String get batchDetailTitle => 'Chi tiết lứa gà';

  @override
  String get batchNotFound => 'Không tìm thấy thông tin lứa gà.';

  @override
  String get deleteThisBatch => 'Xóa lứa gà này';

  @override
  String get initialQuantity => 'Số lượng';

  @override
  String get soldRemainingLabel => 'Đã bán / còn lại';

  @override
  String get remainingLabel => 'Còn lại';

  @override
  String soldRemainingValue(int sold, int remaining) {
    return '$sold / $remaining con';
  }

  @override
  String get incubationDay => 'Ngày ấp';

  @override
  String get expectedHatch => 'Dự kiến nở';

  @override
  String get actualHatchDateLabel => 'Ngày nở thực tế';

  @override
  String get ageLabel => 'Tuổi';

  @override
  String daysCount(int days) {
    return '$days ngày';
  }

  @override
  String get statusLabel => 'Trạng thái';

  @override
  String notHatchedYet(int days) {
    return 'Chưa nở (còn $days ngày)';
  }

  @override
  String get vaccinationSchedule => 'Lịch tiêm phòng';

  @override
  String dateValue(String date) {
    return 'Ngày: $date';
  }

  @override
  String expensesSectionTitle(String amount) {
    return 'Chi phí (Tổng: $amount)';
  }

  @override
  String get expensesTitle => 'Chi phí';

  @override
  String get noExpensesYet => 'Chưa có chi phí nào.';

  @override
  String get saleAndProfit => 'Bán gà & Lợi nhuận';

  @override
  String get notSoldHint => 'Gà chưa bán. Có thể bán một lứa thành nhiều đợt.';

  @override
  String get suggestedPrice => 'Giá gợi ý';

  @override
  String pricePerChicken(String amount) {
    return '$amount/con';
  }

  @override
  String get chickenSale => 'Bán gà';

  @override
  String get soldLabel => 'Đã bán';

  @override
  String soldAndRemaining(int sold, int remaining) {
    return '$sold con, còn $remaining con';
  }

  @override
  String get totalRevenueLabel => 'Tổng doanh thu';

  @override
  String get totalExpensesLabel => 'Tổng chi phí';

  @override
  String get profitUpper => 'LỢI NHUẬN';

  @override
  String get recordNewSale => 'Ghi nhận đợt bán mới';

  @override
  String get deleteSaleRound => 'Xóa đợt bán';

  @override
  String confirmDeleteSaleRound(String date, String amount) {
    return 'Xóa đợt bán ngày $date ($amount)?';
  }

  @override
  String get addExpense => 'Thêm chi phí';

  @override
  String get editExpense => 'Sửa chi phí';

  @override
  String get deleteExpense => 'Xóa chi phí';

  @override
  String confirmDeleteExpense(String label, String amount) {
    return 'Xóa chi phí $label ($amount)?';
  }

  @override
  String get recordSale => 'Ghi nhận đợt bán';

  @override
  String get quantityLabel => 'Số lượng';

  @override
  String get pricePerUnit => 'Giá 1 con';

  @override
  String get totalAutoCalculated => 'Tổng tiền thu được (tự tính)';

  @override
  String priceSuggestion(String price) {
    return 'Gợi ý $price/con';
  }

  @override
  String priceSuggestionBasis(int count, int age) {
    return 'Từ $count đợt bán quanh $age ngày tuổi';
  }

  @override
  String priceSuggestionBasisAll(int count, String min, String max) {
    return 'Từ $count đợt bán trước đó ($min - $max)';
  }

  @override
  String get saleNoteHint => 'Ghi chú (bán cho ai...)';

  @override
  String get saleDate => 'Ngày bán';

  @override
  String get deleteBatch => 'Xóa lứa gà';

  @override
  String confirmDeleteBatch(String name) {
    return 'Bạn có chắc chắn muốn xóa lứa \'$name\'? Hành động này không thể hoàn tác.';
  }

  @override
  String get editBatchInfo => 'Sửa thông tin lứa gà';

  @override
  String get fightingChicken => 'Gà đá';

  @override
  String get meatChicken => 'Gà thịt';

  @override
  String get noCockSalesData => 'Chưa có dữ liệu bán gà';

  @override
  String get noMatchingSales => 'Không có lượt bán phù hợp.';

  @override
  String noSalesInYear(int year) {
    return 'Không có lượt bán trong năm $year.';
  }

  @override
  String get enterFirstSale => 'Nhập bán con đầu tiên';

  @override
  String get editSale => 'Chỉnh sửa lượt bán';

  @override
  String get enterCockSale => 'Nhập bán gà';

  @override
  String get soldMeatChickenNote => 'Bán gà thịt';

  @override
  String get soldFightingChickenNote => 'Bán gà đá';

  @override
  String saveFailed(String error) {
    return 'Lưu thất bại: $error';
  }

  @override
  String get fightingChickenFull => 'Gà đá / gà nòi';

  @override
  String get salePrice => 'Giá bán';

  @override
  String get cockSaleNoteHint => 'Ghi chú (con gà số mấy, trạng gà...)';

  @override
  String get deleteSaleRecord => 'Xóa lượt bán';

  @override
  String confirmDeleteSaleRecord(String date, String amount) {
    return 'Xóa lượt bán ngày $date ($amount)?';
  }

  @override
  String deleteFailed(String error) {
    return 'Xóa thất bại: $error';
  }

  @override
  String get byMonth => 'Theo tháng';

  @override
  String get byYear => 'Theo năm';

  @override
  String noDataInYear(int year) {
    return 'Không có dữ liệu trong năm $year.';
  }

  @override
  String get monthPrefix => 'Tháng';

  @override
  String get noStatsData => 'Chưa có dữ liệu thống kê.';

  @override
  String get batchRevenue => 'Doanh thu gà con';

  @override
  String get cockRevenue => 'Doanh thu gà đá';

  @override
  String get meatRevenue => 'Doanh thu gà thịt';

  @override
  String get profitLabel => 'Lợi nhuận';

  @override
  String get profitMargin => 'Tỷ suất lợi nhuận';

  @override
  String get revenueVsExpense => 'Doanh thu & chi phí';

  @override
  String get revenueBreakdown => 'Cấu phần doanh thu';

  @override
  String get monthlyDetails => 'Chi tiết theo tháng';

  @override
  String get yearlyDetails => 'Chi tiết theo năm';

  @override
  String get averagePerMonth => 'TB / tháng';

  @override
  String get averagePerYear => 'TB / năm';

  @override
  String get bestMonth => 'Tháng cao nhất';

  @override
  String get bestYear => 'Năm cao nhất';

  @override
  String get allYearsLabel => 'Tất cả các năm';

  @override
  String monthShort(int month) {
    return 'T$month';
  }

  @override
  String activeMonths(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count tháng có dữ liệu',
    );
    return '$_temp0';
  }

  @override
  String activeYears(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count năm có dữ liệu',
    );
    return '$_temp0';
  }

  @override
  String get errorEnterAmount => 'Vui lòng nhập số tiền';

  @override
  String get errorEnterQuantity => 'Vui lòng nhập số lượng';

  @override
  String errorQuantityExceedsRemaining(int remaining) {
    return 'Chỉ còn $remaining con để bán';
  }

  @override
  String get errorEnterBatchName => 'Vui lòng nhập tên lứa gà';

  @override
  String get revenue => 'Doanh thu';

  @override
  String get totalLabel => 'Tổng';

  @override
  String get sellGrownChicken => 'Bán gà lớn';

  @override
  String get tabReboot => 'Khởi động lại';

  @override
  String get tabDevices => 'Thiết bị';

  @override
  String get tabSpeed => 'Tốc độ';

  @override
  String get processing => 'Đang xử lý...';

  @override
  String get rebootSuccessStartSpeedTest =>
      'Khởi động lại thành công, bắt đầu kiểm tra tốc độ';

  @override
  String get connectionSpeedTest => 'Kiểm tra tốc độ kết nối';

  @override
  String get selectInternetServer => 'Chọn máy chủ đo internet';

  @override
  String get serverLabel => 'Máy chủ';

  @override
  String ttfbMs(int ms) {
    return 'TTFB: ${ms}ms';
  }

  @override
  String get stopLabel => 'STOP';

  @override
  String get stopSpeedTest => 'Dừng đo';

  @override
  String get deviceConfig => 'Cấu hình thiết bị';

  @override
  String get adminPasswordHelper =>
      'Mật khẩu đăng nhập trang quản trị router (MiWiFi)';

  @override
  String get progressTitle => 'Tiến trình thực hiện:';

  @override
  String routerNoResponse(int seconds) {
    return 'Vẫn chưa thấy router phản hồi (${seconds}s)...';
  }

  @override
  String get reconnectingEstimate => 'Đang kết nối lại... (Ước tính ~90 giây)';

  @override
  String get skipWaiting => 'Bỏ qua chờ';

  @override
  String get skipWaitingNote =>
      'Lưu ý: Nếu router đã đổi IP hoặc đèn đã báo xanh, bạn có thể bỏ qua bước này.';

  @override
  String get errorLabel => 'Lỗi!';

  @override
  String get successLabel => 'Thành công!';

  @override
  String get consoleLog => 'Nhật ký chi tiết (Console Log)';

  @override
  String get speedAnalysisLanWeak =>
      'Kết nối LAN rất yếu. Hãy kiểm tra lại dây mạng hoặc khoảng cách tới repeater.';

  @override
  String get speedAnalysisInternetSlow =>
      'Kết nối LAN tốt, nhưng Internet chậm. Vấn đề có thể từ nhà cung cấp mạng hoặc router chính.';

  @override
  String get speedAnalysisPerfect => 'Mạng hoạt động hoàn hảo!';

  @override
  String get speedAnalysisStable => 'Tốc độ mạng ổn định.';

  @override
  String get localNetworkDevices => 'Thiết bị mạng nội bộ';

  @override
  String get activeDevices => 'Thiết bị đang hoạt động';

  @override
  String scanningAddresses(int scanned, int total) {
    return 'Đang quét $scanned/$total địa chỉ';
  }

  @override
  String devicesDetected(int count) {
    return '$count thiết bị được phát hiện';
  }

  @override
  String get rescan => 'Quét lại';

  @override
  String get noDevicesFound =>
      'Chưa tìm thấy thiết bị. Hãy chắc chắn điện thoại đang kết nối Wi-Fi rồi quét lại.';

  @override
  String get deviceScanHint =>
      'Kết quả gồm các thiết bị phản hồi trên những cổng mạng phổ biến. Thiết bị chặn kết nối có thể không xuất hiện.';

  @override
  String get thisDevice => 'Thiết bị này';

  @override
  String thisDeviceNamed(String name) {
    return '$name (Thiết bị này)';
  }

  @override
  String get routerLabel => 'Router';

  @override
  String get networkDevice => 'Thiết bị mạng';

  @override
  String macLabel(String mac) {
    return 'MAC: $mac';
  }

  @override
  String portsLabel(String ports) {
    return 'Cổng: $ports';
  }

  @override
  String dataAsOf(String time) {
    return 'Dữ liệu lúc $time — chưa cập nhật được';
  }

  @override
  String pendingChanges(int count) {
    return '$count thay đổi chờ đồng bộ — đang lưu trên máy';
  }

  @override
  String syncingChanges(int count) {
    return 'Đang đồng bộ $count thay đổi...';
  }

  @override
  String changesDiscarded(int count) {
    return '$count thay đổi không đồng bộ được và đã bị bỏ qua';
  }

  @override
  String get refreshFailedNoData => 'Không tải được dữ liệu';

  @override
  String get lowPriceWarningTitle => 'Kiểm tra lại giá';

  @override
  String lowPriceWarningMessage(String price) {
    return '$price hơi thấp. Bạn có nhập thiếu số 0 không?';
  }

  @override
  String get badgeNew => 'Mới';

  @override
  String get badgeUpdated => 'Đã sửa';

  @override
  String get lowPriceWarningEdit => 'Sửa lại giá';

  @override
  String get lowPriceWarningSaveAnyway => 'Vẫn lưu';

  @override
  String get movie => 'Phim';

  @override
  String get movieTab => 'Tab Phim';

  @override
  String movieCountStatus(int count, String total) {
    return 'Tải: $count/$total';
  }

  @override
  String get searchMoviesPlaceholder => 'Tìm tên phim, diễn viên...';

  @override
  String get noMoviesFound => 'Không tìm thấy phim nào';

  @override
  String get loadMoviesFailed => 'Không thể tải thư viện phim.';

  @override
  String get invalidMovieServerUrl => 'Movie Server URL không hợp lệ.';

  @override
  String get movieServerUrlUpdated => 'Đã cập nhật Movie Server URL.';

  @override
  String get updateMovieServerFailed => 'Không thể cập nhật movie server.';

  @override
  String get movieServerUrl => 'Movie Server URL';

  @override
  String get addMovieServerUrl => 'Thêm Movie Server URL';

  @override
  String get editMovieServerUrl => 'Sửa Movie Server URL';

  @override
  String get noServersFound => 'Không có server nào';

  @override
  String get serverUrlHint => 'example.com';

  @override
  String get serverUrlHelperText => 'Nhãn và danh mục sẽ được đồng bộ tự động.';

  @override
  String get saveAndSync => 'Lưu & đồng bộ';

  @override
  String get noWatchedMovies => 'Chưa có phim nào đã xem.';

  @override
  String get noFavoriteMovies => 'Chưa có phim yêu thích.';

  @override
  String get watchedMovies => 'Phim đã xem';

  @override
  String get favoriteMovies => 'Phim yêu thích';

  @override
  String get minimize => 'Thu nhỏ';

  @override
  String get scrollToTop => 'Lên đầu trang';

  @override
  String get noCategoriesConfigured => 'Chưa cấu hình chuyên mục.';

  @override
  String get enterMovieServerUrl =>
      'Nhập Movie Server URL để tải danh mục phim.';

  @override
  String get syncing => 'Đang đồng bộ...';

  @override
  String get vietsub => 'Vietsub';

  @override
  String get updateFavoriteFailed => 'Không thể cập nhật yêu thích.';

  @override
  String get videoStreamError => 'Lỗi kết nối luồng phát video.';

  @override
  String serverNotResponding(int index) {
    return 'Server $index không phản hồi.';
  }

  @override
  String get removeFromFavorites => 'Bỏ khỏi yêu thích';

  @override
  String get addToFavorites => 'Thêm vào yêu thích';

  @override
  String serverName(String name) {
    return 'Server $name';
  }

  @override
  String get relatedMovies => 'Phim liên quan';

  @override
  String get categoryNew => 'Mới cập nhật';

  @override
  String get categorySingle => 'Phim lẻ';

  @override
  String get categorySeries => 'Phim bộ';

  @override
  String get categoryAnime => 'Hoạt hình';

  @override
  String get categoryTVShow => 'TV Shows';

  @override
  String get loadStream => 'Tải luồng phát';

  @override
  String get resolutionQuality => 'Chất lượng phân giải';

  @override
  String get volume => 'Âm lượng';

  @override
  String get playbackSpeed => 'Tốc độ';

  @override
  String get unlockRotation => 'Mở khóa xoay màn hình';

  @override
  String get lockRotation => 'Khóa xoay màn hình';

  @override
  String get zoomToFill => 'Phủ kín màn hình';

  @override
  String get zoomToFit => 'Vừa khung hình';

  @override
  String get episodeLabel => 'Tập phim';

  @override
  String get episodeFull => 'Full';

  @override
  String get episodeDefaultName => 'Tập';

  @override
  String get unmute => 'Bật tiếng';

  @override
  String get mute => 'Tắt tiếng';

  @override
  String get removeFromHistory => 'Xóa khỏi lịch sử';

  @override
  String confirmRemoveFromHistory(String title) {
    return 'Xóa \'$title\' khỏi lịch sử đã xem?';
  }

  @override
  String get directorLabel => 'Đạo diễn';

  @override
  String get actorsLabel => 'Diễn viên';

  @override
  String get countryLabel => 'Quốc gia';

  @override
  String get genreLabel => 'Thể loại';

  @override
  String get accountTitle => 'Tài khoản';

  @override
  String get accountSectionSecurity => 'Bảo mật';

  @override
  String get accountSectionDanger => 'Vùng nguy hiểm';

  @override
  String get accountEmailVerified => 'Đã xác thực email';

  @override
  String get accountEmailUnverified => 'Chưa xác thực email';

  @override
  String get accountMemberSince => 'Tham gia từ';

  @override
  String get accountLastSignIn => 'Đăng nhập gần nhất';

  @override
  String get resendConfirmationEmail => 'Gửi lại email xác thực';

  @override
  String get confirmationEmailSent =>
      'Đã gửi email xác thực — vui lòng kiểm tra hộp thư.';

  @override
  String get changePassword => 'Đổi mật khẩu';

  @override
  String get changePasswordSubtitle =>
      'Nên dùng mật khẩu riêng, không trùng với nơi khác.';

  @override
  String get currentPassword => 'Mật khẩu hiện tại';

  @override
  String get newPassword => 'Mật khẩu mới';

  @override
  String get confirmPassword => 'Nhập lại mật khẩu';

  @override
  String get passwordTooShort => 'Mật khẩu tối thiểu 6 ký tự.';

  @override
  String get passwordMismatch => 'Hai mật khẩu chưa khớp nhau.';

  @override
  String get passwordUpdated => 'Đã cập nhật mật khẩu của bạn.';

  @override
  String get passwordSameAsOld => 'Mật khẩu mới phải khác mật khẩu hiện tại.';

  @override
  String get updatePassword => 'Cập nhật mật khẩu';

  @override
  String get setNewPassword => 'Đặt mật khẩu mới';

  @override
  String get setNewPasswordMessage =>
      'Nhập mật khẩu mới cho tài khoản Do X của bạn.';

  @override
  String get deleteAccount => 'Xoá tài khoản';

  @override
  String get deleteAccountSubtitle =>
      'Xoá vĩnh viễn tài khoản cùng toàn bộ dữ liệu.';

  @override
  String get deleteAccountWarning =>
      'Tài khoản và toàn bộ lứa nuôi, doanh thu, chi phí, lịch sử xem gắn với nó sẽ bị xoá vĩnh viễn. Không thể khôi phục.';

  @override
  String get deleteAccountPasswordPrompt => 'Nhập mật khẩu để xác nhận.';

  @override
  String get accountDeleted => 'Tài khoản của bạn đã được xoá.';

  @override
  String get signUp => 'Đăng ký';

  @override
  String get noAccountSignUp => 'Chưa có tài khoản? Đăng ký';

  @override
  String get haveAccountSignIn => 'Đã có tài khoản? Đăng nhập';

  @override
  String get forgotPassword => 'Quên mật khẩu?';

  @override
  String forgotPasswordSent(String email) {
    return 'Đã gửi liên kết đặt lại mật khẩu tới $email.';
  }

  @override
  String signUpCheckEmail(String email) {
    return 'Gần xong rồi — mở liên kết chúng tôi vừa gửi tới $email để kích hoạt tài khoản.';
  }

  @override
  String get emailRequired => 'Vui lòng nhập email.';

  @override
  String get emailInvalid => 'Địa chỉ email chưa hợp lệ.';

  @override
  String get authInvalidCredentials => 'Email hoặc mật khẩu không đúng.';

  @override
  String get authEmailNotConfirmed =>
      'Email này chưa được xác thực. Hãy mở liên kết kích hoạt trong hộp thư.';

  @override
  String get authUserAlreadyExists =>
      'Email này đã được đăng ký — hãy đăng nhập.';

  @override
  String get authWeakPassword => 'Mật khẩu quá yếu. Dùng tối thiểu 6 ký tự.';

  @override
  String get authRateLimited => 'Bạn thử quá nhiều lần. Vui lòng đợi vài phút.';

  @override
  String get authUnknownError => 'Đã có lỗi xảy ra. Vui lòng thử lại.';

  @override
  String get emailLabel => 'Email';

  @override
  String get passwordLabel => 'Mật khẩu';

  @override
  String get showPassword => 'Hiện mật khẩu';

  @override
  String get hidePassword => 'Ẩn mật khẩu';

  @override
  String get verifyCodeTitle => 'Nhập mã xác nhận';

  @override
  String verifyCodeMessage(String email) {
    return 'Nhập mã chúng tôi vừa gửi tới $email. Mã có hiệu lực trong 1 giờ.';
  }

  @override
  String get verifyCodeLabel => 'Mã xác nhận';

  @override
  String get verifyCodeRequired => 'Vui lòng nhập mã trong email.';

  @override
  String get verifyCodeAction => 'Xác nhận';

  @override
  String get enterCodeInstead => 'Nhập mã trong email';

  @override
  String get resendCode => 'Gửi mã mới';

  @override
  String get codeSent => 'Đã gửi mã mới.';

  @override
  String get authOtpExpired =>
      'Mã đã hết hạn hoặc đã dùng rồi. Hãy yêu cầu mã mới.';

  @override
  String get changeAvatar => 'Đổi ảnh đại diện';

  @override
  String get chooseFromGallery => 'Chọn từ thư viện';

  @override
  String get takePhoto => 'Chụp ảnh';

  @override
  String get removeAvatar => 'Xoá ảnh đại diện';

  @override
  String get avatarUpdated => 'Đã cập nhật ảnh đại diện.';

  @override
  String get avatarRemoved => 'Đã xoá ảnh đại diện.';

  @override
  String get avatarUploadFailed => 'Không tải được ảnh lên. Vui lòng thử lại.';
}
