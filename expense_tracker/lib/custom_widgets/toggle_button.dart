import 'package:flutter/material.dart';

typedef ToggleCallback = void Function(bool isCredit);

class ToggleButton extends StatefulWidget {
  final ToggleCallback? onToggle;
  final bool initialIsCredit;

  const ToggleButton({super.key, this.onToggle, this.initialIsCredit = false});

  @override
  State<ToggleButton> createState() => _ToggleButtonState();
}

class _ToggleButtonState extends State<ToggleButton> {
  late bool isCredit;

  @override
  void initState() {
    super.initState();
    isCredit = widget.initialIsCredit;
  }

  void _toggle(bool credit) {
    setState(() {
      isCredit = credit;
    });

    if (widget.onToggle != null) {
      widget.onToggle!(isCredit);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final unselectedBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final selectedBg =
        isDark ? const Color(0xFF334155) : Colors.grey.shade700;
    final selectedText = Colors.white;
    final unselectedText =
        isDark ? const Color(0xFFE2E8F0) : Colors.grey.shade700;

    return Container(
      width: 220,
      height: 50,
      decoration: BoxDecoration(
        border: Border.all(
          color: isDark ? const Color(0xFF475569) : Colors.grey.shade400,
        ),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        children: [
          // DEBIT BUTTON
          Expanded(
            child: GestureDetector(
              onTap: () => _toggle(false),
              child: Container(
                color: !isCredit ? selectedBg : unselectedBg,
                child: Center(
                  child: Text(
                    "DEBIT",
                    style: TextStyle(
                      color: !isCredit ? selectedText : unselectedText,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ),

          // CREDIT BUTTON
          Expanded(
            child: GestureDetector(
              onTap: () => _toggle(true),
              child: Container(
                color: isCredit ? selectedBg : unselectedBg,
                child: Center(
                  child: Text(
                    "CREDIT",
                    style: TextStyle(
                      color: isCredit ? selectedText : unselectedText,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
