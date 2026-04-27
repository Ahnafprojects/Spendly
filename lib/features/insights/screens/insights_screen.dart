import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/constants/transaction_categories.dart';
import '../../../shared/widgets/app_shimmer.dart';
import '../insights_model.dart';
import '../insights_notifier.dart';
import '../widgets/insights_dashboard_card.dart';

class InsightsScreen extends ConsumerWidget {
  const InsightsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(insightsNotifierProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0A0A0F) : const Color(0xFFF4F7FC);
    final titleColor = isDark ? Colors.white : const Color(0xFF15203A);
    final subtitleColor = isDark ? Colors.white70 : const Color(0xFF5B6275);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        title: const Text('Analisis Keuanganmu'),
        actions: [
          IconButton(
            onPressed: () =>
                ref.read(insightsNotifierProvider.notifier).refresh(),
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Generate insight baru',
          ),
        ],
      ),
      body: state.when(
        data: (bundle) => ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          children: [
            Text(
              bundle.periodLabel,
              style: TextStyle(
                color: subtitleColor,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            _SectionTitle(
              title: 'Insight Utama',
              subtitle: formatInsightTimeAgo(bundle.updatedAt),
            ),
            const SizedBox(height: 12),
            _MainInsightCard(bundle: bundle),
            const SizedBox(height: 28),
            const _SectionTitle(
              title: 'Kenapa Insight Ini Muncul',
              subtitle: 'Angka utama yang dipakai AI saat membaca pola kamu',
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: bundle.supportingFacts
                  .map((fact) => _FactChip(fact: fact))
                  .toList(),
            ),
            const SizedBox(height: 28),
            const _SectionTitle(
              title: 'Temuan Minggu Ini',
              subtitle: 'Sorotan paling relevan dari pola terbaru',
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 212,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: bundle.weeklyFindings.length,
                separatorBuilder: (_, _) => const SizedBox(width: 12),
                itemBuilder: (_, index) {
                  final item = bundle.weeklyFindings[index];
                  return SizedBox(width: 270, child: _FindingCard(item: item));
                },
              ),
            ),
            const SizedBox(height: 28),
            const _SectionTitle(
              title: 'Tips Personal',
              subtitle: 'Langkah kecil yang paling realistis minggu ini',
            ),
            const SizedBox(height: 12),
            ...bundle.personalTips.map((tip) => _TipTile(text: tip)),
            const SizedBox(height: 28),
            const _SectionTitle(
              title: 'Prediksi Bulan Ini',
              subtitle: 'Estimasi berbasis ritme transaksi sekarang',
            ),
            const SizedBox(height: 12),
            _PredictionCard(prediction: bundle.prediction),
            const SizedBox(height: 28),
            const _SectionTitle(
              title: 'Riwayat Insight',
              subtitle:
                  'Insight terakhir yang pernah dihasilkan untuk scope ini',
            ),
            const SizedBox(height: 12),
            ...bundle.history.map((item) => _HistoryTile(item: item)),
          ],
        ),
        loading: () => ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          children: const [
            AppShimmer(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SkeletonBox(height: 14, width: 120),
                  SizedBox(height: 18),
                  _SkeletonBox(height: 160, width: double.infinity),
                  SizedBox(height: 26),
                  _SkeletonBox(height: 14, width: 160),
                  SizedBox(height: 12),
                  _SkeletonBox(height: 180, width: double.infinity),
                  SizedBox(height: 26),
                  _SkeletonBox(height: 14, width: 120),
                  SizedBox(height: 12),
                  _SkeletonBox(height: 72, width: double.infinity),
                ],
              ),
            ),
          ],
        ),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Analisis belum bisa dimuat',
                  style: TextStyle(
                    color: titleColor,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  error.toString(),
                  textAlign: TextAlign.center,
                  style: TextStyle(color: subtitleColor),
                ),
                const SizedBox(height: 14),
                FilledButton.icon(
                  onPressed: () =>
                      ref.read(insightsNotifierProvider.notifier).refresh(),
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Coba lagi'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final String subtitle;

  const _SectionTitle({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            color: isDark ? Colors.white : const Color(0xFF15203A),
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: TextStyle(
            color: isDark ? Colors.white70 : const Color(0xFF5B6275),
            fontSize: 13,
          ),
        ),
      ],
    );
  }
}

