class Playlist {
  final int id;
  final String title;
  final String? image;
  final String? createdAt;

  Playlist({
    required this.id,
    required this.title,
    this.image,
    this.createdAt,
  });

  factory Playlist.fromJson(Map<String, dynamic> json) {
    return Playlist(
      id: json['id'] is int ? json['id'] : int.parse(json['id'].toString()),
      title: json['title'] ?? '',
      image: json['image'],
      createdAt: json['created_at'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'image': image,
      'created_at': createdAt,
    };
  }
}
