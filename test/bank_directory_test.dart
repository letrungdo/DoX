import 'package:do_x/model/bank/bank.dart';
import 'package:flutter_test/flutter_test.dart';

/// Rows exactly as `https://api.vietqr.io/v2/banks` returns them, so a change
/// in that payload's shape shows up here rather than as an empty picker.
const _vcb = {
  "id": 43,
  "name": "Ngân hàng TMCP Ngoại Thương Việt Nam",
  "code": "VCB",
  "bin": "970436",
  "shortName": "Vietcombank",
  "logo": "https://cdn.vietqr.io/img/VCB.png",
  "transferSupported": 1,
  "lookupSupported": 1,
  "short_name": "Vietcombank",
  "support": 3,
  "isTransfer": 1,
  "swift_code": "BFTVVNVX",
};

const _icb = {
  "id": 17,
  "name": "Ngân hàng TMCP Công thương Việt Nam",
  "code": "ICB",
  "bin": "970415",
  "shortName": "VietinBank",
  "logo": "https://cdn.vietqr.io/img/ICB.png",
};

void main() {
  group('bank parsing', () {
    test('reads the fields the picker shows', () {
      final bank = Bank.fromJson(Map<String, dynamic>.from(_vcb))!;

      expect(bank.code, 'VCB');
      expect(bank.shortName, 'Vietcombank');
      expect(bank.name, 'Ngân hàng TMCP Ngoại Thương Việt Nam');
      expect(bank.logo, 'https://cdn.vietqr.io/img/VCB.png');
    });

    test('a row without the fields a picker needs is dropped, not blank', () {
      expect(Bank.fromJson({'name': 'Ngân hàng nào đó'}), isNull);
      expect(Bank.fromJson({'code': 'XXX'}), isNull);
    });

    test('two rows are the same bank when their codes match', () {
      final a = Bank.fromJson(Map<String, dynamic>.from(_vcb))!;
      final b = Bank.fromJson(Map<String, dynamic>.from(_vcb))!;

      expect(a, b);
      expect(a, isNot(Bank.fromJson(Map<String, dynamic>.from(_icb))));
    });
  });

  group('bank search', () {
    final banks = [
      Bank.fromJson(Map<String, dynamic>.from(_vcb))!,
      Bank.fromJson(Map<String, dynamic>.from(_icb))!,
    ];

    List<Bank> search(String query) {
      final needle = query.trim().toLowerCase();

      return banks.where((b) => b.searchIndex.contains(needle)).toList();
    }

    test('finds a bank by the code people type', () {
      expect(search('vcb').single.shortName, 'Vietcombank');
      expect(search('icb').single.shortName, 'VietinBank');
    });

    test('finds it by the short name', () {
      expect(search('vietcom').single.shortName, 'Vietcombank');
    });

    test('finds it by a word from the full Vietnamese name', () {
      expect(search('ngoại thương').single.shortName, 'Vietcombank');
      expect(search('công thương').single.shortName, 'VietinBank');
    });

    test('a shared prefix returns both rather than guessing', () {
      expect(search('viet').length, 2);
    });

    test('no match returns nothing instead of the whole list', () {
      expect(search('không có ngân hàng này'), isEmpty);
    });
  });
}
