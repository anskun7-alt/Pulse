class Playlist {
  final String id;
  final String name;
  final List<String> mediaIds;
  final DateTime createdDate;

  Playlist({
    required this.id,
    required this.name,
    required this.mediaIds,
    required this.createdDate,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'mediaIds': mediaIds,
      'createdDate': createdDate.millisecondsSinceEpoch,
    };
  }

  factory Playlist.fromMap(Map<dynamic, dynamic> map) {
    return Playlist(
      id: map['id'] as String,
      name: map['name'] as String,
      mediaIds: List<String>.from(map['mediaIds'] ?? []),
      createdDate: DateTime.fromMillisecondsSinceEpoch(map['createdDate'] as int),
    );
  }

  Playlist copyWith({
    String? name,
    List<String>? mediaIds,
  }) {
    return Playlist(
      id: this.id,
      name: name ?? this.name,
      mediaIds: mediaIds ?? this.mediaIds,
      createdDate: this.createdDate,
    );
  }
}
