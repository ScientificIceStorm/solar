import 'package:flutter/material.dart';

class SolarSegmentedControlOption<T> {
  const SolarSegmentedControlOption({
    required this.value,
    required this.label,
    this.icon,
  });

  final T value;
  final String label;
  final IconData? icon;
}

class SolarSegmentedControl<T> extends StatelessWidget {
  const SolarSegmentedControl({
    required this.options,
    required this.selectedValue,
    required this.onSelected,
    super.key,
    this.padding = const EdgeInsets.all(4),
    this.backgroundColor = const Color(0xFFF1F0F5),
    this.selectedColor = Colors.white,
    this.selectedTextColor = const Color(0xFF16182C),
    this.unselectedTextColor = const Color(0xFF6F748B),
    this.borderRadius = 22,
    this.itemBorderRadius = 18,
    this.compact = false,
  });

  final List<SolarSegmentedControlOption<T>> options;
  final T selectedValue;
  final ValueChanged<T> onSelected;
  final EdgeInsetsGeometry padding;
  final Color backgroundColor;
  final Color selectedColor;
  final Color selectedTextColor;
  final Color unselectedTextColor;
  final double borderRadius;
  final double itemBorderRadius;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      child: Row(
        children: options
            .map((option) {
              final selected = option.value == selectedValue;
              return Expanded(
                child: GestureDetector(
                  onTap: () => onSelected(option.value),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOutCubic,
                    padding: EdgeInsets.symmetric(
                      horizontal: compact ? 10 : 12,
                      vertical: compact ? 10 : 13,
                    ),
                    decoration: BoxDecoration(
                      color: selected ? selectedColor : Colors.transparent,
                      borderRadius: BorderRadius.circular(itemBorderRadius),
                      boxShadow: selected
                          ? const <BoxShadow>[
                              BoxShadow(
                                color: Color(0x12000000),
                                blurRadius: 16,
                                offset: Offset(0, 8),
                              ),
                            ]
                          : const <BoxShadow>[],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        if (option.icon != null) ...<Widget>[
                          Icon(
                            option.icon,
                            size: compact ? 16 : 18,
                            color: selected
                                ? selectedTextColor
                                : unselectedTextColor,
                          ),
                          const SizedBox(width: 6),
                        ],
                        Flexible(
                          child: Text(
                            option.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: selected
                                  ? selectedTextColor
                                  : unselectedTextColor,
                              fontSize: compact ? 12 : 14,
                              fontWeight: selected
                                  ? FontWeight.w800
                                  : FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            })
            .toList(growable: false),
      ),
    );
  }
}
