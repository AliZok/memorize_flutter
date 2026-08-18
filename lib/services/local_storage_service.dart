import 'package:hive_flutter/hive_flutter.dart';
import '../models/playlist.dart';
import '../models/phrase.dart';
import '../models/category.dart';

class LocalStorageService {
  static const String _playlistsBoxName = 'playlists_box';
  static const String _phrasesBoxName = 'phrases_box';
  static const String _categoriesBoxName = 'categories_box';
  static const String _mainCategoriesBoxName = 'main_categories_box';
  static const String _settingsBoxName = 'settings_box';
  static const String _linksBoxName = 'playlist_links_box';

  static Future<void> init() async {
    await Hive.initFlutter();
    await Hive.openBox(_playlistsBoxName);
    await Hive.openBox(_phrasesBoxName);
    await Hive.openBox(_categoriesBoxName);
    await Hive.openBox(_mainCategoriesBoxName);
    await Hive.openBox(_settingsBoxName);
    await Hive.openBox(_linksBoxName);
  }

  // Playlists Caching
  static List<Playlist> getPlaylists() {
    final box = Hive.box(_playlistsBoxName);
    final List<dynamic>? list = box.get('playlists');
    if (list == null) return [];
    return list.map((item) => Playlist.fromJson(Map<String, dynamic>.from(item))).toList();
  }

  static Future<void> savePlaylists(List<Playlist> playlists) async {
    final box = Hive.box(_playlistsBoxName);
    final list = playlists.map((p) => p.toJson()).toList();
    await box.put('playlists', list);
  }

  // Phrases Caching
  static List<Phrase> getPhrases() {
    final box = Hive.box(_phrasesBoxName);
    final List<dynamic>? list = box.get('phrases');
    if (list == null) return [];
    return list.map((item) => Phrase.fromJson(Map<String, dynamic>.from(item))).toList();
  }

  static Future<void> savePhrases(List<Phrase> phrases) async {
    final box = Hive.box(_phrasesBoxName);
    final list = phrases.map((p) => p.toJson()).toList();
    await box.put('phrases', list);
  }

  // Categories Caching
  static List<Category> getCategories() {
    final box = Hive.box(_categoriesBoxName);
    final List<dynamic>? list = box.get('categories');
    if (list == null) return [];
    return list.map((item) => Category.fromJson(Map<String, dynamic>.from(item))).toList();
  }

  static Future<void> saveCategories(List<Category> categories) async {
    final box = Hive.box(_categoriesBoxName);
    final list = categories.map((c) => c.toJson()).toList();
    await box.put('categories', list);
  }

  // Main Categories Caching
  static List<MainCategory> getMainCategories() {
    final box = Hive.box(_mainCategoriesBoxName);
    final List<dynamic>? list = box.get('main_categories');
    if (list == null) return [];
    return list.map((item) => MainCategory.fromJson(Map<String, dynamic>.from(item))).toList();
  }

  static Future<void> saveMainCategories(List<MainCategory> mainCategories) async {
    final box = Hive.box(_mainCategoriesBoxName);
    final list = mainCategories.map((mc) => mc.toJson()).toList();
    await box.put('main_categories', list);
  }

  // Settings / Simple key-value pairs
  static dynamic getSetting(String key, {dynamic defaultValue}) {
    final box = Hive.box(_settingsBoxName);
    return box.get(key, defaultValue: defaultValue);
  }

  static Future<void> saveSetting(String key, dynamic value) async {
    final box = Hive.box(_settingsBoxName);
    await box.put(key, value);
  }

  static Map<int, List<int>> getPlaylistLinks() {
    final box = Hive.box(_linksBoxName);
    final Map? raw = box.get('links');
    if (raw == null) return {};
    return raw.map((key, value) {
      final id = key is int ? key : int.parse(key.toString());
      final ids = (value as List).map((e) => e is int ? e : int.parse(e.toString())).toList();
      return MapEntry(id, ids);
    });
  }

  static Future<void> savePlaylistLinks(Map<int, List<int>> links) async {
    final box = Hive.box(_linksBoxName);
    final encoded = links.map((key, value) => MapEntry(key.toString(), value));
    await box.put('links', encoded);
  }

  static Future<void> clearAll() async {
    await Hive.box(_playlistsBoxName).clear();
    await Hive.box(_phrasesBoxName).clear();
    await Hive.box(_categoriesBoxName).clear();
    await Hive.box(_mainCategoriesBoxName).clear();
    await Hive.box(_settingsBoxName).clear();
    await Hive.box(_linksBoxName).clear();
  }
}
