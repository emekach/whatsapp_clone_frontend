// lib/models/models.dart

class UserModel {
  final int id;
  final String name;
  final String phone;
  final String? email;
  final String? avatarUrl;
  final String? about;
  final bool isOnline;
  final DateTime? lastSeen;
  final String? lastSeenText;

  UserModel({
    required this.id,
    required this.name,
    required this.phone,
    this.email,
    this.avatarUrl,
    this.about,
    this.isOnline = false,
    this.lastSeen,
    this.lastSeenText,
  });

  factory UserModel.fromJson(Map<String, dynamic> j) => UserModel(
        id: _toInt(j['id']),
        name: j['name'] ?? '',
        phone: j['phone'] ?? '',
        email: j['email'],
        avatarUrl: j['avatar_url'],
        about: j['about'],
        isOnline: j['is_online'] == true || j['is_online'] == 1,
        lastSeen: j['last_seen'] != null
            ? DateTime.tryParse(j['last_seen'].toString())
            : null,
        lastSeenText: j['last_seen_text'],
      );
}

class ConversationModel {
  final int id;
  final String type;
  final String name;
  final String? avatarUrl;
  final String? description;
  final bool isOnline;
  final String? lastSeen;
  final int? otherUserId;
  int unreadCount;
  final List<ParticipantModel> participants;
  LastMessageModel? lastMessage;
  DateTime? updatedAt;

  ConversationModel({
    required this.id,
    required this.type,
    required this.name,
    this.avatarUrl,
    this.description,
    this.isOnline = false,
    this.lastSeen,
    this.otherUserId,
    this.unreadCount = 0,
    this.participants = const [],
    this.lastMessage,
    this.updatedAt,
  });

  bool get isGroup => type == 'group';

  factory ConversationModel.fromJson(Map<String, dynamic> j) =>
      ConversationModel(
        id: _toInt(j['id']),
        type: j['type'] ?? 'private',
        name: j['name'] ?? '',
        avatarUrl: j['avatar_url'],
        description: j['description'],
        isOnline: j['is_online'] == true || j['is_online'] == 1,
        lastSeen: j['last_seen']?.toString(),
        otherUserId:
            j['other_user_id'] != null ? _toInt(j['other_user_id']) : null,
        unreadCount: _toInt(j['unread_count'] ?? 0),
        participants: (j['participants'] as List? ?? [])
            .map((p) => ParticipantModel.fromJson(p))
            .toList(),
        lastMessage: j['last_message'] != null
            ? LastMessageModel.fromJson(j['last_message'])
            : null,
        updatedAt: j['updated_at'] != null
            ? DateTime.tryParse(j['updated_at'].toString())
            : null,
      );
}

class ParticipantModel {
  final int id;
  final String name;
  final String? avatarUrl;
  final String role;
  final bool isOnline;

  ParticipantModel({
    required this.id,
    required this.name,
    this.avatarUrl,
    required this.role,
    this.isOnline = false,
  });

  factory ParticipantModel.fromJson(Map<String, dynamic> j) => ParticipantModel(
        id: _toInt(j['id']),
        name: j['name'] ?? '',
        avatarUrl: j['avatar_url'],
        role: j['role'] ?? 'member',
        isOnline: j['is_online'] == true || j['is_online'] == 1,
      );
}

class LastMessageModel {
  final int id;
  final String type;
  final String? content;
  final int senderId;
  final String? senderName;
  final DateTime? createdAt;
  final bool isMe;
  final bool isRead;

  LastMessageModel({
    required this.id,
    required this.type,
    this.content,
    required this.senderId,
    this.senderName,
    this.createdAt,
    this.isMe = false,
    this.isRead = false,
  });

  factory LastMessageModel.fromJson(Map<String, dynamic> j) => LastMessageModel(
        id: _toInt(j['id']),
        type: j['type'] ?? 'text',
        content: j['content'],
        senderId: _toInt(j['sender_id']),
        senderName: j['sender_name'],
        createdAt: j['created_at'] != null
            ? DateTime.tryParse(j['created_at'].toString())
            : null,
        isMe: j['is_mine'] == true || j['is_mine'] == 1,
        isRead: j['is_read'] == true || j['is_read'] == 1,
      );

  String get preview {
    switch (type) {
      case 'image':
        return '📷 Photo';
      case 'video':
        return '🎥 Video';
      case 'audio':
        return '🎤 Voice message';
      case 'document':
        return '📄 Document';
      default:
        return content ?? '';
    }
  }
}

class MessageModel {
  final int id;
  final String type;
  final String? content;
  final String? fileUrl;
  final String? fileName;
  final int? fileSize;
  final int? duration;
  final bool isDeleted;
  final bool isMe;
  final bool isRead;
  final DateTime createdAt;
  final ReplyModel? replyTo;
  final MessageSenderModel sender;

  MessageModel({
    required this.id,
    required this.type,
    this.content,
    this.fileUrl,
    this.fileName,
    this.fileSize,
    this.duration,
    this.isDeleted = false,
    this.isMe = false,
    this.isRead = false,
    required this.createdAt,
    this.replyTo,
    required this.sender,
  });

