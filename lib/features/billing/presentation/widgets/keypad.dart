import 'package:flutter/material.dart';

class KeypadButton extends StatelessWidget {
  const KeypadButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.backgroundColor,
    this.foregroundColor,
    this.fontSize = 28,
  });

  final String label;
  final VoidCallback onPressed;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      height: 64,
      child: Material(
        color: backgroundColor ?? scheme.surface,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onPressed,
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: fontSize,
                fontWeight: FontWeight.w700,
                color: foregroundColor ?? scheme.onSurface,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The action row of the keypad (multiply + NEXT ITEM).
class ActionRow extends StatelessWidget {
  const ActionRow({
    super.key,
    required this.onMultiply,
    required this.onNextItem,
  });

  final VoidCallback onMultiply;
  final VoidCallback onNextItem;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Expanded(
          child: KeypadButton(
            label: '×',
            onPressed: onMultiply,
            backgroundColor: scheme.primaryContainer,
            foregroundColor: scheme.onPrimaryContainer,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: 2,
          child: KeypadButton(
            label: '+ NEXT ITEM',
            onPressed: onNextItem,
            backgroundColor: scheme.primary,
            foregroundColor: scheme.onPrimary,
            fontSize: 22,
          ),
        ),
      ],
    );
  }
}