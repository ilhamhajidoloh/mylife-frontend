import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class BookSelector extends StatelessWidget {
  final List<dynamic> books;
  final String? selectedBookId;
  final Function(String?) onBookSelected;
  final VoidCallback onManageBooks;

  const BookSelector({
    super.key,
    required this.books,
    required this.selectedBookId,
    required this.onBookSelected,
    required this.onManageBooks,
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
                  _buildBookChip(
                    context,
                    label: 'ทั้งหมด',
                    icon: '📚',
                    isSelected: selectedBookId == null,
                    onTap: () => onBookSelected(null),
                  ),
                  ...books.map((book) => _buildBookChip(
                    context,
                    label: book['name'] ?? '',
                    icon: book['icon'] ?? '📔',
                    color: book['color'] ?? 'violet',
                    isSelected: selectedBookId == book['id'],
                    onTap: () => onBookSelected(book['id']),
                  )),
                ],
              ),
            ),
          ),
          const SizedBox(width: 4),
          IconButton(
            icon: Icon(Icons.settings_outlined, size: 20, color: c.ink3),
            tooltip: 'จัดการสมุดบัญชี',
            onPressed: onManageBooks,
          ),
        ],
      ),
    );
  }

  Widget _buildBookChip(
    BuildContext context, {
    required String label,
    required String icon,
    String? color,
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
