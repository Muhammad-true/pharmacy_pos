import 'package:flutter/material.dart';

class NumericKeypad extends StatelessWidget {
  final Function(String) onKeyPressed;
  final VoidCallback onBackspace;

  const NumericKeypad({
    super.key,
    required this.onKeyPressed,
    required this.onBackspace,
  });

  static const _keys = [
    ['7', '8', '9'],
    ['4', '5', '6'],
    ['1', '2', '3'],
    ['.', '0', '←'],
  ];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final shortestSide =
            constraints.biggest.shortestSide.clamp(200.0, double.infinity);
        final fontSize = shortestSide < 260
            ? 18.0
            : (shortestSide > 360 ? 26.0 : 22.0);
        final spacing = shortestSide < 260 ? 6.0 : 10.0;
        final borderRadius = shortestSide < 260 ? 6.0 : 10.0;

        return Container(
          padding: EdgeInsets.all(spacing / 2),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              for (var rowIndex = 0; rowIndex < _keys.length; rowIndex++) ...[
                if (rowIndex > 0) SizedBox(height: spacing),
                Expanded(
                  child: Row(
                    children: [
                      for (var colIndex = 0;
                          colIndex < _keys[rowIndex].length;
                          colIndex++) ...[
                        if (colIndex > 0) SizedBox(width: spacing),
                        Expanded(
                          child: _buildKey(
                            _keys[rowIndex][colIndex],
                            borderRadius: borderRadius,
                            fontSize: fontSize,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildKey(
    String label, {
    required double borderRadius,
    required double fontSize,
  }) {
    final isBackspace = label == '←';
    final color = isBackspace ? const Color(0xFF1976D2) : Colors.white;
    final textColor = isBackspace ? Colors.white : Colors.black87;

    return Listener(
      onPointerDown: (_) {
        if (isBackspace) {
          onBackspace();
        } else {
          onKeyPressed(label);
        }
      },
      child: Material(
        color: color,
        borderRadius: BorderRadius.circular(borderRadius),
        elevation: 2,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(borderRadius),
            color: color,
          ),
          child: Center(
            child: label == '←'
                ? Icon(
                    Icons.backspace,
                    color: textColor,
                    size: fontSize * 0.9,
                  )
                : Text(
                    label,
                    style: TextStyle(
                      fontSize: fontSize,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
