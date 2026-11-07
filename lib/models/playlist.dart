class Playlist {
  final String id;
  final String name;
  final List<String> mediaIds;
  final DateTime createdDate;
  final bool isTemporary;
  final String? coverImagePath;

  Playlist({
    required this.id,
    required this.name,
    required this.mediaIds,
    required this.createdDate,
    this.isTemporary = false,
    this.coverImagePath,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'mediaIds': mediaIds,
      'createdDate': createdDate.millisecondsSinceEpoch,
      'isTemporary': isTemporary,
      'coverImagePath': coverImagePath,
    };
  }

  factory Playlist.fromMap(Map<dynamic, dynamic> map) {
    return Playlist(
      id: map['id'] as String,
      name: map['name'] as String,
      mediaIds: List<String>.from(map['mediaIds'] ?? []),
      createdDate: DateTime.fromMillisecondsSinceEpoch(map['createdDate'] as int),
      isTemporary: (map['isTemporary'] as bool?) ?? false,
      coverImagePath: map['coverImagePath'] as String?,
    );
  }

  Playlist copyWith({
    String? name,
    List<String>? mediaIds,
    bool? isTemporary,
    String? coverImagePath,
  }) {
    return Playlist(
      id: this.id,
      name: name ?? this.name,
      mediaIds: mediaIds ?? this.mediaIds,
      createdDate: this.createdDate,
      isTemporary: isTemporary ?? this.isTemporary,
      coverImagePath: coverImagePath ?? this.coverImagePath,
    );
  }
}
