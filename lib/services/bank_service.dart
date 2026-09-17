import 'package:dio/dio.dart';
import 'package:do_x/model/bank/bank.dart';
import 'package:do_x/repository/client/dio_client.dart';
import 'package:do_x/repository/client/error_handler.dart';

/// The Vietnamese bank directory, from VietQR's public endpoint.
/// See https://www.vietqr.io/danh-sach-api/api-danh-sach-ma-ngan-hang/
class BankService {
  final _dio = DioClient.create();

  static const _url = 'https://api.vietqr.io/v2/banks';

  /// The directory changes a few times a year at most, so the first successful
  /// fetch is kept for the rest of the session: reopening the picker should not
  /// go back to the network.
  static List<Bank>? _cache;

  Future<Result<List<Bank>>> getBanks({CancelToken? cancelToken}) {
    return Result.guardFuture(() async {
      final cached = _cache;
      if (cached != null) return cached;

      final response = await _dio.get(_url, cancelToken: cancelToken);
      final rows = (response.data?['data'] as List?) ?? const [];
      final banks = rows
          .whereType<Map<String, dynamic>>()
          .map(Bank.fromJson)
          .nonNulls
          .toList();

      // Vietnamese collation, so "Á" sorts where a reader expects it rather
      // than after "Z".
      banks.sort((a, b) => a.shortName.compareTo(b.shortName));
      _cache = banks;

      return banks;
    });
  }
}
