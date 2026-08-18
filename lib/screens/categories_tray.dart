import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import '../models/category.dart';
import '../providers/app_provider.dart';
import '../theme/app_colors.dart';
import '../widgets/phrase_card.dart';
import '../widgets/search_box.dart';
import 'phrase_creator_panel.dart';

class CategoriesTray extends StatelessWidget {
  final VoidCallback onClose;
  final VoidCallback onOpenPlaylist;

  const CategoriesTray({
    super.key,
    required this.onClose,
    required this.onOpenPlaylist,
  });

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final selected = provider.selectedPlaylist;

    return Material(
      color: AppColors.secondary,
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(56, 8, 58, 0),
              child: SearchBox(
                value: provider.searchPhrase,
                onChanged: provider.setSearchPhrase,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Column(
                    children: [
                      _TrayIconButton(
                        icon: Icons.upload,
                        onTap: () => _openCreator(context),
                      ),
                      const SizedBox(height: 8),
                      _TrayIconButton(
                        icon: Icons.menu,
                        onTap: () => _openRandomMenu(context, provider),
                      ),
                      const SizedBox(height: 8),
                      _TrayIconButton(
                        icon: Icons.mic,
                        color: const Color(0xFFFFADE2),
                        iconColor: Colors.white,
                        onTap: () => _openCreator(context),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Column(
                    children: [
                      _TrayIconButton(
                        icon: Icons.close,
                        color: AppColors.closePink,
                        onTap: onClose,
                      ),
                      const SizedBox(height: 8),
                      GestureDetector(
                        onTap: onOpenPlaylist,
                        child: Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            gradient: const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [Color(0xB8FFFFFF), Color(0x73EBFFFC)],
                            ),
                            border: Border.all(
                              color: selected != null
                                  ? const Color(0xA6C6FF50)
                                  : const Color(0x473988B6),
                              width: 1.5,
                            ),
                            image: selected?.image != null
                                ? DecorationImage(
                                    image: CachedNetworkImageProvider(selected!.image!),
                                    fit: BoxFit.cover,
                                  )
                                : null,
                          ),
                          child: selected?.image == null
                              ? const Icon(Icons.queue_music, color: Color(0xFF3988B6), size: 28)
                              : null,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: _CategorySelect(provider: provider),
            ),
            if (provider.selectedPhraseCategory != null) ...[
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: _PhraseSentenceSwitch(provider: provider),
              ),
            ],
            const SizedBox(height: 8),
            Expanded(
              child: provider.searchPhrase.isNotEmpty && provider.libraryPhrases.isEmpty
                  ? Center(
                      child: Text(
                        'No phrases found matching "${provider.searchPhrase}"',
                        style: const TextStyle(color: AppColors.navy, fontWeight: FontWeight.w600),
                      ),
                    )
                  : GridView.builder(
                      padding: const EdgeInsets.fromLTRB(4, 8, 4, 24),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        childAspectRatio: 0.62,
                        crossAxisSpacing: 4,
                        mainAxisSpacing: 8,
                      ),
                      itemCount: provider.libraryPhrases.length,
                      itemBuilder: (context, index) {
                        return PhraseCard(
                          phrase: provider.libraryPhrases[index],
                          index: index,
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  void _openCreator(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const PhraseCreatorPanel(),
    );
  }

  void _openRandomMenu(BuildContext context, AppProvider provider) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.primary,
        content: TextButton(
          onPressed: () {
            provider.toggleRandom();
            Navigator.pop(ctx);
          },
          style: TextButton.styleFrom(
            backgroundColor: provider.isRandom ? AppColors.accent : Colors.transparent,
            foregroundColor: provider.isRandom ? Colors.white : AppColors.navy,
          ),
          child: const Text('RANDOMLY'),
        ),
      ),
    );
  }
}

class _TrayIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final Color color;
  final Color iconColor;

  const _TrayIconButton({
    required this.icon,
    required this.onTap,
    this.color = Colors.indigo,
    this.iconColor = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(12),
      elevation: 8,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          width: 48,
          height: 48,
          child: Icon(icon, color: iconColor),
        ),
      ),
    );
  }
}

class _CategorySelect extends StatelessWidget {
  final AppProvider provider;
  const _CategorySelect({required this.provider});

  @override
  Widget build(BuildContext context) {
    final selected = provider.selectedPhraseCategory;
    return GestureDetector(
      onTap: () => _open(context),
      child: Container(
        padding: const EdgeInsets.fromLTRB(7, 7, 10, 7),
        decoration: BoxDecoration(
          color: const Color(0x4CFFFFFF),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0x473988B6)),
        ),
        child: Row(
          children: [
            _thumb(selected),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Category', style: TextStyle(fontSize: 10, color: Color(0xFF047AAE))),
                  Text(
                    selected == null
                        ? 'Choose one…'
                        : (selected.id == -1 ? 'None' : selected.title),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.navyDeep,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.keyboard_arrow_down, color: Color(0xFF3988B6)),
          ],
        ),
      ),
    );
  }

  Widget _thumb(Category? selected) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        width: 34,
        height: 34,
        child: selected?.image != null
            ? CachedNetworkImage(imageUrl: selected!.image!, fit: BoxFit.cover)
            : Container(
                color: const Color(0x945AB3D0),
                alignment: Alignment.center,
                child: Text(selected?.id == -1 ? '📄' : '📁', style: const TextStyle(fontSize: 16)),
              ),
      ),
    );
  }

  void _open(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.primary,
      builder: (ctx) {
        return ListView(
          shrinkWrap: true,
          children: [
            ListTile(
              leading: const Text('📄', style: TextStyle(fontSize: 22)),
              title: const Text('None'),
              onTap: () {
                provider.selectNoCategory();
                Navigator.pop(ctx);
              },
            ),
            ...provider.categories.map(
              (c) => ListTile(
                leading: c.image != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: CachedNetworkImage(imageUrl: c.image!, width: 34, height: 34, fit: BoxFit.cover),
                      )
                    : const Text('📁', style: TextStyle(fontSize: 22)),
                title: Text(c.title),
                selected: provider.selectedPhraseCategory?.id == c.id,
                onTap: () {
                  provider.selectPhraseCategory(c);
                  Navigator.pop(ctx);
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

class _PhraseSentenceSwitch extends StatelessWidget {
  final AppProvider provider;
  const _PhraseSentenceSwitch({required this.provider});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0x57F5F5F5),
        borderRadius: BorderRadius.circular(25),
      ),
      child: Row(
        children: provider.mainCategories.map((mc) {
          final active = provider.selectedMainCategory?.id == mc.id;
          return Expanded(
            child: GestureDetector(
              onTap: () => provider.selectMainCategory(mc),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                decoration: BoxDecoration(
                  color: active ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  mc.title.toUpperCase(),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                    color: active ? AppColors.navy : const Color(0xFF666666),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
