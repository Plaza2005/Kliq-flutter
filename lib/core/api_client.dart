import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_mode.dart';
import 'config.dart';
import 'demo/demo_backend.dart';

/// Single API facade for the whole app.
///
/// Feature code always calls `Api.instance.get/post/...` with server route
/// paths (e.g. `/posts/feed`). In live mode the call goes to the Node API
/// over HTTP with the JWT attached; in demo mode it is answered by the
/// in-memory [DemoBackend] — so every screen works with one code path.
class Api {
  Api._() {
    _dio = Dio(BaseOptions(
      baseUrl: AppConfig.apiUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 30),
    ));
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        if (_token != null) {
          options.headers['Authorization'] = 'Bearer $_token';
        }
        handler.next(options);
      },
    ));
  }

  static final instance = Api._();

  late final Dio _dio;
  AppModeController? _modeController;
  String? _token;

  static const _tokenKey = 'kliq.jwt';

  bool get isDemo => _modeController?.isDemo ?? false;
  String? get token => isDemo ? 'demo-token' : _token;
  bool get hasSession => isDemo || _token != null;

  Future<void> init(AppModeController mode) async {
    _modeController = mode;
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString(_tokenKey);
  }

  Future<void> setToken(String? token) async {
    _token = token;
    final prefs = await SharedPreferences.getInstance();
    if (token == null) {
      await prefs.remove(_tokenKey);
    } else {
      await prefs.setString(_tokenKey, token);
    }
  }

  Future<dynamic> get(String path, {Map<String, dynamic>? query}) =>
      _request('GET', path, query: query);

  Future<dynamic> post(String path, {Object? body}) =>
      _request('POST', path, body: body);

  Future<dynamic> patch(String path, {Object? body}) =>
      _request('PATCH', path, body: body);

  Future<dynamic> put(String path, {Object? body}) =>
      _request('PUT', path, body: body);

  Future<dynamic> delete(String path, {Object? body}) =>
      _request('DELETE', path, body: body);

  /// Multipart upload; returns `{ url: "/uploads/..." }` like the server.
  Future<dynamic> upload(String path, MultipartFile file,
      {Map<String, dynamic>? fields}) async {
    if (isDemo) {
      return DemoBackend.instance.handleUpload(path, file.filename ?? 'file');
    }
    final form = FormData.fromMap({...?fields, 'file': file});
    final res = await _dio.post(path, data: form);
    return res.data;
  }

  /// Resolve a server-relative media path (e.g. `/uploads/x.jpg`) to a URL.
  String mediaUrl(String pathOrUrl) {
    if (pathOrUrl.startsWith('http') || pathOrUrl.startsWith('data:')) {
      return pathOrUrl;
    }
    return '${AppConfig.apiUrl}$pathOrUrl';
  }

  Future<dynamic> _request(String method, String path,
      {Map<String, dynamic>? query, Object? body}) async {
    if (isDemo) {
      return DemoBackend.instance.handle(method, path,
          query: query, body: body);
    }
    try {
      final res = await _dio.request(
        path,
        queryParameters: query,
        data: body,
        options: Options(method: method),
      );
      return res.data;
    } on DioException catch (e) {
      final msg = _errorMessage(e);
      debugPrint('[api] $method $path failed: $msg');
      throw ApiException(msg, statusCode: e.response?.statusCode);
    }
  }

  String _errorMessage(DioException e) {
    final data = e.response?.data;
    if (data is Map && data['error'] is String) return data['error'] as String;
    return e.message ?? 'Network error';
  }
}

class ApiException implements Exception {
  ApiException(this.message, {this.statusCode});
  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}
