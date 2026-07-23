/// "Groups" - unifică Book Clubs, Reading Groups și Community Events:
/// membri, un fir de discuții și evenimente programate opționale.
class GroupMemberInfo {
  final String userId;
  final String? name;
  final String? username;
  final String? profileImage;
  final String role;

  const GroupMemberInfo({
    required this.userId,
    this.name,
    this.username,
    this.profileImage,
    required this.role,
  });

  factory GroupMemberInfo.fromJson(Map<String, dynamic> json) {
    final user = json['user'] as Map<String, dynamic>;
    return GroupMemberInfo(
      userId: json['userId'] as String,
      name: user['name'] as String?,
      username: user['username'] as String?,
      profileImage: user['profileImage'] as String?,
      role: json['role'] as String,
    );
  }
}

class GroupPostInfo {
  final String id;
  final String content;
  final String? authorName;
  final String? authorUsername;
  final DateTime createdAt;

  const GroupPostInfo({
    required this.id,
    required this.content,
    this.authorName,
    this.authorUsername,
    required this.createdAt,
  });

  factory GroupPostInfo.fromJson(Map<String, dynamic> json) {
    final author = json['author'] as Map<String, dynamic>;
    return GroupPostInfo(
      id: json['id'] as String,
      content: json['content'] as String,
      authorName: author['name'] as String?,
      authorUsername: author['username'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}

class GroupEventInfo {
  final String id;
  final String title;
  final String? description;
  final DateTime eventAt;
  final String? location;

  const GroupEventInfo({
    required this.id,
    required this.title,
    this.description,
    required this.eventAt,
    this.location,
  });

  factory GroupEventInfo.fromJson(Map<String, dynamic> json) {
    return GroupEventInfo(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      eventAt: DateTime.parse(json['eventAt'] as String),
      location: json['location'] as String?,
    );
  }
}

class BookGroup {
  final String id;
  final String name;
  final String? description;
  final bool isPublic;
  final int memberCount;
  final bool isMember;
  final bool isAdmin;
  final List<GroupMemberInfo> members;
  final List<GroupPostInfo> posts;
  final List<GroupEventInfo> events;

  const BookGroup({
    required this.id,
    required this.name,
    this.description,
    required this.isPublic,
    required this.memberCount,
    this.isMember = false,
    this.isAdmin = false,
    this.members = const [],
    this.posts = const [],
    this.events = const [],
  });

  factory BookGroup.fromJson(Map<String, dynamic> json) {
    return BookGroup(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      isPublic: json['isPublic'] as bool? ?? true,
      memberCount: (json['_count'] as Map<String, dynamic>?)?['members'] as int? ?? 0,
      isMember: json['isMember'] as bool? ?? false,
      isAdmin: json['isAdmin'] as bool? ?? false,
      members: (json['members'] as List<dynamic>?)
              ?.map((e) => GroupMemberInfo.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      posts: (json['posts'] as List<dynamic>?)
              ?.map((e) => GroupPostInfo.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      events: (json['events'] as List<dynamic>?)
              ?.map((e) => GroupEventInfo.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
    );
  }
}
