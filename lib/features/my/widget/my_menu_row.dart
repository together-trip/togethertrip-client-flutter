import 'package:flutter/material.dart';

import '../../../core/widget/app_design.dart';

class MyMenuRow extends StatelessWidget {
  const MyMenuRow({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.labelColor = AppColors.ink,
  });

  final IconData icon;
  final String label;
  final Color labelColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        child: Row(
          children: [
            Icon(icon, size: 20, color: labelColor),
            const SizedBox(width: 12),
            Text(label, style: TextStyle(fontSize: 13, color: labelColor)),
            const Spacer(),
            const Icon(Icons.chevron_right, size: 22, color: Color(0xFF9E9E9E)),
          ],
        ),
      ),
    );
  }
}
