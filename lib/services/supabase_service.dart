import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/playlist.dart';
import '../models/phrase.dart';
import '../models/category.dart';

class SupabaseService {
  static const String apiUrl = 'https://owcnilmdizgazpjenyer.supabase.co';
  static const String apiKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im93Y25pbG1kaXpnYXpwamVueWVyIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTcwNDg5MDgwNiwiZXhwIjoyMDIwNDY2ODA2fQ.5vNotB94xoL6bssODTxpr5IhwAckoeOuq2yPTFQQ9Es';
  static const String publicStorageBase = '$apiUrl/storage/v1/object/public/';

  static final SupabaseClient client = Supabase.instance.client;

  // Fetch Playlists
  static Future<List<Playlist>> getAllPlaylists() async {
    final response = await client.from('playlists').select().order('created_at', ascending: false);
    return (response as List).map((json) => Playlist.fromJson(json)).toList();
  }

  // Create Playlist
  static Future<Playlist> createPlaylist(String title, String? imagePath) async {
    final Map<String, dynamic> data = {'title': title};
    if (imagePath != null) {
      data['image'] = imagePath;
    }
    final response = await client.from('playlists').insert(data).select().single();
    return Playlist.fromJson(response);
  }

  // Delete Playlist
  static Future<void> deletePlaylist(int playlistId) async {
    // First remove phrase playlist links to avoid FK constraint failures
    await client.from('phrase_playlist').delete().eq('playlist_id', playlistId);
    await client.from('playlists').delete().eq('id', playlistId);
  }

  // Fetch Categories
  static Future<List<Category>> getAllCategories() async {
    final response = await client.from('phrase_categories').select();
    return (response as List).map((json) => Category.fromJson(json)).toList();
  }

  // Fetch Main Categories
  static Future<List<MainCategory>> getAllMainCategories() async {
    final response = await client.from('main_categories').select();
    return (response as List).map((json) => MainCategory.fromJson(json)).toList();
  }

  // Fetch Phrases
  static Future<List<Phrase>> getAllPhrases() async {
    final response = await client.from('phrases').select();
    return (response as List).map((json) => Phrase.fromJson(json)).toList();
  }

  // Create Phrase
  static Future<Phrase> createPhrase(Phrase phrase) async {
    final json = phrase.toJson();
    json.remove('id'); // Remove id to let Supabase auto-increment
    final response = await client.from('phrases').insert(json).select().single();
    return Phrase.fromJson(response);
  }

  // Update Phrase
  static Future<void> updatePhrase(int phraseId, Map<String, dynamic> updatedData) async {
    await client.from('phrases').update(updatedData).eq('id', phraseId);
  }

  // Delete Phrase
  static Future<void> deletePhrase(int phraseId) async {
    // Remove playlist links first to avoid FK constraint failures
    await client.from('phrase_playlist').delete().eq('phrase_id', phraseId);
    await client.from('phrases').delete().eq('id', phraseId);
  }

  // Playlist Phrase Links
  static Future<List<Map<String, dynamic>>> getAllPhrasePlaylistLinks() async {
    final response = await client.from('phrase_playlist').select('phrase_id, playlist_id');
    return List<Map<String, dynamic>>.from(response);
  }

  static Future<void> addPhraseToPlaylist(int phraseId, int playlistId) async {
    await client.from('phrase_playlist').insert({
      'phrase_id': phraseId,
      'playlist_id': playlistId,
    });
  }

  static Future<void> removePhraseFromPlaylist(int phraseId, int playlistId) async {
    await client.from('phrase_playlist')
        .delete()
        .eq('phrase_id', phraseId)
        .eq('playlist_id', playlistId);
  }

  static Future<List<int>> getPhraseIdsInPlaylist(int playlistId) async {
    final response = await client
        .from('phrase_playlist')
        .select('phrase_id')
        .eq('playlist_id', playlistId);
    return (response as List).map((item) => item['phrase_id'] as int).toList();
  }

  // File Upload (Images/Audio)
  // Returns the public Key (e.g., "files/filename.ext")
  static Future<String?> uploadFile(File file, String remoteName) async {
    try {
      final String path = remoteName;
      // Upload to the 'files' bucket
      await client.storage.from('files').upload(
            path,
            file,
            fileOptions: const FileOptions(cacheControl: '3600', upsert: true),
          );
      return 'files/$path';
    } catch (e) {
      // If file already exists (conflict), return the key anyway
      if (e.toString().contains('409') || e.toString().contains('already exists')) {
        return 'files/$remoteName';
      }
      print('Error uploading file to Supabase: $e');
      rethrow;
    }
  }

  // Helper to get full public URL for a file key
  static String getPublicUrl(String? fileKey) {
    if (fileKey == null || fileKey.isEmpty) return '';
    if (fileKey.startsWith('http://') || fileKey.startsWith('https://')) {
      return fileKey;
    }
    return '$publicStorageBase$fileKey';
  }
}
