import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

class ApiService {
  static String? _sessionToken;

  static String get baseUrl {
    const configuredUrl = String.fromEnvironment('API_BASE_URL');
    if (configuredUrl.isNotEmpty) return configuredUrl;
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return 'http://127.0.0.1:3000';
    }
    return 'http://localhost:3000';
  }

  static final Dio _client = _createClient();

  static Dio _createClient() {
    final client = Dio(BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 8),
      receiveTimeout: const Duration(seconds: 12),
      headers: const {'Accept': 'application/json'},
    ));
    client.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          final token = _sessionToken;
          if (token != null) options.headers['Authorization'] = 'Bearer $token';
          handler.next(options);
        },
      ),
    );
    return client;
  }

  static Future<Map<String, dynamic>> login({
    required String identifier,
    required String password,
  }) async {
    try {
      final response = await _client.post<Map<String, dynamic>>(
        '/api/auth/login',
        data: {'cedula': identifier, 'contrasena': password},
      );
      _sessionToken = response.data?['token']?.toString();
      return Map<String, dynamic>.from(response.data?['usuario'] as Map);
    } on DioException catch (error) {
      throw ApiFailure.fromDio(error, authentication: true);
    }
  }

  static Future<void> logout() async {
    try {
      if (_sessionToken != null) await _client.post<void>('/api/auth/logout');
    } on DioException {
      // A local logout must still complete when the backend is unavailable.
    } finally {
      _sessionToken = null;
    }
  }

  static Future<void> register({
    required String name,
    required String identifier,
    required String password,
  }) async {
    try {
      await _client.post<void>(
        '/api/auth/register',
        data: {'nombre': name, 'cedula': identifier, 'contrasena': password},
      );
    } on DioException catch (error) {
      throw ApiFailure.fromDio(error);
    }
  }

  static Future<List<Map<String, dynamic>>> getClients() => _getList('/api/admin/clientes');

  static Future<List<Map<String, dynamic>>> getUsers() => _getList('/api/admin/usuarios');

  static Future<List<Map<String, dynamic>>> getCashiers() => _getList('/api/admin/cajeros');

  static Future<List<Map<String, dynamic>>> getBranches() => _getList('/api/admin/sucursales');

  static Future<List<Map<String, dynamic>>> getOperations() => _getList('/api/admin/operaciones');

  static Future<List<Map<String, dynamic>>> getCashierClients() => _getList('/api/cajero/clientes');

  static Future<Map<String, dynamic>> getServicePoints() async {
    try {
      final response = await _client.get<Map<String, dynamic>>('/api/cliente/puntos-atencion');
      return Map<String, dynamic>.from(response.data ?? const {});
    } on DioException catch (error) {
      throw ApiFailure.fromDio(error);
    }
  }

  static Future<List<Map<String, dynamic>>> getFriends(String identifier) =>
      _getList('/api/cliente/${Uri.encodeComponent(identifier)}/amigos');

  static Future<List<Map<String, dynamic>>> getNotifications(String identifier) =>
      _getList('/api/notificaciones/${Uri.encodeComponent(identifier)}');

  static Future<Map<String, dynamic>> updateProfile({
    required String identifier,
    required String name,
  }) async {
    try {
      final response = await _client.put<Map<String, dynamic>>(
        '/api/cliente/${Uri.encodeComponent(identifier)}',
        data: {'nombre': name},
      );
      return Map<String, dynamic>.from(response.data ?? const {});
    } on DioException catch (error) {
      throw ApiFailure.fromDio(error);
    }
  }

  static Future<String> uploadProfileImage({
    required String identifier,
    required XFile image,
  }) async {
    try {
      final response = await _client.post<Map<String, dynamic>>(
        '/api/perfil/upload',
        data: FormData.fromMap({
          'cedula': identifier,
          'imagen': await MultipartFile.fromFile(image.path, filename: image.name),
        }),
      );
      return response.data?['url']?.toString() ?? '';
    } on DioException catch (error) {
      throw ApiFailure.fromDio(error);
    }
  }

  static Future<Map<String, dynamic>> transfer({
    required String sender,
    required String recipient,
    required double amount,
  }) async {
    try {
      final response = await _client.post<Map<String, dynamic>>(
        '/api/transferencias',
        data: {'remitente': sender, 'destinatario': recipient, 'monto': amount},
      );
      return Map<String, dynamic>.from(response.data ?? const {});
    } on DioException catch (error) {
      throw ApiFailure.fromDio(error);
    }
  }

  static Future<Map<String, dynamic>> createCashier({
    required String identifier,
    required String name,
    required String password,
    required String branch,
  }) async {
    try {
      final response = await _client.post<Map<String, dynamic>>(
        '/api/admin/cajeros',
        data: {
          'cedula': identifier,
          'nombre': name,
          'contrasena': password,
          'sucursal': branch,
        },
      );
      return Map<String, dynamic>.from(response.data ?? const {});
    } on DioException catch (error) {
      throw ApiFailure.fromDio(error);
    }
  }

  static Future<void> deleteUser(String identifier) async {
    try {
      await _client.delete<void>('/api/admin/usuarios/${Uri.encodeComponent(identifier)}');
    } on DioException catch (error) {
      throw ApiFailure.fromDio(error);
    }
  }

  static Future<Map<String, dynamic>> adjustBalance({
    required String identifier,
    required double balance,
  }) async {
    try {
      final response = await _client.patch<Map<String, dynamic>>(
        '/api/admin/usuarios/${Uri.encodeComponent(identifier)}/saldo',
        data: {'saldo': balance},
      );
      return Map<String, dynamic>.from(response.data ?? const {});
    } on DioException catch (error) {
      throw ApiFailure.fromDio(error);
    }
  }

  static Future<Map<String, dynamic>> deposit({
    required String customerIdentifier,
    required double amount,
  }) async {
    try {
      final response = await _client.post<Map<String, dynamic>>(
        '/api/cajero/depositos',
        data: {'cedula': customerIdentifier, 'monto': amount},
      );
      return Map<String, dynamic>.from(response.data ?? const {});
    } on DioException catch (error) {
      throw ApiFailure.fromDio(error);
    }
  }

  static Future<List<Map<String, dynamic>>> _getList(String path) async {
    try {
      final response = await _client.get<List<dynamic>>(path);
      return (response.data ?? const [])
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList();
    } on DioException catch (error) {
      throw ApiFailure.fromDio(error);
    }
  }
}

class ApiFailure implements Exception {
  const ApiFailure(this.message);

  final String message;

  factory ApiFailure.fromDio(DioException error, {bool authentication = false}) {
    final status = error.response?.statusCode;
    if (authentication && (status == 401 || status == 403)) {
      return const ApiFailure('Usuario o contraseña incorrectos');
    }
    if (status == null) {
      return const ApiFailure('Error de conexión con el servidor - Sin conexión');
    }
    if (status == 404 || status >= 500) {
      return ApiFailure('Error de conexión con el servidor - Status $status');
    }
    final responseData = error.response?.data;
    final serverMessage = responseData is Map ? responseData['message']?.toString() : null;
    return ApiFailure(serverMessage ?? 'Error en la solicitud - Status $status');
  }

  @override
  String toString() => message;
}