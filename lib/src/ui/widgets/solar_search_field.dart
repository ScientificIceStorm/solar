import 'package:flutter/material.dart';

enum SolarSearchFieldTone { light, chrome, embedded }

class SolarSearchField extends StatelessWidget {
  const SolarSearchField({
    required this.controller,
    required this.hintText,
    super.key,
    this.onChanged,
    this.resultCount,
    this.textInputAction = TextInputAction.search,
    this.prefixIcon = Icons.search_rounded,
    this.tone = SolarSearchFieldTone.light,
    this.horizontalPadding = 16,
    this.verticalPadding = 8,
    this.borderRadius = 22,
  });

  final TextEditingController controller;
  final String hintText;
  final ValueChanged<String>? onChanged;
  final int? resultCount;
  final TextInputAction textInputAction;
  final IconData prefixIcon;
  final SolarSearchFieldTone tone;
  final double horizontalPadding;
  final double verticalPadding;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final isChrome = tone == SolarSearchFieldTone.chrome;
    final isEmbedded = tone == SolarSearchFieldTone.embedded;
    final containerColor = isChrome
        ? Colors.white.withValues(alpha: 0.12)
        : isEmbedded
        ? Colors.transparent
        : Colors.white.withValues(alpha: 0.96);
    final borderColor = isChrome
        ? Colors.white.withValues(alpha: 0.10)
        : isEmbedded
        ? const Color(0xFFDADDEA)
        : const Color(0xFFE0E4F0);
    final iconColor = isChrome
        ? Colors.white.withValues(alpha: 0.72)
        : const Color(0xFF5F6478);
    final textColor = isChrome ? Colors.white : const Color(0xFF181A33);
    final hintColor = isChrome
        ? Colors.white.withValues(alpha: 0.42)
        : const Color(0xFF8E92A7);
    final badgeColor = isChrome
        ? Colors.white.withValues(alpha: 0.14)
        : isEmbedded
        ? const Color(0xFFF3F4F8)
        : const Color(0xFFF1F3F9);
    final badgeTextColor = isChrome
        ? Colors.white.withValues(alpha: 0.84)
        : const Color(0xFF6F748B);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: horizontalPadding,
        vertical: verticalPadding,
      ),
      decoration: BoxDecoration(
        color: containerColor,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: borderColor),
        boxShadow: isChrome || isEmbedded
            ? const <BoxShadow>[]
            : const <BoxShadow>[
                BoxShadow(
                  color: Color(0x12000000),
                  blurRadius: 18,
                  offset: Offset(0, 10),
                ),
              ],
      ),
      child: Row(
        children: <Widget>[
          Icon(prefixIcon, color: iconColor, size: isEmbedded ? 18 : 20),
          SizedBox(width: isEmbedded ? 10 : 12),
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              textInputAction: textInputAction,
              cursorColor: textColor,
              decoration: InputDecoration(
                isCollapsed: true,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                hintText: hintText,
                hintStyle: TextStyle(
                  color: hintColor,
                  fontSize: isEmbedded ? 13 : 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              style: TextStyle(
                color: textColor,
                fontSize: isEmbedded ? 13 : 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          if (controller.text.trim().isNotEmpty) ...<Widget>[
            const SizedBox(width: 8),
            InkWell(
              onTap: () {
                controller.clear();
                onChanged?.call('');
              },
              borderRadius: BorderRadius.circular(999),
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Icon(Icons.close_rounded, color: iconColor, size: 18),
              ),
            ),
          ],
          if (resultCount != null) ...<Widget>[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: badgeColor,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                '$resultCount',
                style: TextStyle(
                  color: badgeTextColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
