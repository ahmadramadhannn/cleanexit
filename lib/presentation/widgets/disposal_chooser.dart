import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../data/models/models.dart';

/// The three disposal strategies, shown as selectable cards.
/// The user picks one per cleanup run ("Ask each" project decision).
class DisposalChooser extends StatelessWidget {
  final DisposalMethod selected;
  final ValueChanged<DisposalMethod> onChanged;

  const DisposalChooser({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final m in DisposalMethod.values) ...[
          Expanded(
            child: _methodCard(m),
          ),
          if (m != DisposalMethod.values.last) const SizedBox(width: 10),
        ],
      ],
    );
  }

  Widget _methodCard(DisposalMethod m) {
    final isSelected = m == selected;
    final color = switch (m) {
      DisposalMethod.recycle => CeColors.accent,
      DisposalMethod.vault => CeColors.warning,
      DisposalMethod.shred => CeColors.danger,
    };
    return Card(
      color: isSelected ? CeColors.surfaceHigh : CeColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isSelected ? color : CeColors.border,
          width: isSelected ? 1.6 : 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => onChanged(m),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Icon(
                switch (m) {
                  DisposalMethod.recycle => Icons.delete_outline,
                  DisposalMethod.vault => Icons.lock_clock_outlined,
                  DisposalMethod.shred => Icons.local_fire_department_outlined,
                },
                size: 20,
                color: isSelected ? color : CeColors.textSecondary,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  switch (m) {
                    DisposalMethod.recycle => 'Recycle Bin',
                    DisposalMethod.vault => 'Vault',
                    DisposalMethod.shred => 'Shred',
                  },
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: isSelected ? color : CeColors.textPrimary,
                  ),
                ),
              ),
              if (isSelected)
                Icon(Icons.check_circle, size: 16, color: color),
            ],
          ),
        ),
      ),
    );
  }
}

/// Full description text for the selected method (used under the chooser).
Widget disposalDescription(DisposalMethod m) {
  return Text(
    switch (m) {
      DisposalMethod.recycle =>
        'Files go to the OS trash and can be restored until it is emptied.',
      DisposalMethod.vault =>
        'CleanExit hides the files in its vault — restore anything later from History.',
      DisposalMethod.shred =>
        'Files are overwritten with zeroes, then deleted. Nothing comes back.',
    },
    style: const TextStyle(
      fontSize: 12,
      color: CeColors.textSecondary,
      height: 1.45,
    ),
  );
}