class _MainInsightCard extends StatelessWidget {
  final InsightsBundle bundle;

  const _MainInsightCard({required this.bundle});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final item = bundle.mainInsight;
    final accent = insightKindColor(item.kind);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? const [Color(0xFF161C2E), Color(0xFF0E1320)]
              : const [Color(0xFFF8FBFF), Color(0xFFEFF5FF)],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? Colors.white10 : const Color(0xFFD7E3FF),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(categoryIconFor(item.category), color: accent),
              ),
              const SizedBox(width: 12),
              Expanded(child: InsightBadge(kind: item.kind)),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            item.title,
            style: TextStyle(
              color: isDark ? Colors.white : const Color(0xFF15203A),
              fontSize: 22,
              height: 1.2,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            item.description,
            style: TextStyle(
              color: isDark ? Colors.white70 : const Color(0xFF5B6275),
              fontSize: 14,
              height: 1.55,
            ),
          ),
        ],
      ),
    );
  }
}

class _FindingCard extends StatelessWidget {
  final InsightItem item;

  const _FindingCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = insightKindColor(item.kind);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF141A28) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? Colors.white10 : const Color(0xFFE1E9F9),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  categoryIconFor(item.category),
                  color: accent,
                  size: 20,
                ),
              ),
              const Spacer(),
              InsightBadge(kind: item.kind),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            item.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: isDark ? Colors.white : const Color(0xFF15203A),
              fontSize: 16,
              height: 1.25,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            item.description,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: isDark ? Colors.white70 : const Color(0xFF5B6275),
              fontSize: 13,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}

class _TipTile extends StatelessWidget {
  final String text;

  const _TipTile({required this.text});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF141A28) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? Colors.white10 : const Color(0xFFE1E9F9),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: const Color(0xFF7C5CFA).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.auto_awesome_rounded,
              size: 18,
              color: Color(0xFF7C5CFA),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: isDark ? Colors.white70 : const Color(0xFF41506A),
                fontSize: 13.5,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PredictionCard extends StatelessWidget {
  final String prediction;

  const _PredictionCard({required this.prediction});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF132033) : const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isDark ? Colors.white10 : const Color(0xFFD7E7FF),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: const Color(0xFF2F80ED).withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.insights_rounded, color: Color(0xFF2F80ED)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              prediction,
              style: TextStyle(
                color: isDark ? Colors.white : const Color(0xFF17304D),
                fontSize: 14,
                height: 1.55,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FactChip extends StatelessWidget {
  final SupportingFact fact;

  const _FactChip({required this.fact});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF141A28) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white10 : const Color(0xFFE1E9F9),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            fact.label,
            style: TextStyle(
              color: isDark ? Colors.white60 : const Color(0xFF6D7991),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            fact.value,
            style: TextStyle(
              color: isDark ? Colors.white : const Color(0xFF15203A),
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _HistoryTile extends StatelessWidget {
  final InsightItem item;

  const _HistoryTile({required this.item});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF141A28) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? Colors.white10 : const Color(0xFFE1E9F9),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: insightKindColor(item.kind).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              categoryIconFor(item.category),
              color: insightKindColor(item.kind),
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: TextStyle(
                    color: isDark ? Colors.white : const Color(0xFF15203A),
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  item.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: isDark ? Colors.white70 : const Color(0xFF5B6275),
                    fontSize: 12.5,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SkeletonBox extends StatelessWidget {
  final double height;
  final double width;

  const _SkeletonBox({required this.height, required this.width});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      width: width,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
    );
  }
}
