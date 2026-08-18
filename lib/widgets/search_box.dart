import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class SearchBox extends StatefulWidget {
  final String value;
  final ValueChanged<String> onChanged;

  const SearchBox({
    super.key,
    required this.value,
    required this.onChanged,
  });

  @override
  State<SearchBox> createState() => _SearchBoxState();
}

class _SearchBoxState extends State<SearchBox> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value);
  }

  @override
  void didUpdateWidget(SearchBox oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != _controller.text) {
      _controller.text = widget.value;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: TextField(
        controller: _controller,
        onChanged: widget.onChanged,
        style: const TextStyle(color: Color(0xFF0E0B3B), fontSize: 16),
        decoration: InputDecoration(
          labelText: 'Search Phrase',
          labelStyle: const TextStyle(color: Color(0xFF084A90)),
          filled: true,
          fillColor: AppColors.searchField,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }
}