  factory MessageModel.fromJson(Map<String, dynamic> j) => MessageModel(
        id: _toInt(j['id']),
        type: j['type'] ?? 'text',
        content: j['content'],
        fileUrl: j['file_url'],
        fileName: j['file_name'],
        fileSize: j['file_size'] != null ? _toInt(j['file_size']) : null,
        duration: j['duration'] != null ? _toInt(j['duration']) : null,
        isDeleted: j['is_deleted'] == true || j['is_deleted'] == 1,
        isMe: j['is_mine'] == true || j['is_mine'] == 1,
        isRead: j['is_read'] == true || j['is_read'] == 1,
        createdAt: DateTime.parse(j['created_at'].toString()),
        replyTo:
            j['reply_to'] != null ? ReplyModel.fromJson(j['reply_to']) : null,
        sender: MessageSenderModel.fromJson(j['sender']),
      );
}

class ReplyModel {
  final int id;
  final String? content;
  final String sender;

  ReplyModel({required this.id, this.content, required this.sender});

  factory ReplyModel.fromJson(Map<String, dynamic> j) => ReplyModel(
        id: _toInt(j['id']),
        content: j['content'],
        sender: j['sender'] ?? '',
      );
}

class MessageSenderModel {
  final int id;
  final String name;
  final String? avatarUrl;

  MessageSenderModel({required this.id, required this.name, this.avatarUrl});

  factory MessageSenderModel.fromJson(Map<String, dynamic> j) =>
      MessageSenderModel(
        id: _toInt(j['id']),
        name: j['name'] ?? '',
        avatarUrl: j['avatar_url'],
      );
}

// ── Status models ─────────────────────────────────────────────────────────

class StatusGroupModel {
  final UserModel user;
  final List<StatusModel> statuses;

  StatusGroupModel({required this.user, required this.statuses});

  factory StatusGroupModel.fromJson(Map<String, dynamic> j) {
    try {
      return StatusGroupModel(
        user: UserModel.fromJson(j['user'] as Map<String, dynamic>),
        statuses: (j['statuses'] as List? ?? [])
            .map((s) => StatusModel.fromJson(s as Map<String, dynamic>))
            .toList(),
      );
    } catch (_) {
      return StatusGroupModel(
        user: UserModel.fromJson(j['user'] as Map<String, dynamic>),
        statuses: [],
      );
    }
  }
}

class StatusModel {
  final int id;
  final String type;
  final String? content;
  final String? fileUrl;
  final String? backgroundColor;
  final DateTime createdAt;
  final DateTime expiresAt;
  final int viewCount;
  final int reactionCount;
  final String? myReaction;
  final bool isMine;
  final List<StatusViewerModel> viewers;

  StatusModel({
    required this.id,
    required this.type,
    this.content,
    this.fileUrl,
    this.backgroundColor,
    required this.createdAt,
    required this.expiresAt,
    this.viewCount = 0,
    this.reactionCount = 0,
    this.myReaction,
    this.isMine = false,
    this.viewers = const [],
  });

  factory StatusModel.fromJson(Map<String, dynamic> j) {
    try {
      return StatusModel(
        id: _toInt(j['id']),
        type: j['type'] ?? 'text',
        content: j['content'],
        fileUrl: j['file_url'],
        backgroundColor: j['background_color'],
        createdAt: j['created_at'] != null
            ? DateTime.tryParse(j['created_at'].toString()) ?? DateTime.now()
            : DateTime.now(),
        expiresAt: j['expires_at'] != null
            ? DateTime.tryParse(j['expires_at'].toString()) ??
                DateTime.now().add(const Duration(hours: 24))
            : DateTime.now().add(const Duration(hours: 24)),
        viewCount: _toInt(j['view_count'] ?? 0),
        reactionCount: _toInt(j['reaction_count'] ?? 0),
        myReaction: j['my_reaction'],
        isMine: j['is_mine'] == true || j['is_mine'] == 1,
        viewers: (j['viewers'] as List? ?? [])
            .map((v) => StatusViewerModel.fromJson(v as Map<String, dynamic>))
            .toList(),
      );
    } catch (e) {
      return StatusModel(
        id: _toInt(j['id']),
        type: j['type'] ?? 'text',
        content: j['content'],
        createdAt: DateTime.now(),
        expiresAt: DateTime.now().add(const Duration(hours: 24)),
      );
    }
  }
}

class StatusViewerModel {
  final int id;
  final String name;
  final String? avatarUrl;
  final DateTime viewedAt;
  final String? reaction;

  StatusViewerModel({
    required this.id,
    required this.name,
    this.avatarUrl,
    required this.viewedAt,
    this.reaction,
  });

  factory StatusViewerModel.fromJson(Map<String, dynamic> j) =>
      StatusViewerModel(
        id: _toInt(j['user_id']),
        name: j['name'] ?? '',
        avatarUrl: j['avatar_url'],
        viewedAt: j['viewed_at'] != null
            ? DateTime.tryParse(j['viewed_at'].toString()) ?? DateTime.now()
            : DateTime.now(),
        reaction: j['reaction'],
      );
}

int _toInt(dynamic val) {
  if (val == null) return 0;
  if (val is int) return val;
  if (val is double) return val.toInt();
  return int.tryParse(val.toString()) ?? 0;
}
