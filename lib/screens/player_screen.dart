import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../services/supabase_service.dart';
import '../theme/app_colors.dart';
import '../widgets/loading_layer.dart';
import 'categories_tray.dart';
import 'playlist_tray.dart';

class PlayerScreen extends StatefulWidget {
  const PlayerScreen({super.key});

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  bool _categoriesOpen = false;
  bool _playlistOpen = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AppProvider>().addListener(_onNotice);
    });
  }

  void _onNotice() {
    final provider = context.read<AppProvider>();
    final message = provider.notice;
    if (message == null || !mounted) return;
    provider.clearNotice();
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(color: AppColors.navy)),
        backgroundColor: AppColors.primary,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.only(top: 16, right: 16, left: 80),
      ),
    );
  }

  @override
  void dispose() {
    try {
      context.read<AppProvider>().removeListener(_onNotice);
    } catch (_) {}
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final phrase = provider.currentPhrase;
    final imageUrl = phrase?.picture != null && phrase!.picture!.isNotEmpty
        ? SupabaseService.getPublicUrl(phrase.picture)
        : null;

    return Scaffold(
      backgroundColor: AppColors.stageBg,
      body: SafeArea(
        top: false,
        left: false,
        right: false,
        bottom: true,
        child: Stack(
        children: [
          Positioned.fill(
            child: imageUrl != null
                ? CachedNetworkImage(
                    imageUrl: imageUrl,
                    fit: BoxFit.contain,
                    alignment: Alignment.center,
                    placeholder: (_, _) => const ColoredBox(color: AppColors.stageBg),
                    errorWidget: (_, _, _) => const ColoredBox(color: AppColors.stageBg),
                  )
                : const ColoredBox(color: AppColors.stageBg),
          ),
          if (phrase != null && !_playlistOpen)
            Positioned(
              top: MediaQuery.of(context).padding.top + 8,
              left: 64,
              right: 64,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.titleBg,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    phrase.phrase,
                    textAlign: TextAlign.center,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.titleText,
                      fontSize: 45,
                      fontWeight: FontWeight.bold,
                      height: 1.1,
                      shadows: [
                        Shadow(offset: Offset(5, 3), blurRadius: 8, color: Color(0xFF192023)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          if (phrase == null && !provider.isLoading && !_playlistOpen)
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
                decoration: BoxDecoration(
                  color: const Color(0x8C111B1F),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.queue_music, color: AppColors.titleText, size: 48),
                    const SizedBox(height: 6),
                    Text(
                      provider.selectedPlaylist != null
                          ? '"${provider.selectedPlaylist!.title}" is empty'
                          : 'No playlist selected',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: AppColors.titleText,
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Add phrases to it from the playlist panel',
                      style: TextStyle(color: AppColors.titleText, fontSize: 14),
                    ),
                  ],
                ),
              ),
            ),
          Positioned(
            left: 0,
            bottom: 0,
            width: 80,
            height: 135,
            child: GestureDetector(
              onTap: () => provider.goToPrevious(playMain: true),
              child: Container(
                decoration: const BoxDecoration(
                  color: Color(0x088CA6A3),
                  borderRadius: BorderRadius.only(topRight: Radius.circular(20)),
                ),
                child: const Icon(Icons.chevron_left, color: AppColors.arrow, size: 50),
              ),
            ),
          ),
          Positioned(
            right: 0,
            bottom: 0,
            width: 80,
            height: 135,
            child: GestureDetector(
              onTap: () => provider.goToNext(playMain: true),
              child: Container(
                decoration: const BoxDecoration(
                  color: Color(0x088CA6A3),
                  borderRadius: BorderRadius.only(topLeft: Radius.circular(20)),
                ),
                child: const Icon(Icons.chevron_right, color: AppColors.arrow, size: 50),
              ),
            ),
          ),
          if (!_playlistOpen)
            Positioned(
              top: MediaQuery.of(context).padding.top + 10,
              left: 5,
              child: Column(
                children: [
                  _SideButton(
                    icon: Icons.folder_copy_outlined,
                    onTap: () => setState(() => _categoriesOpen = true),
                  ),
                  const SizedBox(height: 8),
                  _SideButton(
                    icon: Icons.play_arrow,
                    playing: provider.isAutoplay,
                    onTap: provider.togglePlay,
                  ),
                ],
              ),
            ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            right: 5,
            child: GestureDetector(
              onTap: () => setState(() => _playlistOpen = true),
              child: provider.selectedPlaylist?.image != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: CachedNetworkImage(
                        imageUrl: provider.selectedPlaylist!.image!,
                        width: 50,
                        height: 50,
                        fit: BoxFit.cover,
                      ),
                    )
                  : const Icon(Icons.queue_music, color: Color(0xB3FFFFFF), size: 50),
            ),
          ),
          AnimatedPositioned(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
            top: _categoriesOpen ? 0 : -MediaQuery.of(context).size.height,
            left: 0,
            right: 0,
            bottom: _categoriesOpen ? 0 : null,
            height: _categoriesOpen ? null : MediaQuery.of(context).size.height,
            child: CategoriesTray(
              onClose: () => setState(() => _categoriesOpen = false),
              onOpenPlaylist: () => setState(() {
                _categoriesOpen = false;
                _playlistOpen = true;
              }),
            ),
          ),
          AnimatedPositioned(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
            top: _playlistOpen ? 0 : -MediaQuery.of(context).size.height,
            left: 0,
            right: 0,
            bottom: _playlistOpen ? 0 : null,
            height: _playlistOpen ? null : MediaQuery.of(context).size.height,
            child: PlaylistTray(
              onClose: () => setState(() => _playlistOpen = false),
            ),
          ),
          if (provider.isLoading) const Positioned.fill(child: LoadingLayer()),
        ],
        ),
      ),
    );
  }
}

class _SideButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool playing;

  const _SideButton({
    required this.icon,
    required this.onTap,
    this.playing = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: playing ? AppColors.playGreenBg : AppColors.sideBtn,
      borderRadius: BorderRadius.circular(16),
      elevation: 8,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: SizedBox(
          width: 48,
          height: 48,
          child: Icon(
            icon,
            color: playing ? AppColors.playGreenIcon : AppColors.grayIcon,
            size: 28,
          ),
        ),
      ),
    );
  }
}
