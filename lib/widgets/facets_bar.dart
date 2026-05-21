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

  String _formatCount(int n) {
    if (n >= 1000000) {
      return n >= 10000000
          ? '${n ~/ 1000000}M'
          : '${_trim(n / 1000000)}M';
    }
    if (n >= 1000) {
      return n >= 10000 ? '${n ~/ 1000}K' : '${_trim(n / 1000)}K';
    }
    return '$n';
  }

  String _trim(double v) {
    final s = v.toStringAsFixed(1);
    return s.endsWith('.0') ? s.substring(0, s.length - 2) : s;
  }

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

    final activeSet = activeFacets['category'] ?? {};
    categoryItems.sort((a, b) {
      final aActive = activeSet.contains(a.value) ? 0 : 1;
      final bActive = activeSet.contains(b.value) ? 0 : 1;
      if (aActive != bActive) return aActive.compareTo(bActive);
      return b.count.compareTo(a.count);
    });

    return Container(
      height: 104,
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: const BoxDecoration(
        color: NexusColors.surface,
        border: Border(
          bottom: BorderSide(color: NexusColors.border, width: 0.5),
        ),
      ),
      child: Stack(
        children: [
          ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: categoryItems.length,
            separatorBuilder: (_, __) => const SizedBox(width: 16),
            itemBuilder: (_, i) {
              final item = categoryItems[i];
              final isActive =
                  activeFacets['category']?.contains(item.value) ?? false;
              return GestureDetector(
                onTap: () => onToggle('category', item.value),
                child: SizedBox(
                  width: 68,
                  child: Column(
                    children: [
                      Container(
                        width: 50,
                        height: 50,
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
                            _formatCount(item.count),
                            style: TextStyle(
                              color: isActive
                                  ? NexusColors.textPrimary
                                  : NexusColors.textMuted,
                              fontSize: 11,
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
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          _edgeFade(left: true),
          _edgeFade(left: false),
        ],
      ),
    );
  }

  Widget _edgeFade({required bool left}) {
    return Positioned(
      top: 0,
      bottom: 0,
      left: left ? 0 : null,
      right: left ? null : 0,
      width: 24,
      child: IgnorePointer(child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: left ? Alignment.centerLeft : Alignment.centerRight,
            end: left ? Alignment.centerRight : Alignment.centerLeft,
            colors: [
              NexusColors.surface.withValues(alpha: 0.7),
              NexusColors.surface.withValues(alpha: 0),
            ],
          ),
        ),
      )),
    );
  }
}
