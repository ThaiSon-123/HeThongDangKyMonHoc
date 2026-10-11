import 'package:dio/dio.dart';

/// Lỗi API đã chuẩn hóa từ response của backend (plan.md mục 8.4):
/// - envelope nghiệp vụ `{"error": {"code", "message", "details"}}`
/// - lỗi field DRF `{"field": ["thông điệp", ...]}`
class ApiFailure implements Exception {
  const ApiFailure({
    this.status,
    this.code,
    this.message,
    this.fields = const {},
    this.retryAfter,
  });

  final int? status;
  final String? code;
  final String? message;

  /// Lỗi theo từng ô nhập: tên field → thông điệp đầu tiên.
  final Map<String, String> fields;
  final int? retryAfter;

  bool get isNetwork => status == null;
  bool get isRateLimited => status == 429 || code == 'QUA_NHIEU_YEU_CAU';
  bool get isLocked => code == 'TAI_KHOAN_BI_KHOA';

  factory ApiFailure.from(DioException e) {
    final res = e.response;
    if (res == null) return const ApiFailure();
    final data = res.data;
    String? code;
    String? message;
    int? retryAfter;
    final fields = <String, String>{};
    if (data is Map) {
      final error = data['error'];
      if (error is Map) {
        code = error['code'] as String?;
        message = error['message'] as String?;
        final details = error['details'];
        if (details is Map && details['retry_after'] is num) {
          retryAfter = (details['retry_after'] as num).toInt();
        }
      } else {
        for (final entry in data.entries) {
          final v = entry.value;
          if (entry.key == 'detail') {
            message = v.toString();
          } else if (v is List && v.isNotEmpty) {
            fields[entry.key.toString()] = v.first.toString();
          } else if (v is String) {
            fields[entry.key.toString()] = v;
          }
        }
      }
    }
    return ApiFailure(
      status: res.statusCode,
      code: code,
      message: message,
      fields: fields,
      retryAfter: retryAfter,
    );
  }

  @override
  String toString() => 'ApiFailure($status, $code, $message, $fields)';
}
