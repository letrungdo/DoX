class MyLifeErrorResult {
  final List<dynamic>? errors;
  final int? status;

  MyLifeErrorResult({required this.errors, required this.status});

  factory MyLifeErrorResult.fromJson(Map<String, dynamic> json) {
    return MyLifeErrorResult(
      errors: json['errors'] as List<dynamic>?,
      status: json['status'] as int?,
    );
  }
}

class MyLifeErrorResponse {
  final MyLifeErrorResult result;

  MyLifeErrorResponse({required this.result});

  factory MyLifeErrorResponse.fromJson(Map<String, dynamic> json) {
    return MyLifeErrorResponse(
      result: MyLifeErrorResult.fromJson(
        json['result'] as Map<String, dynamic>,
      ),
    );
  }
}
