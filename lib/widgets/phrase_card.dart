import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import '../models/phrase.dart';
import '../providers/app_provider.dart';
import '../services/supabase_service.dart';
import '../theme/app_colors.dart';

class PhraseCard extends StatelessWidget {
  final Phrase phrase;
  final int index;

  const PhraseCard({
    super.key,
    required this.phrase,
    required this.index,
  });

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final checked = provider.phraseCheckStates[phrase.id] ?? false;
    final imageUrl = phrase.picture != null && phrase.picture!.isNotEmpty
        ? SupabaseService.getPublicUrl(phrase.picture)
        : null;
    String categoryTitle = 'None';
    if (phrase.categoryId != null) {
      categoryTitle = 'Unknown';
      for (final c in provider.categories) {
        if (c.id == phrase.categoryId) {
          categoryTitle = c.title;
          break;
        }
      }
    }

    return Padding(
      padding: const EdgeInsets.all(4),
      child: Stack(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: AppColors.cardTint,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                GestureDetector(
                  onTap: () => provider.playPhraseVoiceManually(phrase),
                  child: Text(
                    phrase.phrase,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.navy,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      height: 1.25,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                _MiniPlayer(
                  imageUrl: imageUrl,
                  hasVoice: phrase.voice != null && phrase.voice!.isNotEmpty,
                  hasSecond: phrase.voiceSecond != null && phrase.voiceSecond!.isNotEmpty,
                  onPlay: () => provider.playPhraseVoiceManually(phrase),
                  onPlaySecond: () => provider.playPhraseVoiceManually(phrase, isSecond: true),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: [
                    _Badge(
                      text: phrase.mainCategoryId == 2 ? 'Sentence' : 'Phrase',
                      onTap: () {
                        provider.updatePhraseSettings(
                          phrase,
                          mainCategoryId: phrase.mainCategoryId == 1 ? 2 : 1,
                        );
                      },
                    ),
                    _Badge(
                      text: categoryTitle,
                      onTap: () => _pickCategory(context, provider),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                _RepeatRow(
                  label: '',
                  value: phrase.firstRepeat,
                  onChanged: (v) => provider.updatePhraseSettings(phrase, firstRepeat: v),
                ),
                _RepeatRow(
                  label: 'Loop',
                  value: phrase.repeat,
                  onChanged: (v) => provider.updatePhraseSettings(phrase, repeat: v),
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    icon: const Icon(Icons.more_horiz, color: Color(0xFF3988B6), size: 22),
                    onPressed: () => _confirmDelete(context, provider),
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            top: 4,
            right: 4,
            child: GestureDetector(
              onTap: () => provider.togglePhraseInPlaylist(phrase),
              child: Icon(
                Icons.check,
                size: 16,
                color: checked ? AppColors.checkOn : const Color(0xFF666666),
              ),
            ),
          ),
          Positioned(
            right: 8,
            bottom: 4,
            child: Text(
              '${index + 1}',
              style: const TextStyle(color: AppColors.arrow, fontSize: 10),
            ),
          ),
        ],
      ),
    );
  }

  void _pickCategory(BuildContext context, AppProvider provider) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.primary,
      builder: (ctx) {
        return ListView(
          shrinkWrap: true,
          children: [
            ListTile(
              title: const Text('None'),
              onTap: () {
                provider.updatePhraseSettings(phrase, clearCategory: true);
                Navigator.pop(ctx);
              },
            ),
            ...provider.categories.map(
              (c) => ListTile(
                title: Text(c.title),
                selected: phrase.categoryId == c.id,
                onTap: () {
                  provider.updatePhraseSettings(phrase, categoryId: c.id);
                  Navigator.pop(ctx);
                },
              ),
            ),
          ],
        );
      },
    );
  }

  void _confirmDelete(BuildContext context, AppProvider provider) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete'),
        content: Text('Delete "${phrase.phrase}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              provider.deletePhraseFromDatabase(phrase);
              Navigator.pop(ctx);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

class _MiniPlayer extends StatelessWidget {
  final String? imageUrl;
  final bool hasVoice;
  final bool hasSecond;
  final VoidCallback onPlay;
  final VoidCallback onPlaySecond;

  const _MiniPlayer({
    required this.imageUrl,
    required this.hasVoice,
    required this.hasSecond,
    required this.onPlay,
    required this.onPlaySecond,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 140,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: imageUrl != null
                ? CachedNetworkImage(
                    imageUrl: imageUrl!,
                    fit: BoxFit.cover,
                    errorWidget: (_, _, _) => Container(color: AppColors.stageBg),
                  )
                : Container(color: const Color(0xFF2A3A42)),
          ),
          if (hasVoice)
            Center(
              child: GestureDetector(
                onTap: onPlay,
                child: Container(
                  width: 64,
                  height: 64,
                  decoration: const BoxDecoration(
                    color: Color(0x6917171B),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.play_arrow, color: Color(0xFFACEDEd), size: 36),
                ),
              ),
            ),
          if (hasSecond)
            Positioned(
              left: 6,
              bottom: 18,
              child: GestureDetector(
                onTap: onPlaySecond,
                child: Container(
                  width: 34,
                  height: 34,
                  decoration: const BoxDecoration(
                    color: Color(0x6917171B),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.play_arrow, color: Color(0xFFACEDEd), size: 20),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String text;
  final VoidCallback onTap;

  const _Badge({required this.text, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0x4DEBfffc),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              text,
              style: const TextStyle(
                color: Color(0xFF047AAE),
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
            const Icon(Icons.keyboard_arrow_down, size: 12, color: Color(0xFF047AAE)),
          ],
        ),
      ),
    );
  }
}

class _RepeatRow extends StatelessWidget {
  final String label;
  final int value;
  final ValueChanged<int> onChanged;

  const _RepeatRow({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.repeat, size: 14, color: Color(0xFF666666)),
        if (label.isNotEmpty) ...[
          const SizedBox(width: 4),
          Text(label, style: const TextStyle(color: Color(0xFF666666), fontSize: 12)),
        ],
        const SizedBox(width: 4),
        SizedBox(
          width: 32,
          height: 24,
          child: TextFormField(
            initialValue: '$value',
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, color: AppColors.navy),
            decoration: const InputDecoration(
              isDense: true,
              contentPadding: EdgeInsets.zero,
              border: InputBorder.none,
            ),
            onFieldSubmitted: (v) {
              final n = int.tryParse(v);
              if (n != null && n > 0) onChanged(n);
            },
          ),
        ),
      ],
    );
  }
}
