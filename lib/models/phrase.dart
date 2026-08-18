class Phrase {
  final int id;
  final String phrase;
  final String? picture;
  final String? voice;
  final String? voiceSecond;
  final int? categoryId;
  final int? mainCategoryId;
  final int repeat;
  final int firstRepeat;
  final int secondRepeat;
  final int? priority;

  Phrase({
    required this.id,
    required this.phrase,
    this.picture,
    this.voice,
    this.voiceSecond,
    this.categoryId,
    this.mainCategoryId,
    this.repeat = 1,
    this.firstRepeat = 1,
    this.secondRepeat = 1,
    this.priority,
  });

  factory Phrase.fromJson(Map<String, dynamic> json) {
    return Phrase(
      id: json['id'] is int ? json['id'] : int.parse(json['id'].toString()),
      phrase: json['phrase'] ?? '',
      picture: json['picture'],
      voice: json['voice'],
      voiceSecond: json['voice_second'],
      categoryId: json['category_id'] != null
          ? (json['category_id'] is int
              ? json['category_id']
              : int.parse(json['category_id'].toString()))
          : null,
      mainCategoryId: json['main_category_id'] != null
          ? (json['main_category_id'] is int
              ? json['main_category_id']
              : int.parse(json['main_category_id'].toString()))
          : null,
      repeat: json['repeat'] != null
          ? (json['repeat'] is int ? json['repeat'] : int.parse(json['repeat'].toString()))
          : 1,
      firstRepeat: json['first_repeat'] != null
          ? (json['first_repeat'] is int ? json['first_repeat'] : int.parse(json['first_repeat'].toString()))
          : 1,
      secondRepeat: json['second_repeat'] != null
          ? (json['second_repeat'] is int ? json['second_repeat'] : int.parse(json['second_repeat'].toString()))
          : 1,
      priority: json['priority'] != null
          ? (json['priority'] is int ? json['priority'] : int.parse(json['priority'].toString()))
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'phrase': phrase,
      'picture': picture,
      'voice': voice,
      'voice_second': voiceSecond,
      'category_id': categoryId,
      'main_category_id': mainCategoryId,
      'repeat': repeat,
      'first_repeat': firstRepeat,
      'second_repeat': secondRepeat,
      'priority': priority,
    };
  }

  Phrase copyWith({
    int? id,
    String? phrase,
    String? picture,
    String? voice,
    String? voiceSecond,
    int? categoryId,
    int? mainCategoryId,
    int? repeat,
    int? firstRepeat,
    int? secondRepeat,
    int? priority,
  }) {
    return Phrase(
      id: id ?? this.id,
      phrase: phrase ?? this.phrase,
      picture: picture ?? this.picture,
      voice: voice ?? this.voice,
      voiceSecond: voiceSecond ?? this.voiceSecond,
      categoryId: categoryId ?? this.categoryId,
      mainCategoryId: mainCategoryId ?? this.mainCategoryId,
      repeat: repeat ?? this.repeat,
      firstRepeat: firstRepeat ?? this.firstRepeat,
      secondRepeat: secondRepeat ?? this.secondRepeat,
      priority: priority ?? this.priority,
    );
  }
}
