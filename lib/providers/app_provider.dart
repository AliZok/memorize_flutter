import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/widgets.dart' hide Category;
import 'package:just_audio/just_audio.dart';
import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/playlist.dart';
import '../models/phrase.dart';
import '../models/category.dart';
import '../services/supabase_service.dart';
import '../services/local_storage_service.dart';

class AppProvider extends ChangeNotifier with WidgetsBindingObserver {
  List<Playlist> _playlists = [];
  List<Phrase> _phrases = [];
  List<Category> _categories = [];
  List<MainCategory> _mainCategories = [];
  Playlist? _selectedPlaylist;
  List<Phrase> _playlistPhrases = [];
  Map<int, List<int>> _playlistLinks = {};
  Map<int, bool> _phraseCheckStates = {};
  String _searchPhrase = '';
  Category? _selectedPhraseCategory;
  MainCategory? _selectedMainCategory;
  bool _isLoading = true;
  bool _isBusy = false;
  String? _notice;

  List<Playlist> get playlists => _playlists;
  List<Phrase> get phrases => _phrases;
  List<Category> get categories => _categories;
  List<MainCategory> get mainCategories => _mainCategories;
  Playlist? get selectedPlaylist => _selectedPlaylist;
  List<Phrase> get playlistPhrases => _playlistPhrases;
  Map<int, bool> get phraseCheckStates => _phraseCheckStates;
  String get searchPhrase => _searchPhrase;
  Category? get selectedPhraseCategory => _selectedPhraseCategory;
  MainCategory? get selectedMainCategory => _selectedMainCategory;
  bool get isLoading => _isLoading;
  bool get isBusy => _isBusy;
  String? get notice => _notice;

  Phrase? get currentPhrase {
    if (_phraseCounter == null || _playlistPhrases.isEmpty) return null;
    if (_phraseCounter! < 0 || _phraseCounter! >= _playlistPhrases.length) return null;
    return _playlistPhrases[_phraseCounter!];
  }

  final AudioPlayer _audioPlayer = AudioPlayer();
  StreamSubscription? _playerStateSubscription;
  StreamSubscription? _currentIndexSubscription;
  StreamSubscription? _playerErrorSubscription;
  StreamSubscription? _interruptionSubscription;
  bool _isPlaying = false;
  bool _isAutoplay = false;
  int? _phraseCounter;
  bool _isRandom = false;
  bool _isSecondVoicePlaying = false;
  int _playToken = 0;
  int _repeatCounter = 0;
  int _firstRepeatCounter = 0;
  int _secondRepeatCounter = 0;
  int _mediaSeq = 0;
  bool _isRefillingQueue = false;
  int? _nextPhraseToEnqueue;
  String? _gapShortPath;
  String? _gapLongPath;
  final List<_QueuedClip> _queueClips = [];
  bool _restartingQueue = false;

  bool get isPlaying => _isPlaying;
  bool get isAutoplay => _isAutoplay;
  int? get phraseCounter => _phraseCounter;
  bool get isRandom => _isRandom;
  bool get isSecondVoicePlaying => _isSecondVoicePlaying;

