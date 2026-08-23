import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';

class MemorizeAudioHandler extends BaseAudioHandler {
  static MemorizeAudioHandler? instance;

  AudioPlayer? _player;
  StreamSubscription? _eventSub;
  StreamSubscription? _playingSub;
  void Function()? onPlay;
  void Function()? onPause;
  void Function()? onStop;
  void Function()? onSkipNext;
  void Function()? onSkipPrevious;

  MemorizeAudioHandler() {
    instance = this;
    playbackState.add(PlaybackState(
      controls: const [
        MediaControl.skipToPrevious,
        MediaControl.play,
        MediaControl.skipToNext,
      ],
      systemActions: const {
        MediaAction.seek,
        MediaAction.seekForward,
        MediaAction.seekBackward,
      },
      androidCompactActionIndices: const [0, 1, 2],
      processingState: AudioProcessingState.idle,
      playing: false,
    ));
  }

  void attachPlayer(AudioPlayer player) {
    _eventSub?.cancel();
    _playingSub?.cancel();
    _player = player;
    _eventSub = player.playbackEventStream.listen((_) => broadcast());
    _playingSub = player.playingStream.listen((_) => broadcast());
    broadcast();
  }

  void setCurrentMediaItem(MediaItem item) {
    mediaItem.add(item);
  }

  void broadcast() {
    final player = _player;
    if (player == null) return;
    final playing = player.playing;
    playbackState.add(PlaybackState(
      controls: [
        MediaControl.skipToPrevious,
        if (playing) MediaControl.pause else MediaControl.play,
        MediaControl.skipToNext,
      ],
      systemActions: const {
        MediaAction.seek,
        MediaAction.seekForward,
        MediaAction.seekBackward,
      },
      androidCompactActionIndices: const [0, 1, 2],
      processingState: _toAudioProcessingState(player.processingState),
      playing: playing,
      updatePosition: player.position,
      bufferedPosition: player.bufferedPosition,
      speed: player.speed,
      queueIndex: player.currentIndex,
    ));
  }

  AudioProcessingState _toAudioProcessingState(ProcessingState state) {
    switch (state) {
      case ProcessingState.idle:
        return AudioProcessingState.idle;
      case ProcessingState.loading:
        return AudioProcessingState.loading;
      case ProcessingState.buffering:
        return AudioProcessingState.buffering;
      case ProcessingState.ready:
        return AudioProcessingState.ready;
      case ProcessingState.completed:
        return AudioProcessingState.completed;
    }
  }

  @override
  Future<void> play() async {
    onPlay?.call();
    if (_player != null && !_player!.playing) {
      await _player!.play();
    }
  }

  @override
  Future<void> pause() async {
    onPause?.call();
  }

  @override
  Future<void> stop() async {
    onStop?.call();
    await super.stop();
  }

  @override
  Future<void> skipToNext() async {
    onSkipNext?.call();
  }

  @override
  Future<void> skipToPrevious() async {
    onSkipPrevious?.call();
  }

  @override
  Future<void> seek(Duration position) async {
    await _player?.seek(position);
  }
}
