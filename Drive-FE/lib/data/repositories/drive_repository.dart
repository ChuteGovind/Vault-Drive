import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/drive_file.dart';

class StorageInfo {
  const StorageInfo(
      {required this.limit, required this.used, required this.remaining});

  final int limit;
  final int used;
  final int remaining;

  double get progress => limit == 0 ? 0 : (used / limit).clamp(0, 1).toDouble();

  factory StorageInfo.fromJson(Map<String, dynamic> json) => StorageInfo(
        limit: (json['limit'] as num?)?.toInt() ?? 1073741824,
        used: (json['used'] as num?)?.toInt() ?? 0,
        remaining: (json['remaining'] as num?)?.toInt() ?? 1073741824,
      );
}

class DriveRepository {
  DriveRepository() : _dio = Dio();
  final Dio _dio;

  String get baseUrl {
    if (kIsWeb) return 'http://localhost:8080/api';
    if (defaultTargetPlatform == TargetPlatform.android)
      return 'http://10.0.2.2:8080/api';
    return 'http://localhost:8080/api';
  }

  Future<String?> getToken() async =>
      (await SharedPreferences.getInstance()).getString('auth_token');

  Future<Options> _options() async {
    final token = await getToken();
    if (token == null || token.isEmpty) throw Exception('Please login first.');
    return Options(headers: {'Authorization': 'Bearer $token'});
  }

  Future<Map<String, dynamic>> getCurrentUser() async {
    try {
      final response =
          await _dio.get('$baseUrl/auth/me', options: await _options());
      return Map<String, dynamic>.from(response.data);
    } on DioException catch (e) {
      if (e.response?.statusCode == 401 || e.response?.statusCode == 403) {
        await logout();
      }
      throw Exception(_message(e, 'Unable to load profile'));
    }
  }

  Future<bool> hasValidSession() async {
    final token = await getToken();
    if (token == null || token.isEmpty) return false;
    try {
      await getCurrentUser();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<Map<String, dynamic>> login(
      String emailOrUsername, String password) async {
    try {
      final response = await _dio.post('$baseUrl/auth/login', data: {
        'emailOrUsername': emailOrUsername.trim(),
        'password': password,
      });
      final data = Map<String, dynamic>.from(response.data);
      final token = data['token'] as String?;
      if (token != null && token.isNotEmpty) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('auth_token', token);
      }
      return data;
    } on DioException catch (e) {
      throw Exception(
          _message(e, 'Login failed. Please check your credentials.'));
    }
  }

  Future<Map<String, dynamic>> requestRegisterOtp(
      {required String name,
      required String username,
      required String email,
      required String password}) async {
    try {
      final response = await _dio.post('$baseUrl/auth/register-otp', data: {
        'name': name.trim(),
        'username': username.trim(),
        'email': email.trim(),
        'password': password,
      });
      return Map<String, dynamic>.from(response.data);
    } on DioException catch (e) {
      throw Exception(_message(e, 'Failed to send OTP'));
    }
  }

  Future<Map<String, dynamic>> verifyOtpAndRegister(
      String email, String otp) async {
    try {
      final response = await _dio.post('$baseUrl/auth/verify-otp',
          data: {'email': email.trim(), 'otp': otp.trim()});
      final data = Map<String, dynamic>.from(response.data);
      final token = data['token'] as String?;
      if (token != null && token.isNotEmpty) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('auth_token', token);
      }
      return data;
    } on DioException catch (e) {
      throw Exception(_message(e, 'OTP verification failed'));
    }
  }

  Future<void> deleteAccount() async {
    try {
      await _dio.delete('$baseUrl/auth/me', options: await _options());
      await logout();
    } on DioException catch (e) {
      throw Exception(_message(e, 'Unable to delete account'));
    }
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
  }

  Future<List<DriveFile>> list({String search = '', bool trash = false}) async {
    final response = await _dio.get('$baseUrl/files',
        queryParameters: {
          if (search.trim().isNotEmpty) 'search': search.trim(),
          'trash': trash,
        },
        options: await _options());
    return (response.data as List)
        .map((e) => DriveFile.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<StorageInfo> storage() async {
    final response =
        await _dio.get('$baseUrl/files/storage', options: await _options());
    return StorageInfo.fromJson(Map<String, dynamic>.from(response.data));
  }

  Future<void> upload(PlatformFile file,
      {void Function(double progress)? onProgress}) async {
    final MultipartFile multipart;
    if (file.bytes != null) {
      multipart = MultipartFile.fromBytes(file.bytes!, filename: file.name);
    } else if (file.path != null) {
      multipart = await MultipartFile.fromFile(file.path!, filename: file.name);
    } else {
      throw Exception('Unable to read ${file.name}');
    }
    try {
      await _dio.post('$baseUrl/files/upload',
          data: FormData.fromMap({'files': multipart}),
          options: await _options(), onSendProgress: (sent, total) {
        if (total > 0) onProgress?.call(sent / total);
      });
    } on DioException catch (e) {
      throw Exception(_message(e, 'File upload failed'));
    }
  }

  Future<List<int>> downloadBytes(int id) async {
    final options = await _options();
    options.responseType = ResponseType.bytes;

    final response = await _dio.get<List<int>>(
      '$baseUrl/files/download/$id',
      options: options,
    );

    return response.data ?? <int>[];
  }

  Future<void> rename(int id, String name) async {
    await _dio.put('$baseUrl/files/rename/$id',
        data: {'name': name}, options: await _options());
  }

  Future<void> trash(int id) async =>
      _dio.delete('$baseUrl/files/delete/$id', options: await _options());

  Future<void> restore(int id) async =>
      _dio.put('$baseUrl/files/restore/$id', options: await _options());

  Future<void> permanentDelete(int id) async =>
      _dio.delete('$baseUrl/files/permanent/$id', options: await _options());

  String _message(DioException e, String fallback) {
    final data = e.response?.data;
    if (data is Map && data['message'] != null)
      return data['message'].toString();
    return fallback;
  }
}
