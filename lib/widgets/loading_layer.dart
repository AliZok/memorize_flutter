import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class LoadingLayer extends StatefulWidget {
  const LoadingLayer({super.key});

  @override
  State<LoadingLayer> createState() => _LoadingLayerState();
}

class _LoadingLayerState extends State<LoadingLayer> with TickerProviderStateMixin {
  static const _row1 = ['M', 'e', 'm', 'o', 'r', 'i', 'z', 'e'];
  static const _row2 = ['M', 'e', '!'];
  late final List<AnimationController> _controllers;
  late final List<Animation<double>> _opacities;
  late final List<Animation<Offset>> _offsets;

  @override
  void initState() {
    super.initState();
    final letters = [..._row1, ..._row2];
    _controllers = List.generate(letters.length, (i) {
      return AnimationController(
        vsync: this,
        duration: const Duration(seconds: 4),
      );
    });
    _opacities = [];
    _offsets = [];
    for (var i = 0; i < letters.length; i++) {
      final c = _controllers[i];
      _opacities.add(TweenSequence<double>([
        TweenSequenceItem(tween: ConstantTween(0), weight: 10),
        TweenSequenceItem(tween: Tween(begin: 0, end: 0.5), weight: 15),
        TweenSequenceItem(tween: ConstantTween(0.5), weight: 10),
        TweenSequenceItem(tween: Tween(begin: 0.5, end: 1), weight: 15),
        TweenSequenceItem(tween: ConstantTween(1), weight: 50),
      ]).animate(CurvedAnimation(parent: c, curve: Curves.easeInOut)));
      _offsets.add(TweenSequence<Offset>([
        TweenSequenceItem(tween: ConstantTween(const Offset(0, 0.45)), weight: 10),
        TweenSequenceItem(
          tween: Tween(begin: const Offset(0, 0.45), end: const Offset(0, -0.12)),
          weight: 15,
        ),
        TweenSequenceItem(tween: ConstantTween(const Offset(0, -0.12)), weight: 10),
        TweenSequenceItem(
          tween: Tween(begin: const Offset(0, -0.12), end: Offset.zero),
          weight: 15,
        ),
        TweenSequenceItem(tween: ConstantTween(Offset.zero), weight: 50),
      ]).animate(CurvedAnimation(parent: c, curve: Curves.easeInOut)));
      Future.delayed(Duration(milliseconds: i * 100), () {
        if (mounted) _controllers[i].repeat();
      });
    }
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  Widget _row(List<String> letters, int offset) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < letters.length; i++)
          FadeTransition(
            opacity: _opacities[offset + i],
            child: SlideTransition(
              position: _offsets[offset + i],
              child: Text(
                letters[i],
                style: const TextStyle(
                  fontSize: 56,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                  height: 1.15,
                  shadows: [
                    Shadow(color: Color(0x80FFFFFF), blurRadius: 20),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          transform: GradientRotation(83 * 3.14159 / 180),
          colors: [AppColors.loadingStart, AppColors.loadingEnd],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _row(_row1, 0),
            _row(_row2, _row1.length),
          ],
        ),
      ),
    );
  }
}
