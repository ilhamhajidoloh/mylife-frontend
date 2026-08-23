import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class TermSelector extends StatelessWidget {
  final List<dynamic> terms;
  final String? selectedTermId;
  final Function(String?) onTermSelected;
  final VoidCallback onManageTerms;

  const TermSelector({
    super.key,
    required this.terms,
    required this.selectedTermId,
    required this.onTermSelected,
    required this.onManageTerms,
  });

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<AppColors>()!;

    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: c.surface2,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildTermChip(
                    context,
                    label: 'ทั้งหมด',
                    icon: '📚',
                    isSelected: selectedTermId == null,
                    onTap: () => onTermSelected(null),
                  ),
                  ...terms.map((term) => _buildTermChip(
                    context,
                    label: term['termName'] ?? term['name'] ?? '',
                    icon: '📖',
                    isSelected: selectedTermId == term['id'],
                    onTap: () => onTermSelected(term['id']),
                  )),
                ],
              ),
            ),
          ),
          const SizedBox(width: 4),
          IconButton(
            icon: Icon(Icons.settings_outlined, size: 20, color: c.ink3),
            tooltip: 'จัดการภาคเรียน',
            onPressed: onManageTerms,
          ),
        ],
      ),
    );
  }

  Widget _buildTermChip(
    BuildContext context, {
    required String label,
    required String icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final c = Theme.of(context).extension<AppColors>()!;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? c.accent : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                icon,
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  color: isSelected ? Colors.white : c.ink2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
