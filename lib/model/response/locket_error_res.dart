class LocketErrorResult {
  final List<dynamic>? errors;
  final int? status;

  LocketErrorResult({required this.errors, required this.status});

  factory LocketErrorResult.fromJson(Map<String, dynamic> json) {
    return LocketErrorResult(errors: json['errors'] as List<dynamic>?, status: json['status'] as int?);
  }
}

class LocketErrorResponse {
  final LocketErrorResult result;

  LocketErrorResponse({required this.result});

  factory LocketErrorResponse.fromJson(Map<String, dynamic> json) {
    return LocketErrorResponse(result: LocketErrorResult.fromJson(json['result'] as Map<String, dynamic>));
  }
}
