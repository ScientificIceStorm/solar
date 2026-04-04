import 'package:flutter/material.dart';

class SolarTextField extends StatefulWidget {
  const SolarTextField({
    required this.controller,
    required this.hintText,
    required this.icon,
    super.key,
    this.keyboardType,
    this.textInputAction,
    this.obscureText = false,
  });

  final TextEditingController controller;
  final String hintText;
  final IconData icon;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final bool obscureText;

  @override
  State<SolarTextField> createState() => _SolarTextFieldState();
}

class _SolarTextFieldState extends State<SolarTextField> {
  late bool _obscured = widget.obscureText;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: widget.controller,
      keyboardType: widget.keyboardType,
      textInputAction: widget.textInputAction,
      obscureText: _obscured,
      decoration: InputDecoration(
        hintText: widget.hintText,
        prefixIcon: Icon(widget.icon, size: 20, color: const Color(0xFF8E92A7)),
        suffixIcon: widget.obscureText
            ? IconButton(
                onPressed: () {
                  setState(() {
                    _obscured = !_obscured;
                  });
                },
                icon: Icon(
                  _obscured
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  color: const Color(0xFF8E92A7),
                ),
              )
            : null,
      ),
    );
  }
}
