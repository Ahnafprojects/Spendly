import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/constants/transaction_categories.dart';
import '../../../shared/widgets/app_shimmer.dart';
import '../insights_model.dart';
import '../insights_notifier.dart';

class InsightsDashboardCard extends ConsumerWidget {
  const InsightsDashboardCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(insightsNotifierProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: () => context.push('/insights'),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isDark
                ? const [Color(0xFF1A2442), Color(0xFF0E1424)]
                : const [Color(0xFFEAF1FF), Color(0xFFF7FBFF)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: isDark ? Colors.white10 : const Color(0xFFD7E3FF),
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF4F6EF7).withValues(alpha: 0.10),
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: state.when(
          data: (bundle) => _LoadedInsightsCard(bundle: bundle),
          loading: () => const _LoadingInsightsCard(),
          error: (error, _) => _InsightsCardError(
            message: error.toString(),
            onRetry: () =>
                ref.read(insightsNotifierProvider.notifier).refresh(),
          ),
        ),
      ),
    );
  }
}

class _LoadedInsightsCard extends ConsumerWidget {
  final InsightsBundle bundle;

  const _LoadedInsightsCard({required this.bundle});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final titleColor = isDark ? Colors.white : const Color(0xFF15203A);
    final subtitleColor = isDark ? Colors.white70 : const Color(0xFF5B6275);
    final accent = insightKindColor(bundle.mainInsight.kind);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                categoryIconFor(bundle.mainInsight.category),
                color: accent,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'AI Insights',
                    style: TextStyle(
                      color: titleColor,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    formatInsightTimeAgo(bundle.updatedAt),
                    style: TextStyle(color: subtitleColor, fontSize: 12),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: () {
                ref.read(insightsNotifierProvider.notifier).refresh();
              },
              icon: const Icon(Icons.refresh_rounded),
              tooltip: 'Generate insight baru',
            ),
          ],
        ),
        const SizedBox(height: 14),
        InsightBadge(kind: bundle.mainInsight.kind),
        const SizedBox(height: 10),
        Text(
          bundle.mainInsight.title,
          style: TextStyle(
            color: titleColor,
            fontSize: 18,
            height: 1.2,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          bundle.mainInsight.description,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(color: subtitleColor, fontSize: 13.5, height: 1.45),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Text(
              'Lihat analisis lengkap',
              style: TextStyle(
                color: accent,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 6),
            Icon(Icons.arrow_forward_rounded, size: 18, color: accent),
          ],
        ),
      ],
    );
  }
}

class _LoadingInsightsCard extends StatelessWidget {
  const _LoadingInsightsCard();

  @override
  Widget build(BuildContext context) {
    return AppShimmer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(height: 14, width: 96, color: Colors.white),
                    const SizedBox(height: 8),
                    Container(height: 10, width: 120, color: Colors.white),
                  ],
                ),
              ),
              Container(height: 24, width: 24, color: Colors.white),
            ],
          ),
          const SizedBox(height: 18),
          Container(height: 22, width: 100, color: Colors.white),
          const SizedBox(height: 12),
          Container(height: 18, width: double.infinity, color: Colors.white),
          const SizedBox(height: 8),
          Container(height: 14, width: double.infinity, color: Colors.white),
          const SizedBox(height: 8),
          Container(height: 14, width: 240, color: Colors.white),
        ],
      ),
    );
  }
}

class _InsightsCardError extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _InsightsCardError({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final titleColor = isDark ? Colors.white : const Color(0xFF15203A);
    final subtitleColor = isDark ? Colors.white70 : const Color(0xFF5B6275);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'AI Insights',
          style: TextStyle(
            color: titleColor,
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'Insight belum bisa dibuat sekarang.',
          style: TextStyle(
            color: titleColor,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          message,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(color: subtitleColor, fontSize: 13),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('Coba lagi'),
        ),
      ],
    );
  }
}

class InsightBadge extends StatelessWidget {
  final InsightKind kind;

  const InsightBadge({super.key, required this.kind});

  @override
  Widget build(BuildContext context) {
    final color = insightKindColor(kind);
    final label = switch (kind) {
      InsightKind.warning => 'Warning',
      InsightKind.good => 'Good',
      InsightKind.tip => 'Tips',
      InsightKind.trend => 'Trend',
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

Color insightKindColor(InsightKind kind) {
  switch (kind) {
    case InsightKind.warning:
      return const Color(0xFFE2564D);
    case InsightKind.good:
      return const Color(0xFF159A6E);
    case InsightKind.tip:
      return const Color(0xFF7C5CFA);
    case InsightKind.trend:
      return const Color(0xFF2F80ED);
  }
}

String formatInsightTimeAgo(DateTime updatedAt) {
  final diff = DateTime.now().difference(updatedAt);
  if (diff.inMinutes < 1) return 'Diperbarui barusan';
  if (diff.inHours < 1) return 'Diperbarui ${diff.inMinutes} menit lalu';
  if (diff.inDays < 1) return 'Diperbarui ${diff.inHours} jam lalu';
  return 'Diperbarui ${diff.inDays} hari lalu';
}
