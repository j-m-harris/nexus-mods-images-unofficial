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
        color: Color(0xFF16213E),
        border: Border(
          bottom: BorderSide(color: Color(0xFF2A2A4A), width: 0.5),
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
                  // Circle icon (stories-style)
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
                                Color(0xFFD35400),
                                Color(0xFFE67E22),
                              ],
                            )
                          : null,
                      color: isActive ? null : const Color(0xFF1A1A2E),
                      border: Border.all(
                        color: isActive
                            ? Colors.transparent
                            : const Color(0xFF2A2A4A),
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
                              ? Colors.white
                              : const Color(0xFF888888),
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  // Label
                  Text(
                    item.value,
                    style: TextStyle(
                      fontSize: 10,
                      color: isActive
                          ? const Color(0xFFE0E0E0)
                          : const Color(0xFF888888),
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
