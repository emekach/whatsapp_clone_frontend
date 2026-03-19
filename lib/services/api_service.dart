// lib/services/api_service.dart

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../utils/app_theme.dart';

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  final _storage = const FlutterSecureStorage();
  late final Dio _dio;

  void init() {
    _dio = Dio(BaseOptions(
      baseUrl: AppConstants.baseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 30),
      headers: {'Accept': 'application/json'},
    ));

    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await _storage.read(key: AppConstants.tokenKey);
        if (token != null) options.headers['Authorization'] = 'Bearer $token';
        return handler.next(options);
      },
    ));
  }

  // ── Auth ─────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> register(Map<String, dynamic> data) async =>
      (await _dio.post('/auth/register', data: data)).data;

  Future<Map<String, dynamic>> login(String phone, String password) async =>
      (await _dio.post('/auth/login', data: {
        'phone': phone,
        'password': password,
      }))
          .data;

  Future<void> logout() async => await _dio.post('/auth/logout');

  Future<Map<String, dynamic>> getMe() async =>
      (await _dio.get('/auth/me')).data;

  Future<Map<String, dynamic>> updateProfile(Map<String, dynamic> data) async =>
      (await _dio.put('/auth/profile', data: data)).data;

  Future<Map<String, dynamic>> updateAvatar(String filePath) async {
    final formData = FormData.fromMap({
      'avatar': await MultipartFile.fromFile(filePath, filename: 'avatar.jpg'),
    });
    return (await _dio.post('/auth/avatar', data: formData)).data;
  }

  Future<void> ping() async {
    try {
      await _dio.post('/auth/ping');
    } catch (_) {}
  }

  // ── Conversations ─────────────────────────────────────────────────

  Future<Map<String, dynamic>> getConversations() async =>
      (await _dio.get('/conversations')).data;

  Future<Map<String, dynamic>> startPrivateConversation(int userId) async =>
      (await _dio.post('/conversations/private', data: {'user_id': userId}))
          .data;

  Future<Map<String, dynamic>> createGroup(Map<String, dynamic> data) async =>
      (await _dio.post('/conversations/group', data: data)).data;

  Future<Map<String, dynamic>> getConversation(int id) async =>
      (await _dio.get('/conversations/$id')).data;

  Future<void> deleteConversation(int id) async {
    try {
      await _dio.delete('/conversations/$id');
    } catch (_) {}
  }

  Future<void> archiveConversation(int id, bool archive) async {
    try {
      await _dio.post('/conversations/$id/archive', data: {'archive': archive});
    } catch (_) {}
  }

  Future<void> leaveConversation(int id) async =>
      await _dio.delete('/conversations/$id/leave');

  // ── Messages ──────────────────────────────────────────────────────

  Future<Map<String, dynamic>> getMessages(int conversationId,
          {int page = 1}) async =>
      (await _dio.get('/conversations/$conversationId/messages',
              queryParameters: {'page': page}))
          .data;

  Future<Map<String, dynamic>> pollMessages(
    int conversationId, {
    int lastId = 0,
  }) async =>
      (await _dio.get(
        '/conversations/$conversationId/poll',
        queryParameters: {'last_id': lastId},
      ))
          .data;

  Future<Map<String, dynamic>> sendTextMessage(
    int conversationId,
    String content, {
    int? replyToId,
  }) async =>
      (await _dio.post('/conversations/$conversationId/messages', data: {
        'type': 'text',
        'content': content,
        if (replyToId != null) 'reply_to_id': replyToId,
      }))
          .data;

  Future<Map<String, dynamic>> sendFileMessage(
    int conversationId,
    String filePath,
    String type, {
    String? filename,
    int? replyToId,
    int? duration,
    String? caption,
  }) async {
    final formData = FormData.fromMap({
      'type': type,
      'file': await MultipartFile.fromFile(filePath, filename: filename),
      if (replyToId != null) 'reply_to_id': replyToId,
      if (duration != null) 'duration': duration,
      if (caption != null && caption.isNotEmpty) 'content': caption,
    });
    return (await _dio.post(
      '/conversations/$conversationId/messages',
      data: formData,
    ))
        .data;
  }

  Future<void> deleteMessage(int messageId) async =>
      await _dio.delete('/messages/$messageId');

  Future<void> markAsRead(int conversationId) async {
    try {
      await _dio.post('/conversations/$conversationId/messages/read');
    } catch (_) {}
  }

  Future<void> sendTyping(int conversationId, bool isTyping) async {
    try {
      await _dio.post('/conversations/$conversationId/typing',
          data: {'is_typing': isTyping});
    } catch (_) {}
  }

  // ── Contacts ──────────────────────────────────────────────────────

  Future<Map<String, dynamic>> getContacts() async =>
      (await _dio.get('/contacts')).data;

  Future<Map<String, dynamic>> searchByPhone(String phone) async =>
      (await _dio.get('/contacts/search', queryParameters: {'phone': phone}))
          .data;

  Future<Map<String, dynamic>> addContact(int contactId,
          {String? nickname}) async =>
      (await _dio.post('/contacts', data: {
        'contact_id': contactId,
        if (nickname != null) 'nickname': nickname,
      }))
          .data;

  Future<Map<String, dynamic>> syncContacts(List<String> phones) async =>
      (await _dio.post('/contacts/sync', data: {'phones': phones})).data;

  // ── Statuses ──────────────────────────────────────────────────────

  Future<Map<String, dynamic>> getStatuses() async =>
      (await _dio.get('/statuses')).data;

  Future<Map<String, dynamic>> postTextStatus(String content,
          {String? bgColor}) async =>
      (await _dio.post('/statuses', data: {
        'type': 'text',
        'content': content,
        'background_color': bgColor,
      }))
          .data;

  Future<Map<String, dynamic>> postMediaStatus(
      String filePath, String type) async {
    final formData = FormData.fromMap({
      'type': type,
      'file': await MultipartFile.fromFile(filePath),
    });
    return (await _dio.post('/statuses', data: formData)).data;
  }

  // Get statuses using phone contacts for better discovery
  Future<Map<String, dynamic>> getStatusFeed(List<String> phones) async =>
      (await _dio.post('/statuses/feed', data: {'phones': phones})).data;

  Future<void> viewStatus(int statusId) async {
    try {
      await _dio.post('/statuses/$statusId/view');
    } catch (_) {}
  }

  Future<Map<String, dynamic>> getStatusViews(int statusId) async =>
      (await _dio.get('/statuses/$statusId/views')).data;

  Future<void> reactToStatus(int statusId, String emoji) async =>
      await _dio.post('/statuses/$statusId/react', data: {'emoji': emoji});

  Future<Map<String, dynamic>> replyToStatus(
          int statusId, String content) async =>
      (await _dio.post('/statuses/$statusId/reply', data: {'content': content}))
          .data;
}