  AppProvider() {
    _isRandom = LocalStorageService.getSetting('isRandom', defaultValue: false) == true;
    WidgetsBinding.instance.addObserver(this);
    _initAudioPlayer();
    _loadLocalData();
    refreshData();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.detached) return;
    if (state == AppLifecycleState.inactive) {
      _activateAudioSession();
      return;
    }
    _activateAudioSession();
    if (_isAutoplay) {
      _audioPlayer.play();
    }
  }

  Future<void> _activateAudioSession() async {
    try {
      final session = await AudioSession.instance;
      await session.setActive(true);
    } catch (e) {
      debugPrint('Audio session activate failed: $e');
    }
  }

  void _initAudioPlayer() {
    _audioPlayer.setSkipSilenceEnabled(false);
    _playerStateSubscription = _audioPlayer.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed) {
        _handleAudioCompleted();
      }
    });
    _currentIndexSubscription = _audioPlayer.currentIndexStream.listen(_onPlayerIndex);
    _playerErrorSubscription = _audioPlayer.errorStream.listen((error) {
      debugPrint('Audio player error: $error');
      if (_isAutoplay) {
        _audioPlayer.seekToNext();
      }
    });
    _initAudioInterruptionHandler();
    _ensureSilenceFiles();
  }

  Future<void> _initAudioInterruptionHandler() async {
    try {
      final session = await AudioSession.instance;
      _interruptionSubscription = session.interruptionEventStream.listen((event) {
        if (event.begin) return;
        if (!_isAutoplay) return;
        _activateAudioSession();
        _audioPlayer.play();
      });
    } catch (e) {
      debugPrint('Audio interruption handler failed: $e');
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _playerStateSubscription?.cancel();
    _currentIndexSubscription?.cancel();
    _playerErrorSubscription?.cancel();
    _interruptionSubscription?.cancel();
    _audioPlayer.dispose();
    super.dispose();
  }

  void showNotice(String message) {
    _notice = message;
    notifyListeners();
  }

  void clearNotice() {
    _notice = null;
  }

  void _loadLocalData() {
    _playlists = LocalStorageService.getPlaylists();
    _phrases = LocalStorageService.getPhrases();
    _categories = LocalStorageService.getCategories();
    _mainCategories = LocalStorageService.getMainCategories();
    _playlistLinks = LocalStorageService.getPlaylistLinks();

    if (_mainCategories.isNotEmpty) {
      _selectedMainCategory = _mainCategories.first;
    }

    final savedPlaylistId = LocalStorageService.getSetting('selectedPlaylistId');
    if (_playlists.isNotEmpty) {
      Playlist? found;
      if (savedPlaylistId != null) {
        for (final p in _playlists) {
          if (p.id == savedPlaylistId) {
            found = p;
            break;
          }
        }
      }
      _selectedPlaylist = found ?? _playlists.first;
      _applyPlaylistPhrasesFromCache();
    }
  }

  void _applyPlaylistPhrasesFromCache() {
    if (_selectedPlaylist == null) {
      _playlistPhrases = [];
      _phraseCounter = null;
      _phraseCheckStates = {};
      return;
    }
    final ids = _playlistLinks[_selectedPlaylist!.id] ?? [];
    _playlistPhrases = _phrases.where((p) => ids.contains(p.id)).toList();
    _phraseCheckStates = {
      for (final p in _phrases) p.id: ids.contains(p.id),
    };
    _phraseCounter = _playlistPhrases.isNotEmpty ? 0 : null;
    _syncRepeatCountersToCurrentPhrase();
  }

  Future<void> refreshData() async {
    _isLoading = true;
    notifyListeners();

    try {
      final fetchedPlaylists = await SupabaseService.getAllPlaylists();
      final fetchedPhrases = await SupabaseService.getAllPhrases();
      final fetchedCategories = await SupabaseService.getAllCategories();
      final fetchedMainCategories = await SupabaseService.getAllMainCategories();
      final linksRaw = await SupabaseService.getAllPhrasePlaylistLinks();

      _playlists = fetchedPlaylists;
      _phrases = fetchedPhrases;
      _categories = fetchedCategories;
      _mainCategories = fetchedMainCategories;

      _playlistLinks = {};
      for (final row in linksRaw) {
        final playlistId = row['playlist_id'] is int
            ? row['playlist_id'] as int
            : int.parse(row['playlist_id'].toString());
        final phraseId = row['phrase_id'] is int
            ? row['phrase_id'] as int
            : int.parse(row['phrase_id'].toString());
        _playlistLinks.putIfAbsent(playlistId, () => []);
        _playlistLinks[playlistId]!.add(phraseId);
      }

      await LocalStorageService.savePlaylists(fetchedPlaylists);
      await LocalStorageService.savePhrases(fetchedPhrases);
      await LocalStorageService.saveCategories(fetchedCategories);
      await LocalStorageService.saveMainCategories(fetchedMainCategories);
      await LocalStorageService.savePlaylistLinks(_playlistLinks);

      if (_mainCategories.isNotEmpty && _selectedMainCategory == null) {
        _selectedMainCategory = _mainCategories.first;
      }

      final savedPlaylistId = LocalStorageService.getSetting('selectedPlaylistId');
      if (_playlists.isNotEmpty) {
        Playlist? found;
        if (savedPlaylistId != null) {
          for (final p in _playlists) {
            if (p.id == savedPlaylistId) {
              found = p;
              break;
            }
          }
        }
        _selectedPlaylist = found ?? _playlists.first;
        LocalStorageService.saveSetting('selectedPlaylistId', _selectedPlaylist!.id);
      } else {
        _selectedPlaylist = null;
      }

      _applyPlaylistPhrasesFromCache();
    } catch (e) {
      debugPrint('Error fetching data from Supabase: $e');
      _applyPlaylistPhrasesFromCache();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> selectPlaylist(Playlist playlist) async {
    _selectedPlaylist = playlist;
    LocalStorageService.saveSetting('selectedPlaylistId', playlist.id);
    stopPlaying();
    _applyPlaylistPhrasesFromCache();
    notifyListeners();

    try {
      final ids = await SupabaseService.getPhraseIdsInPlaylist(playlist.id);
      _playlistLinks[playlist.id] = ids;
      await LocalStorageService.savePlaylistLinks(_playlistLinks);
      _applyPlaylistPhrasesFromCache();
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading playlist phrases: $e');
    }
  }

  void setSearchPhrase(String query) {
    _searchPhrase = query;
    notifyListeners();
  }

  void selectPhraseCategory(Category? category) {
    _selectedPhraseCategory = category;
    notifyListeners();
  }

  void selectNoCategory() {
    _selectedPhraseCategory = Category(id: -1, title: 'None');
    notifyListeners();
  }

  void selectMainCategory(MainCategory category) {
    _selectedMainCategory = category;
    notifyListeners();
  }

  List<Phrase> get libraryPhrases {
    final query = _searchPhrase.trim().toLowerCase();
    return _phrases.where((p) {
      final matchesSearch = query.isEmpty || p.phrase.toLowerCase().contains(query);
      if (!matchesSearch) return false;
      if (query.isNotEmpty) return true;
      if (_selectedPhraseCategory == null) return false;
      if (_selectedPhraseCategory!.id == -1) {
        return p.categoryId == null;
      }
      if (p.categoryId != _selectedPhraseCategory!.id) return false;
      if (_selectedMainCategory != null && p.mainCategoryId != _selectedMainCategory!.id) {
        return false;
      }
      return true;
    }).toList();
  }

  bool isPlaylistEmpty(Playlist playlist) {
    return (_playlistLinks[playlist.id] ?? []).isEmpty;
  }

  Future<void> createNewPlaylist(String title, File? coverFile) async {
    _isBusy = true;
    notifyListeners();
    try {
      String? remoteImagePath;
      if (coverFile != null) {
        final ext = coverFile.path.split('.').last;
        final name = 'playlist_${DateTime.now().millisecondsSinceEpoch}.$ext';
        remoteImagePath = await SupabaseService.uploadFile(coverFile, name);
      }
      final newPlaylist = await SupabaseService.createPlaylist(
        title,
        remoteImagePath != null ? SupabaseService.getPublicUrl(remoteImagePath) : null,
      );
      _playlists.insert(0, newPlaylist);
      _playlistLinks[newPlaylist.id] = [];
      await LocalStorageService.savePlaylists(_playlists);
      await LocalStorageService.savePlaylistLinks(_playlistLinks);
      await selectPlaylist(newPlaylist);
    } catch (e) {
      debugPrint('Error creating playlist: $e');
    } finally {
      _isBusy = false;
      notifyListeners();
    }
  }

  Future<void> deletePlaylist(Playlist playlist) async {
    _isBusy = true;
    notifyListeners();
    try {
      await SupabaseService.deletePlaylist(playlist.id);
      _playlists.removeWhere((p) => p.id == playlist.id);
      _playlistLinks.remove(playlist.id);
      await LocalStorageService.savePlaylists(_playlists);
      await LocalStorageService.savePlaylistLinks(_playlistLinks);
      if (_selectedPlaylist?.id == playlist.id) {
        _selectedPlaylist = _playlists.isNotEmpty ? _playlists.first : null;
        if (_selectedPlaylist != null) {
          LocalStorageService.saveSetting('selectedPlaylistId', _selectedPlaylist!.id);
        }
      }
      _applyPlaylistPhrasesFromCache();
      showNotice('your Playlist deleted');
    } catch (e) {
      debugPrint('Error deleting playlist: $e');
    } finally {
      _isBusy = false;
      notifyListeners();
    }
  }

  Future<void> togglePhraseInPlaylist(Phrase phrase) async {
    if (_selectedPlaylist == null) return;
    final isChecked = _phraseCheckStates[phrase.id] ?? false;
    try {
      if (isChecked) {
        await SupabaseService.removePhraseFromPlaylist(phrase.id, _selectedPlaylist!.id);
        _playlistLinks[_selectedPlaylist!.id]?.remove(phrase.id);
      } else {
        await SupabaseService.addPhraseToPlaylist(phrase.id, _selectedPlaylist!.id);
        _playlistLinks.putIfAbsent(_selectedPlaylist!.id, () => []);
        if (!_playlistLinks[_selectedPlaylist!.id]!.contains(phrase.id)) {
          _playlistLinks[_selectedPlaylist!.id]!.add(phrase.id);
        }
      }
      await LocalStorageService.savePlaylistLinks(_playlistLinks);
      _applyPlaylistPhrasesFromCache();
      notifyListeners();
    } catch (e) {
      debugPrint('Error toggling phrase in playlist: $e');
    }
  }

  Future<void> createNewPhrase({
    required String phraseText,
    required int mainCategoryId,
    int? categoryId,
    File? imageFile,
    File? voiceFile,
    File? voiceSecondFile,
  }) async {
    _isBusy = true;
    notifyListeners();
    try {
      String? pictureKey;
      String? voiceKey;
      String? voiceSecondKey;
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      if (imageFile != null) {
        final ext = imageFile.path.split('.').last;
        pictureKey = await SupabaseService.uploadFile(imageFile, 'img_$timestamp.$ext');
      }
      if (voiceFile != null) {
        voiceKey = await SupabaseService.uploadFile(voiceFile, 'voice_$timestamp.m4a');
      }
      if (voiceSecondFile != null) {
        voiceSecondKey = await SupabaseService.uploadFile(voiceSecondFile, 'voice_second_$timestamp.m4a');
      }
      final savedPhrase = await SupabaseService.createPhrase(
        Phrase(
          id: 0,
          phrase: phraseText,
          picture: pictureKey,
          voice: voiceKey,
          voiceSecond: voiceSecondKey,
          categoryId: categoryId,
          mainCategoryId: mainCategoryId,
        ),
      );
      _phrases.add(savedPhrase);
      await LocalStorageService.savePhrases(_phrases);
      if (_selectedPlaylist != null) {
        await togglePhraseInPlaylist(savedPhrase);
      }
      showNotice('your Phrase inserted');
    } catch (e) {
      debugPrint('Error creating phrase: $e');
    } finally {
      _isBusy = false;
      notifyListeners();
    }
  }

  Future<void> updatePhraseSettings(
    Phrase phrase, {
    int? repeat,
    int? firstRepeat,
    int? secondRepeat,
    int? categoryId,
    int? mainCategoryId,
    String? phraseText,
    bool clearCategory = false,
  }) async {
    final updated = Phrase(
      id: phrase.id,
      phrase: phraseText ?? phrase.phrase,
      picture: phrase.picture,
      voice: phrase.voice,
      voiceSecond: phrase.voiceSecond,
      categoryId: clearCategory ? null : (categoryId ?? phrase.categoryId),
      mainCategoryId: mainCategoryId ?? phrase.mainCategoryId,
      repeat: repeat ?? phrase.repeat,
      firstRepeat: firstRepeat ?? phrase.firstRepeat,
      secondRepeat: secondRepeat ?? phrase.secondRepeat,
      priority: phrase.priority,
    );
    try {
      await SupabaseService.updatePhrase(phrase.id, {
        'repeat': updated.repeat,
        'first_repeat': updated.firstRepeat,
        'second_repeat': updated.secondRepeat,
        'category_id': updated.categoryId,
        'main_category_id': updated.mainCategoryId,
        'phrase': updated.phrase,
      });
      final idx = _phrases.indexWhere((p) => p.id == phrase.id);
      if (idx != -1) _phrases[idx] = updated;
      await LocalStorageService.savePhrases(_phrases);
      _applyPlaylistPhrasesFromCache();
      notifyListeners();
    } catch (e) {
      debugPrint('Error updating phrase: $e');
    }
  }

  Future<void> deletePhraseFromDatabase(Phrase phrase) async {
    try {
      await SupabaseService.deletePhrase(phrase.id);
      _phrases.removeWhere((p) => p.id == phrase.id);
      for (final entry in _playlistLinks.entries) {
        entry.value.remove(phrase.id);
      }
      await LocalStorageService.savePhrases(_phrases);
      await LocalStorageService.savePlaylistLinks(_playlistLinks);
      _applyPlaylistPhrasesFromCache();
      showNotice('your Phrase deleted');
      notifyListeners();
    } catch (e) {
      debugPrint('Error deleting phrase: $e');
    }
  }

  void _syncRepeatCountersToCurrentPhrase() {
    if (_phraseCounter == null || _playlistPhrases.isEmpty) return;
    final current = _playlistPhrases[_phraseCounter!];
    _repeatCounter = current.repeat > 0 ? current.repeat : 1;
    _firstRepeatCounter = current.firstRepeat > 0 ? current.firstRepeat : 1;
    _secondRepeatCounter = 1;
  }

  void toggleRandom() {
    _isRandom = !_isRandom;
    LocalStorageService.saveSetting('isRandom', _isRandom);
    notifyListeners();
  }

  void togglePlay() {
    if (_isAutoplay) {
      stopPlaying();
    } else {
      start();
    }
  }

  void start() {
    if (_playlistPhrases.isEmpty) {
      showNotice('insert your Phrases\nYour List is emply');
      return;
    }
    _isAutoplay = true;
    _isPlaying = true;
    _playToken++;
    _phraseCounter ??= 0;
    _syncRepeatCountersToCurrentPhrase();
    notifyListeners();
    _startAutoplayQueue(playMainOnlyFirst: false);
  }

  void stopPlaying() {
    _isAutoplay = false;
    _isPlaying = false;
    _isSecondVoicePlaying = false;
    _playToken++;
    _queueClips.clear();
    _nextPhraseToEnqueue = null;
    _audioPlayer.stop();
    notifyListeners();
  }

  int _pickRandomPhraseIndex([int? fromIndex]) {
    final total = _playlistPhrases.length;
    if (total <= 1) return 0;
    final current = fromIndex ?? _phraseCounter;
    if (current == null || current < 0 || current >= total) {
      return Random().nextInt(total);
    }
    final index = Random().nextInt(total - 1);
    return index >= current ? index + 1 : index;
  }

  int _nextPhraseIndex(int current) {
    if (_playlistPhrases.isEmpty) return 0;
    if (_isRandom) return _pickRandomPhraseIndex(current);
    return (current + 1) % _playlistPhrases.length;
  }

  int _previousPhraseIndex(int current) {
    if (_playlistPhrases.isEmpty) return 0;
    if (_isRandom) return _pickRandomPhraseIndex(current);
    return current <= 0 ? _playlistPhrases.length - 1 : current - 1;
  }

  void goToNext({bool playMain = false}) {
    if (_playlistPhrases.isEmpty) {
      showNotice('insert your Phrases\nYour List is emply');
      return;
    }
    _playToken++;
    _phraseCounter = _nextPhraseIndex(_phraseCounter ?? 0);
    _syncRepeatCountersToCurrentPhrase();
    notifyListeners();
    if (_isAutoplay) {
      _startAutoplayQueue(playMainOnlyFirst: playMain);
    } else {
      _playVoice(playMainOnly: playMain);
    }
  }

  void goToPrevious({bool playMain = false}) {
    if (_playlistPhrases.isEmpty) {
      showNotice('insert your Phrases\nYour List is emply');
      return;
    }
    _playToken++;
    _phraseCounter = _previousPhraseIndex(_phraseCounter ?? 0);
    _syncRepeatCountersToCurrentPhrase();
    notifyListeners();
    if (_isAutoplay) {
      _startAutoplayQueue(playMainOnlyFirst: playMain);
    } else {
      _playVoice(playMainOnly: playMain);
    }
  }

  Future<void> _startAutoplayQueue({required bool playMainOnlyFirst}) async {
    final currentToken = _playToken;
    await _ensureNotificationPermission();
    await _ensureSilenceFiles();
    await _activateAudioSession();
    if (currentToken != _playToken || !_isAutoplay) return;

    final startIndex = _phraseCounter ?? 0;
    final built = _buildAutoplayQueue(
      startPhraseIndex: startIndex,
      playMainOnlyFirst: playMainOnlyFirst,
    );
    if (currentToken != _playToken || !_isAutoplay) return;
    if (built.sources.isEmpty) {
      showNotice('No Voice available');
      return;
    }

    _queueClips
      ..clear()
      ..addAll(built.clips);
    _nextPhraseToEnqueue = built.nextPhraseIndex;
    _applyQueuedClip(built.clips.first);

    try {
      await _audioPlayer.setAudioSources(built.sources, preload: true);
      if (currentToken != _playToken || !_isAutoplay) return;
      await _audioPlayer.play();
    } catch (e) {
      debugPrint('Error starting autoplay queue: $e');
      showNotice('No Voice available');
    }
  }

  _BuiltQueue _buildAutoplayQueue({
    required int startPhraseIndex,
    required bool playMainOnlyFirst,
    int targetSources = 1200,
  }) {
    final sources = <AudioSource>[];
    final clips = <_QueuedClip>[];
    var phraseIndex = startPhraseIndex;
    var skipSecond = playMainOnlyFirst;
    var nextIndex = startPhraseIndex;
    final seenSkips = <int>{};

    while (sources.length < targetSources) {
      final phrase = _playlistPhrases[phraseIndex];
      if (phrase.repeat <= 0) {
        if (!seenSkips.add(phraseIndex) && seenSkips.length >= _playlistPhrases.length) {
          break;
        }
        phraseIndex = _nextPhraseIndex(phraseIndex);
        skipSecond = false;
        continue;
      }
      seenSkips.clear();
      _appendPhraseVisit(
        sources: sources,
        clips: clips,
        phraseIndex: phraseIndex,
        skipSecondVoice: skipSecond,
      );
      nextIndex = _nextPhraseIndex(phraseIndex);
      phraseIndex = nextIndex;
      skipSecond = false;
      if (_playlistPhrases.isEmpty) break;
    }

    return _BuiltQueue(
      sources: sources,
      clips: clips,
      nextPhraseIndex: nextIndex,
    );
  }

  void _appendPhraseVisit({
    required List<AudioSource> sources,
    required List<_QueuedClip> clips,
    required int phraseIndex,
    required bool skipSecondVoice,
  }) {
    final phrase = _playlistPhrases[phraseIndex];
    final repeat = phrase.repeat > 0 ? phrase.repeat : 1;
    final firstRepeat = phrase.firstRepeat > 0 ? phrase.firstRepeat : 1;
    final hasSecond = phrase.voiceSecond != null && phrase.voiceSecond!.isNotEmpty;
    final hasMain = phrase.voice != null && phrase.voice!.isNotEmpty;

    bool appendFullCycle() {
      if (hasSecond) {
        _appendVoice(sources, clips, phrase, phraseIndex, isSecond: true);
      }
      if (hasMain) {
        for (var i = 0; i < firstRepeat; i++) {
          _appendVoice(sources, clips, phrase, phraseIndex, isSecond: false);
        }
        return true;
      }
      if (!hasSecond) {
        _appendMissingVoiceGap(sources, clips, phrase, phraseIndex);
      } else {
        _appendMissingVoiceGap(sources, clips, phrase, phraseIndex);
      }
      return false;
    }

    if (skipSecondVoice) {
      if (hasMain) {
        for (var i = 0; i < firstRepeat; i++) {
          _appendVoice(sources, clips, phrase, phraseIndex, isSecond: false);
        }
        for (var r = 1; r < repeat; r++) {
          if (!appendFullCycle()) return;
        }
      } else {
        _appendMissingVoiceGap(sources, clips, phrase, phraseIndex);
      }
      return;
    }

    for (var r = 0; r < repeat; r++) {
      if (!appendFullCycle()) return;
    }
  }

  void _appendVoice(
    List<AudioSource> sources,
    List<_QueuedClip> clips,
    Phrase phrase,
    int phraseIndex, {
    required bool isSecond,
  }) {
    final clip = _QueuedClip(
      phraseIndex: phraseIndex,
      isSecondVoice: isSecond,
    );
    final item = _mediaItemFor(phrase, isSecond: isSecond);
    sources.add(_voiceSource(phrase, isSecond: isSecond, tag: item));
    clips.add(clip);
    sources.add(_gapSource(item, long: false));
    clips.add(clip);
  }

  void _appendMissingVoiceGap(
    List<AudioSource> sources,
    List<_QueuedClip> clips,
    Phrase phrase,
    int phraseIndex,
  ) {
    final clip = _QueuedClip(
      phraseIndex: phraseIndex,
      isSecondVoice: false,
      isMissingVoice: true,
    );
    sources.add(_gapSource(_mediaItemFor(phrase, isSecond: false), long: true));
    clips.add(clip);
  }

  AudioSource _voiceSource(Phrase phrase, {required bool isSecond, required MediaItem tag}) {
    final key = isSecond ? phrase.voiceSecond : phrase.voice;
    return AudioSource.uri(Uri.parse(SupabaseService.getPublicUrl(key!)), tag: tag);
  }

  AudioSource _gapSource(MediaItem tag, {required bool long}) {
    final path = long ? _gapLongPath : _gapShortPath;
    return ProgressiveAudioSource(
      Uri.file(path!),
      tag: tag,
      duration: long ? const Duration(seconds: 3) : const Duration(milliseconds: 1700),
    );
  }

  MediaItem _mediaItemFor(Phrase phrase, {required bool isSecond}) {
    _mediaSeq++;
    return MediaItem(
      id: '${phrase.id}_${isSecond ? 'v2' : 'v1'}_$_mediaSeq',
      title: phrase.phrase,
      album: _selectedPlaylist?.title ?? 'Memorize',
      artist: isSecond ? 'Translated Voice' : 'Voice',
      playable: true,
    );
  }

  void _onPlayerIndex(int? index) {
    if (!_isAutoplay || index == null) return;
    if (index < 0 || index >= _queueClips.length) return;
    _applyQueuedClip(_queueClips[index]);
    _maybeRefillQueue(index);
  }

  void _applyQueuedClip(_QueuedClip clip) {
    if (clip.phraseIndex < 0 || clip.phraseIndex >= _playlistPhrases.length) return;
    final changed = _phraseCounter != clip.phraseIndex ||
        _isSecondVoicePlaying != clip.isSecondVoice;
    _phraseCounter = clip.phraseIndex;
    _isSecondVoicePlaying = clip.isSecondVoice;
    _isPlaying = true;
    if (clip.isMissingVoice) {
      showNotice('No Voice available');
    }
    if (changed) notifyListeners();
  }

  Future<void> _maybeRefillQueue(int currentIndex) async {
    if (!_isAutoplay || _isRefillingQueue) return;
    final remaining = _queueClips.length - currentIndex;
    if (remaining > 40) return;
    final nextIndex = _nextPhraseToEnqueue;
    if (nextIndex == null) return;

    _isRefillingQueue = true;
    try {
      final built = _buildAutoplayQueue(
        startPhraseIndex: nextIndex,
        playMainOnlyFirst: false,
        targetSources: 400,
      );
      if (!_isAutoplay || built.sources.isEmpty) return;
      _queueClips.addAll(built.clips);
      _nextPhraseToEnqueue = built.nextPhraseIndex;
      await _audioPlayer.addAudioSources(built.sources);
    } catch (e) {
      debugPrint('Error refilling audio queue: $e');
    } finally {
      _isRefillingQueue = false;
    }
  }

  Future<void> _playVoice({required bool playMainOnly}) async {
    if (_phraseCounter == null || _playlistPhrases.isEmpty) return;
    final currentPhrase = _playlistPhrases[_phraseCounter!];
    if (currentPhrase.repeat <= 0) {
      if (_isAutoplay) goToNext();
      return;
    }

    final currentToken = _playToken;
    _isPlaying = true;
    notifyListeners();

    try {
      await _activateAudioSession();
      if (!playMainOnly &&
          currentPhrase.voiceSecond != null &&
          currentPhrase.voiceSecond!.isNotEmpty) {
        _isSecondVoicePlaying = true;
        notifyListeners();
        await _setAndPlay(currentPhrase, isSecond: true);
        if (currentToken != _playToken) return;
      } else if (currentPhrase.voice != null && currentPhrase.voice!.isNotEmpty) {
        _isSecondVoicePlaying = false;
        notifyListeners();
        await _setAndPlay(currentPhrase, isSecond: false);
        if (currentToken != _playToken) return;
      } else {
        showNotice('No Voice available');
        _isPlaying = false;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error playing audio: $e');
      showNotice('No Voice available');
      _isPlaying = false;
      notifyListeners();
    }
  }

  void _handleAudioCompleted() {
    if (!_isAutoplay) {
      _isPlaying = false;
      notifyListeners();
      return;
    }
    if (_restartingQueue || _playlistPhrases.isEmpty) return;
    _restartingQueue = true;
    final continueFrom = _nextPhraseToEnqueue ?? _nextPhraseIndex(_phraseCounter ?? 0);
    _phraseCounter = continueFrom;
    _syncRepeatCountersToCurrentPhrase();
    _startAutoplayQueue(playMainOnlyFirst: false).whenComplete(() {
      _restartingQueue = false;
    });
  }

  Future<void> playPhraseVoiceManually(Phrase phrase, {bool isSecond = false}) async {
    _isAutoplay = false;
    _playToken++;
    _queueClips.clear();
    _isSecondVoicePlaying = isSecond;
    _isPlaying = true;
    notifyListeners();
    final audioUrl = isSecond ? phrase.voiceSecond : phrase.voice;
    if (audioUrl == null || audioUrl.isEmpty) {
      showNotice('No Voice available');
      _isPlaying = false;
      notifyListeners();
      return;
    }
    try {
      await _activateAudioSession();
      await _setAndPlay(phrase, isSecond: isSecond);
    } catch (e) {
      debugPrint('Error playing manual voice: $e');
      showNotice('No Voice available');
    }
  }

  Future<void> _setAndPlay(Phrase phrase, {required bool isSecond}) async {
    final key = isSecond ? phrase.voiceSecond : phrase.voice;
    if (key == null || key.isEmpty) return;
    final url = SupabaseService.getPublicUrl(key);
    await _audioPlayer.setAudioSources([
      AudioSource.uri(
        Uri.parse(url),
        tag: _mediaItemFor(phrase, isSecond: isSecond),
      ),
    ]);
    await _audioPlayer.play();
  }

  Future<void> _ensureNotificationPermission() async {
    if (!Platform.isAndroid) return;
    try {
      final status = await Permission.notification.status;
      if (!status.isGranted) {
        await Permission.notification.request();
      }
    } catch (e) {
      debugPrint('Notification permission request failed: $e');
    }
  }

  Future<void> _ensureSilenceFiles() async {
    if (_gapShortPath != null && _gapLongPath != null) return;
    final dir = await getTemporaryDirectory();
    final shortFile = File('${dir.path}/memorize_gap_1700.wav');
    final longFile = File('${dir.path}/memorize_gap_3000.wav');
    if (!await shortFile.exists()) {
      await shortFile.writeAsBytes(_nearSilentWav(const Duration(milliseconds: 1700)));
    }
    if (!await longFile.exists()) {
      await longFile.writeAsBytes(_nearSilentWav(const Duration(seconds: 3)));
    }
    _gapShortPath = shortFile.path;
    _gapLongPath = longFile.path;
  }
}

class _QueuedClip {
  final int phraseIndex;
  final bool isSecondVoice;
  final bool isMissingVoice;

  const _QueuedClip({
    required this.phraseIndex,
    required this.isSecondVoice,
    this.isMissingVoice = false,
  });
}

class _BuiltQueue {
  final List<AudioSource> sources;
  final List<_QueuedClip> clips;
  final int nextPhraseIndex;

  const _BuiltQueue({
    required this.sources,
    required this.clips,
    required this.nextPhraseIndex,
  });
}

Uint8List _nearSilentWav(Duration duration, {int sampleRate = 8000}) {
  final numSamples = (sampleRate * duration.inMilliseconds / 1000).round().clamp(1, 1000000);
  final dataSize = numSamples * 2;
  final bytes = ByteData(44 + dataSize);
  void writeString(int offset, String value) {
    for (var i = 0; i < value.length; i++) {
      bytes.setUint8(offset + i, value.codeUnitAt(i));
    }
  }

  writeString(0, 'RIFF');
  bytes.setUint32(4, 36 + dataSize, Endian.little);
  writeString(8, 'WAVE');
  writeString(12, 'fmt ');
  bytes.setUint32(16, 16, Endian.little);
  bytes.setUint16(20, 1, Endian.little);
  bytes.setUint16(22, 1, Endian.little);
  bytes.setUint32(24, sampleRate, Endian.little);
  bytes.setUint32(28, sampleRate * 2, Endian.little);
  bytes.setUint16(32, 2, Endian.little);
  bytes.setUint16(34, 16, Endian.little);
  writeString(36, 'data');
  bytes.setUint32(40, dataSize, Endian.little);
  for (var i = 0; i < numSamples; i++) {
    final sample = (sin(2 * pi * 20 * i / sampleRate) * 3).round();
    bytes.setInt16(44 + i * 2, sample, Endian.little);
  }
  return bytes.buffer.asUint8List();
}
