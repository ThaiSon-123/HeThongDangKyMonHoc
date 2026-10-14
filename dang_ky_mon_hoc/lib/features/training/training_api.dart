import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_failure.dart';
import '../../core/api/page_result.dart';
import '../../core/auth/auth_provider.dart';

typedef Json = Map<String, dynamic>;

/// Gọi API dữ liệu đào tạo của PĐT (plan.md mục 8.1). Lỗi luôn được đổi thành [ApiFailure].
/// Dùng `Json` thay cho lớp riêng từng thực thể: màn hình chỉ đọc vài trường hiển thị.
class TrainingApi {
  TrainingApi(this._dio);

  final Dio _dio;

  Future<T> _guard<T>(Future<T> Function() call) async {
    try {
      return await call();
    } on DioException catch (e) {
      throw ApiFailure.from(e);
    }
  }

  static Json _json(Response res) => Json.from(res.data as Map);

  Future<PageResult<Json>> list(
    String path, {
    int page = 1,
    int pageSize = 25,
    String search = '',
    Map<String, Object?> query = const {},
  }) => _guard(() async {
    final res = await _dio.get(
      path,
      queryParameters: {
        'page': page,
        'page_size': pageSize,
        if (search.trim().isNotEmpty) 'search': search.trim(),
        for (final e in query.entries)
          if (e.value != null && '${e.value}'.isNotEmpty) e.key: e.value,
      },
    );
    final data = res.data as Map;
    return PageResult(
      count: (data['count'] as num).toInt(),
      items: [for (final e in data['results'] as List) Json.from(e as Map)],
    );
  });

  /// Một trang nguyên vẹn của DRF (`count`, `results`, và các khóa thêm như `meta`).
  Future<Json> page(
    String path, {
    int page = 1,
    int pageSize = 50,
    Map<String, Object?> query = const {},
  }) => _guard(
    () async => _json(
      await _dio.get(
        path,
        queryParameters: {
          'page': page,
          'page_size': pageSize,
          for (final e in query.entries)
            if (e.value != null && '${e.value}'.isNotEmpty) e.key: e.value,
        },
      ),
    ),
  );

  /// Gom mọi trang (50 dòng/trang) — dùng khi cần tổng/tập đầy đủ nhỏ (vd môn của một CTĐT).
  Future<List<Json>> listAll(
    String path, {
    Map<String, Object?> query = const {},
  }) async {
    final items = <Json>[];
    for (var page = 1; ; page++) {
      final r = await list(path, page: page, pageSize: 50, query: query);
      items.addAll(r.items);
      if (items.length >= r.count || r.items.isEmpty) return items;
    }
  }

  Future<Json> get(String path, {Map<String, Object?> query = const {}}) =>
      _guard(
        () async => _json(
          await _dio.get(
            path,
            queryParameters: {
              for (final e in query.entries)
                if (e.value != null && '${e.value}'.isNotEmpty) e.key: e.value,
            },
          ),
        ),
      );

  Future<Json> create(String path, Json body, {Map<String, String>? headers}) =>
      _guard(
        () async => _json(
          await _dio.post(
            path,
            data: body,
            options: Options(headers: headers),
          ),
        ),
      );

  Future<Json> update(String path, Object id, Json body) =>
      _guard(() async => _json(await _dio.patch('$path$id/', data: body)));

  /// `PATCH` thẳng vào [path] (không kèm id) — vd cấu hình hệ thống.
  Future<Json> patch(String path, Json body) =>
      _guard(() async => _json(await _dio.patch(path, data: body)));

  Future<Json> put(String path, Json body) =>
      _guard(() async => _json(await _dio.put(path, data: body)));

  Future<void> delete(String path, Object id) =>
      _guard(() => _dio.delete('$path$id/'));

  /// `DELETE` kèm body (hủy đăng ký hộ cần `ly_do`); trả bản ghi sau khi hủy.
  Future<Json> cancel(String path, Object id, Json body) =>
      _guard(() async => _json(await _dio.delete('$path$id/', data: body)));

  /// Tải tệp nhị phân (xuất Excel).
  Future<List<int>> getBytes(
    String path, {
    Map<String, Object?> query = const {},
  }) => _guard(() async {
    final res = await _dio.get<List<int>>(
      path,
      queryParameters: {
        for (final e in query.entries)
          if (e.value != null && '${e.value}'.isNotEmpty) e.key: e.value,
      },
      options: Options(responseType: ResponseType.bytes),
    );
    return res.data ?? const <int>[];
  });

  /// `POST multipart/form-data` (gửi yêu cầu sửa điểm danh kèm minh chứng tùy chọn).
  Future<Json> createForm(
    String path,
    Map<String, Object> fields, {
    String? fileField,
    String? fileName,
    List<int>? fileBytes,
  }) => _guard(() async {
    final form = FormData.fromMap({
      ...fields,
      if (fileField != null && fileBytes != null)
        fileField: MultipartFile.fromBytes(fileBytes, filename: fileName),
    });
    return _json(await _dio.post(path, data: form));
  });

  /// Action kiểu `POST /semesters/1/open/` (đổi trạng thái, gia hạn…).
  Future<Json> action(String path, Object id, String name, [Json? body]) =>
      _guard(() async => _json(await _dio.post('$path$id/$name/', data: body)));

  Future<Json> patchAction(String path, Object id, String name, Json body) =>
      _guard(
        () async => _json(await _dio.patch('$path$id/$name/', data: body)),
      );
}

final trainingApiProvider = Provider<TrainingApi>(
  (ref) => TrainingApi(ref.watch(apiClientProvider).dio),
);

/// Đọc trường dạng số/chuỗi từ [Json] không ném lỗi khi thiếu.
extension JsonX on Json {
  int get id => (this['id'] as num).toInt();
  String str(String key) => (this[key] ?? '').toString();
  int num0(String key) => ((this[key] as num?) ?? 0).toInt();
}
