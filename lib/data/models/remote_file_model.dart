class RemoteFileModel {
  final String name;
  final int size;
  final DateTime? modifiedAt;

  const RemoteFileModel({
    required this.name,
    this.size = 0,
    this.modifiedAt,
  });

  factory RemoteFileModel.fromJson(dynamic json) {
    if (json is String && json.isNotEmpty) {
      return RemoteFileModel(name: json);
    }

    if (json is List) {
      if (json.isNotEmpty) return RemoteFileModel.fromJson(json.first);
      return const RemoteFileModel(name: '');
    }

    if (json is! Map) return const RemoteFileModel(name: '');

    final rawName = json['name'] ??
        json['filename'] ??
        json['file_name'] ??
        json['fileName'] ??
        json['path'] ??
        '';

    var rawSize = json['size'] ??
        json['filesize'] ??
        json['file_size'] ??
        json['length'] ??
        json['bytes'] ??
        0;
    if (rawSize is String) rawSize = int.tryParse(rawSize) ?? 0;

    DateTime? modifiedAt;
    final rawDate = json['modified'] ??
        json['mtime'] ??
        json['lastModified'] ??
        json['last_modified'] ??
        json['date'];
    if (rawDate is String) modifiedAt = DateTime.tryParse(rawDate);

    return RemoteFileModel(
      name: rawName.toString(),
      size: rawSize is int ? rawSize : 0,
      modifiedAt: modifiedAt,
    );
  }

  static List<RemoteFileModel> parseList(dynamic response) {
    if (response == null) return [];

    List<dynamic> items;
    if (response is List) {
      items = response;
    } else if (response is Map) {
      items = (response['files'] ??
          response['data'] ??
          response['result'] ??
          response['list'] ??
          []) as List<dynamic>;
    } else {
      return [];
    }

    return items.map(RemoteFileModel.fromJson).toList();
  }

  @override
  String toString() => 'RemoteFileModel(name=$name, size=$size)';
}
