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
    return 'Video sau khi nén vẫn còn ${size}MB, vượt giới hạn 6MB của Locket.\n\nGiảm chất lượng xuống 480p, hoặc quay lại cắt ngắn video?';
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
  String get showLocketTab => 'Hiện tab Locket';

  @override
  String get language => 'Ngôn ngữ';

  @override
  String get vietnamese => 'Tiếng Việt';

  @override
  String get english => 'Tiếng Anh';

  @override
  String get menu => 'Menu';

  @override
  String get news => 'Tin tức';

  @override
  String get chicken => 'Nuôi gà';

  @override
  String get locket => 'Locket';

  @override
  String get rebootRouter => 'Quản lý Wifi';

  @override
  String get about => 'Giới thiệu';

  @override
  String get loginDoX => 'Đăng nhập Do X';

  @override
  String get logoutDoX => 'Đăng xuất Do X';

  @override
  String get vaccinationNotifications => 'Thông báo lịch tiêm phòng';

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
  String get index => 'Chỉ số';

  @override
  String get buy => 'Mua vào';

  @override
  String get sell => 'Bán ra';

  @override
  String get chickenManagement => 'Quản lý gà';

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
  String get yearLabel => 'Năm:';

  @override
  String get all => 'Tất cả';

  @override
  String expenseCount(int count) {
    return '$count khoản chi';
  }

  @override
  String saleCount(int count) {
    return '$count lượt bán';
  }

  @override
  String revenueAmount(String amount) {
    return 'Doanh thu: $amount';
  }

  @override
  String profitAmount(String amount) {
    return 'Lợi nhuận: $amount';
  }

  @override
  String totalAmount(String amount) {
    return 'Tổng: $amount';
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
  String get expenseFeed => 'Cám / thức ăn';

  @override
  String get expenseMedicine => 'Thuốc / vắc xin';

  @override
  String get expenseElectricity => 'Điện sưởi';

  @override
  String get expenseWater => 'Nước';

  @override
  String get expenseOther => 'Khác';
}
