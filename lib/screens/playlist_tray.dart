import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import '../models/playlist.dart';
import '../providers/app_provider.dart';
import '../theme/app_colors.dart';
import '../widgets/phrase_card.dart';

class PlaylistTray extends StatefulWidget {
  final VoidCallback onClose;

  const PlaylistTray({super.key, required this.onClose});

  @override
  State<PlaylistTray> createState() => _PlaylistTrayState();
}

class _PlaylistTrayState extends State<PlaylistTray> {
  bool _creating = false;
  final _titleController = TextEditingController();
  File? _cover;
  Playlist? _pendingDelete;

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();

    return Material(
      color: AppColors.secondary,
      child: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.only(top: 8, right: 8),
                child: Material(
                  color: AppColors.closePink,
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    onTap: widget.onClose,
                    borderRadius: BorderRadius.circular(12),
                    child: const SizedBox(
                      width: 48,
                      height: 48,
                      child: Icon(Icons.close, color: Colors.white),
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(6),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0x38EBFFFC),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Material(
                          color: AppColors.addPlaylist,
                          borderRadius: BorderRadius.circular(10),
                          elevation: 6,
                          child: InkWell(
                            onTap: () => setState(() => _creating = true),
                            borderRadius: BorderRadius.circular(10),
                            child: const SizedBox(
                              width: 48,
                              height: 48,
                              child: Icon(Icons.add, color: Color(0xFF122382), size: 28),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          if (_creating) _draftCard(provider),
                          ...provider.playlists.map((p) => _playlistCard(provider, p)),
                        ],
                      ),
                      if (provider.playlists.isEmpty && !_creating)
                        const Padding(
                          padding: EdgeInsets.all(28),
                          child: Text(
                            'No playlists yet — press + to create your first one',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: AppColors.navy,
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      if (provider.selectedPlaylist != null) ...[
                        const SizedBox(height: 16),
                        Text.rich(
                          TextSpan(
                            children: [
                              const TextSpan(
                                text: 'Playlist: ',
                                style: TextStyle(
                                  color: AppColors.navy,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 18,
                                ),
                              ),
                              TextSpan(
                                text: provider.selectedPlaylist!.title,
                                style: const TextStyle(
                                  color: AppColors.navyDeep,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 29,
                                ),
                              ),
                            ],
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        if (provider.playlistPhrases.isEmpty)
                          const Padding(
                            padding: EdgeInsets.all(16),
                            child: Text('This playlist is empty', style: TextStyle(color: AppColors.navy)),
                          )
                        else
                          GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              childAspectRatio: 0.62,
                              crossAxisSpacing: 4,
                              mainAxisSpacing: 8,
                            ),
                            itemCount: provider.playlistPhrases.length,
                            itemBuilder: (context, index) {
                              return PhraseCard(
                                phrase: provider.playlistPhrases[index],
                                index: index,
                              );
                            },
                          ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _draftCard(AppProvider provider) {
    return SizedBox(
      width: (MediaQuery.of(context).size.width / 2) - 20,
      child: GestureDetector(
        onTap: () async {
          final file = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 70);
          if (file != null) setState(() => _cover = File(file.path));
        },
        child: Container(
          height: 130,
          decoration: BoxDecoration(
            color: const Color(0xCC5AB3D0),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.lime, width: 2),
            image: _cover != null ? DecorationImage(image: FileImage(_cover!), fit: BoxFit.cover) : null,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_cover == null) ...[
                const Icon(Icons.add_photo_alternate, color: Colors.white, size: 40),
                const Text('Click to upload', style: TextStyle(color: Colors.white, fontSize: 13)),
              ],
              Padding(
                padding: const EdgeInsets.all(6),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _titleController,
                        style: const TextStyle(color: Colors.white, fontSize: 14),
                        decoration: const InputDecoration(
                          hintText: 'Playlist name',
                          hintStyle: TextStyle(color: Colors.white70, fontSize: 13),
                          isDense: true,
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.check, color: Colors.white, size: 18),
                      onPressed: provider.isBusy
                          ? null
                          : () async {
                              final title = _titleController.text.trim();
                              if (title.isEmpty) return;
                              await provider.createNewPlaylist(title, _cover);
                              setState(() {
                                _creating = false;
                                _cover = null;
                                _titleController.clear();
                              });
                            },
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white, size: 18),
                      onPressed: () => setState(() {
                        _creating = false;
                        _cover = null;
                        _titleController.clear();
                      }),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _playlistCard(AppProvider provider, Playlist playlist) {
    final active = provider.selectedPlaylist?.id == playlist.id;
    final empty = provider.isPlaylistEmpty(playlist);
    final asking = _pendingDelete?.id == playlist.id;

    return GestureDetector(
      onTap: () => provider.selectPlaylist(playlist),
      child: AnimatedScale(
        scale: active ? 1 : 0.6,
        duration: const Duration(milliseconds: 200),
        child: SizedBox(
          width: (MediaQuery.of(context).size.width / 2) - 20,
          child: Container(
            height: 130,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              boxShadow: active
                  ? [const BoxShadow(color: AppColors.lime, blurRadius: 0, spreadRadius: 3)]
                  : null,
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              fit: StackFit.expand,
              children: [
                playlist.image != null
                    ? CachedNetworkImage(
                        imageUrl: playlist.image!,
                        fit: BoxFit.cover,
                        color: active ? null : Colors.black26,
                        colorBlendMode: active ? null : BlendMode.darken,
                      )
                    : Container(
                        color: const Color(0x945AB3D0),
                        alignment: Alignment.center,
                        child: const Text('🎵', style: TextStyle(fontSize: 32)),
                      ),
                Positioned(
                  top: 10,
                  left: 0,
                  right: 0,
                  child: Container(
                    color: active ? const Color(0x80000000) : const Color(0x66000000),
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    child: Text(
                      playlist.title,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: active ? AppColors.lime : Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: active ? 18 : 16,
                      ),
                    ),
                  ),
                ),
                if (empty)
                  Positioned(
                    bottom: 4,
                    right: 4,
                    child: asking
                        ? Row(
                            children: [
                              const Text('Delete?', style: TextStyle(color: Colors.white, fontSize: 11)),
                              IconButton(
                                icon: const Icon(Icons.check, color: Colors.white, size: 16),
                                onPressed: () {
                                  provider.deletePlaylist(playlist);
                                  setState(() => _pendingDelete = null);
                                },
                              ),
                              IconButton(
                                icon: const Icon(Icons.close, color: Colors.white, size: 16),
                                onPressed: () => setState(() => _pendingDelete = null),
                              ),
                            ],
                          )
                        : IconButton(
                            icon: const Icon(Icons.delete, color: Colors.white, size: 16),
                            onPressed: () => setState(() => _pendingDelete = playlist),
                          ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
