import 'package:flutter/material.dart';
import '../models/nexus_image.dart';

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
    // Group facets by type, filter zero counts
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Color(0xFF2A2A4A)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'CATEGORY',
            style: TextStyle(
              fontSize: 10,
              color: Color(0xFF666666),
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: top.map((item) {
              final isActive =
                  activeFacets['category']?.contains(item.value) ?? false;
              return GestureDetector(
                onTap: () => onToggle('category', item.value),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: isActive
                        ? const Color(0xFFD35400)
                        : const Color(0xFF1A1A2E),
                    border: Border.all(
                      color: isActive
                          ? const Color(0xFFD35400)
                          : const Color(0xFF2A2A4A),
                    ),
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        item.value,
                        style: TextStyle(
                          fontSize: 12,
                          color: isActive ? Colors.white : const Color(0xFFCCCCCC),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        item.count.toString(),
                        style: TextStyle(
                          fontSize: 10,
                          color: isActive
                              ? Colors.white70
                              : const Color(0xFF888888),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
