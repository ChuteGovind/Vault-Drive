class DriveFile {
  const DriveFile({
    required this.id,
    required this.name,
    required this.path,
    required this.size,
    required this.type,
    required this.createdAt,
    this.updatedAt,
    this.deleted = false,
  });

  final int id;
  final String name;
  final String path;
  final int size;
  final String type;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final bool deleted;

  factory DriveFile.fromJson(Map<String, dynamic> json) => DriveFile(
        id: (json['id'] as num).toInt(),
        name: (json['name'] ?? '').toString(),
        path: (json['path'] ?? '').toString(),
        size: (json['size'] as num?)?.toInt() ?? 0,
        type: (json['type'] ?? '').toString(),
        createdAt: DateTime.tryParse((json['createdAt'] ?? '').toString()) ??
            DateTime.now(),
        updatedAt: DateTime.tryParse((json['updatedAt'] ?? '').toString()),
        deleted: json['deleted'] == true,
      );

  DriveFile copyWith({
    int? id,
    String? name,
    String? path,
    int? size,
    String? type,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? deleted,
  }) {
    return DriveFile(
      id: id ?? this.id,
      name: name ?? this.name,
      path: path ?? this.path,
      size: size ?? this.size,
      type: type ?? this.type,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deleted: deleted ?? this.deleted,
    );
  }
}
