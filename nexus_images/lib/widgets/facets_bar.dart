import 'package:flutter/material.dart';
import '../models/nexus_image.dart';
import '../theme.dart';

class FacetsBar extends StatelessWidget {
  final List<FacetItem> facets;
  final Map<String, Set<String>> activeFacets;
  final void Function(String facetName, String value) onToggle;

  const FacetsBar({
    super.key,
    required this.facets,
    required this.activeFacets,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final groups = <String, List<FacetItem>>{};
    for (final f in facets) {
      if (f.count == 0) continue;
      groups.putIfAbsent(f.facet, () => []).add(f);
    }

    final categoryItems = groups['category'];
    if (categoryItems == null || categoryItems.isEmpty) {
      return const SizedBox.shrink();
    }

    categoryItems.sort((a, b) => b.count.compareTo(a.count));
    final top = categoryItems.take(10).toList();

    return Container(
      height: 100,
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: const BoxDecoration(
        color: NexusColors.surface,
        border: Border(
          bottom: BorderSide(color: NexusColors.border, width: 0.5),
        ),
      ),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: top.length,
        separatorBuilder: (_, __) => const SizedBox(width: 16),
        itemBuilder: (_, i) {
          final item = top[i];
          final isActive =
              activeFacets['category']?.contains(item.value) ?? false;
          return GestureDetector(
            onTap: () => onToggle('category', item.value),
            child: SizedBox(
              width: 68,
              child: Column(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: isActive
                          ? const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                NexusColors.primary,
                                NexusColors.primaryLight,
                              ],
                            )
                          : null,
                      color: isActive ? null : NexusColors.background,
                      border: Border.all(
                        color: isActive
                            ? Colors.transparent
                            : NexusColors.border,
                        width: 2,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        item.value.isNotEmpty
                            ? item.value[0].toUpperCase()
                            : '?',
                        style: TextStyle(
                          color: isActive
                              ? NexusColors.textPrimary
                              : NexusColors.textMuted,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.value,
                    style: TextStyle(
                      fontSize: 10,
                      color: isActive
                          ? NexusColors.textPrimary
                          : NexusColors.textMuted,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
