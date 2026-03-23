import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/services/offline_store.dart';
import '../../../shared/widgets/app_notice.dart';
import '../../auth/auth_notifier.dart';
import '../../auth/auth_service.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  static const _kPushNotif = 'settings_push_notif';
  static const _kBudgetAlert = 'settings_budget_alert';

  bool _pushNotif = true;
  bool _budgetAlert = true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _pushNotif = prefs.getBool(_kPushNotif) ?? true;
      _budgetAlert = prefs.getBool(_kBudgetAlert) ?? true;
    });
  }

  Future<void> _saveBool(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
  }

  Future<String?> _pickExportFormat() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return showModalBottomSheet<String>(
      context: context,
      backgroundColor: isDark ? const Color(0xFF151A2A) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (_) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(
                  Icons.table_chart_rounded,
                  color: isDark ? Colors.white70 : const Color(0xFF415073),
                ),
                title: Text(
                  'Excel (.csv)',
                  style: TextStyle(
                    color: isDark ? Colors.white : const Color(0xFF1A1E2A),
                  ),
                ),
                subtitle: Text(
                  'Bisa dibuka di Excel / Google Sheets',
                  style: TextStyle(
                    color: isDark ? Colors.white54 : const Color(0xFF5B6275),
                  ),
                ),
                onTap: () => Navigator.pop(context, 'csv'),
              ),
              ListTile(
                leading: Icon(
                  Icons.data_object_rounded,
                  color: isDark ? Colors.white70 : const Color(0xFF415073),
                ),
                title: Text(
                  'JSON (.json)',
                  style: TextStyle(
                    color: isDark ? Colors.white : const Color(0xFF1A1E2A),
                  ),
                ),
                onTap: () => Navigator.pop(context, 'json'),
              ),
              ListTile(
                leading: Icon(
                  Icons.picture_as_pdf_rounded,
                  color: isDark ? Colors.white70 : const Color(0xFF415073),
                ),
                title: Text(
                  'PDF (.pdf)',
                  style: TextStyle(
                    color: isDark ? Colors.white : const Color(0xFF1A1E2A),
                  ),
                ),
                subtitle: Text(
                  'Laporan ringkas transaksi dan budget',
                  style: TextStyle(
                    color: isDark ? Colors.white54 : const Color(0xFF5B6275),
                  ),
                ),
                onTap: () => Navigator.pop(context, 'pdf'),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _exportData() async {
    final format = await _pickExportFormat();
    if (!mounted || format == null) return;

    setState(() => _busy = true);
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) throw Exception('User belum login');

      final tx = await Supabase.instance.client
          .from('transactions')
          .select()
          .eq('user_id', userId)
          .order('date', ascending: false);
      final budgets = await Supabase.instance.client
          .from('budgets')
          .select()
          .eq('user_id', userId)
          .order('month', ascending: false);

      final data = {
        'exported_at': DateTime.now().toIso8601String(),
        'user_id': userId,
        'transactions': tx,
        'budgets': budgets,
      };

      final dir = await getApplicationDocumentsDirectory();
      final ts = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      late final String ext;
      if (format == 'json') {
        ext = 'json';
        final content = const JsonEncoder.withIndent('  ').convert(data);
        final file = File('${dir.path}/spendly_export_$ts.$ext');
        await file.writeAsString(content);
        if (!mounted) return;
        AppNotice.success(context, 'Export sukses: ${file.path}');
      } else if (format == 'csv') {
        ext = 'csv';
        final rows = <String>[
          'type,id,date,category,note,amount',
          ...(tx as List).map((e) {
            final m = e as Map<String, dynamic>;
            return [
              m['type'] ?? '',
              m['id'] ?? '',
              m['date'] ?? '',
              _csv(m['category']),
              _csv(m['note']),
              (m['amount'] ?? '').toString(),
            ].join(',');
          }),
          '',
          'BUDGETS',
          'category,month,limit_amount',
          ...(budgets as List).map((e) {
            final m = e as Map<String, dynamic>;
            return [
              _csv(m['category']),
              m['month'] ?? '',
              (m['limit_amount'] ?? '').toString(),
            ].join(',');
          }),
        ];
        final content = rows.join('\n');
        final file = File('${dir.path}/spendly_export_$ts.$ext');
        await file.writeAsString(content);
        if (!mounted) return;
        AppNotice.success(context, 'Export sukses: ${file.path}');
      } else {
        ext = 'pdf';
        final document = pw.Document();
        final txList = (tx as List).cast<Map<String, dynamic>>();
        final budgetList = (budgets as List).cast<Map<String, dynamic>>();
        final totalIncome = txList
            .where((e) => e['type'] == 'income')
            .fold<double>(
              0,
              (sum, e) => sum + ((e['amount'] as num?)?.toDouble() ?? 0),
            );
        final totalExpense = txList
            .where((e) => e['type'] == 'expense')
            .fold<double>(
              0,
              (sum, e) => sum + ((e['amount'] as num?)?.toDouble() ?? 0),
            );

        document.addPage(
          pw.MultiPage(
            build: (ctx) => [
              pw.Header(level: 0, child: pw.Text('Spendly Export')),
              pw.Text('Exported at: ${data['exported_at']}'),
              pw.Text('User ID: $userId'),
              pw.SizedBox(height: 12),
              pw.Text(
                'Ringkasan',
                style: pw.TextStyle(
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.Bullet(text: 'Total transaksi: ${txList.length}'),
              pw.Bullet(
                text:
                    'Total income: ${NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0).format(totalIncome)}',
              ),
              pw.Bullet(
                text:
                    'Total expense: ${NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0).format(totalExpense)}',
              ),
              pw.Bullet(text: 'Total budget: ${budgetList.length}'),
              pw.SizedBox(height: 12),
              pw.Text(
                '5 Transaksi Terbaru',
                style: pw.TextStyle(
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              ...txList
                  .take(5)
                  .map(
                    (m) => pw.Text(
                      '${m['date'] ?? '-'} | ${m['type'] ?? '-'} | ${m['category'] ?? '-'} | ${(m['amount'] ?? 0).toString()}',
                    ),
                  ),
            ],
          ),
        );

        final bytes = await document.save();
        final file = File('${dir.path}/spendly_export_$ts.$ext');
        await file.writeAsBytes(bytes, flush: true);
        if (!mounted) return;
        AppNotice.success(context, 'Export PDF sukses: ${file.path}');
      }
    } catch (e) {
      if (!mounted) return;
      AppNotice.error(context, 'Gagal export data: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _csv(dynamic value) {
    final raw = (value ?? '').toString().replaceAll('"', '""');
    return '"$raw"';
  }

  Future<void> _clearAllData() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Hapus Semua Data?'),
        content: const Text(
          'Semua transaksi dan budget kamu akan dihapus permanen. Lanjutkan?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    setState(() => _busy = true);
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) throw Exception('User belum login');

      await OfflineStore().clearUserData(userId);
      try {
        await Supabase.instance.client
            .from('transactions')
            .delete()
            .eq('user_id', userId);
        await Supabase.instance.client
            .from('budgets')
            .delete()
            .eq('user_id', userId);
      } catch (_) {
        // offline mode: data lokal tetap dibersihkan
      }

      if (!mounted) return;
      AppNotice.success(context, 'Semua data lokal berhasil dihapus');
    } catch (e) {
      if (!mounted) return;
      AppNotice.error(context, 'Gagal hapus data: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _changePassword() async {
    final passController = TextEditingController();
    final confirmController = TextEditingController();
    try {
      final ok = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Ganti Password'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: passController,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Password Baru'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: confirmController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Konfirmasi Password',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Simpan'),
            ),
          ],
        ),
      );

      if (!mounted) return;
      if (ok != true) return;
      final pass = passController.text.trim();
      final confirm = confirmController.text.trim();
      if (pass.length < 8) {
        AppNotice.warning(context, 'Password minimal 8 karakter');
        return;
      }
      if (pass != confirm) {
        AppNotice.warning(context, 'Konfirmasi password tidak cocok');
        return;
      }

      setState(() => _busy = true);
      await ref.read(authServiceProvider).updatePassword(pass);
      if (!mounted) return;
      AppNotice.success(context, 'Password berhasil diperbarui');
    } catch (e) {
      if (!mounted) return;
      AppNotice.error(context, 'Gagal ganti password: $e');
    } finally {
      passController.dispose();
      confirmController.dispose();
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentMode = ref.watch(themeProvider);
    final isDark = currentMode == ThemeMode.dark;
    final userEmail =
        ref.read(authServiceProvider).currentSession?.user.email ?? '-';
    final bg = isDark ? const Color(0xFF090B14) : const Color(0xFFF4F6FB);
    final card = isDark ? const Color(0xFF151A2A) : Colors.white;
    final border = isDark ? Colors.white10 : const Color(0xFFDCE2F0);
    final textMuted = isDark ? Colors.white60 : const Color(0xFF5B6275);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: Colors.transparent,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: border),
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF1F2740)
                        : const Color(0xFFE9EEFA),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    Icons.person_rounded,
                    color: isDark ? Colors.white70 : const Color(0xFF24314F),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Akun Kamu',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        userEmail,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: textMuted, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _sectionTitle('Preferences'),
          _tile(
            icon: Icons.dark_mode_rounded,
            title: 'Dark Mode',
            subtitle: 'Atur mode tema aplikasi',
            trailing: Switch(
              value: isDark,
              onChanged: (v) => ref
                  .read(themeProvider.notifier)
                  .setThemeMode(v ? ThemeMode.dark : ThemeMode.light),
            ),
          ),
          _tile(
            icon: Icons.notifications_active_rounded,
            title: 'Push Notification',
            subtitle: 'Aktif/nonaktif notifikasi aplikasi',
            trailing: Switch(
              value: _pushNotif,
              onChanged: (v) {
                setState(() => _pushNotif = v);
                _saveBool(_kPushNotif, v);
              },
            ),
          ),
          _tile(
            icon: Icons.savings_rounded,
            title: 'Budget Alerts',
            subtitle: 'Notifikasi budget hampir habis',
            trailing: Switch(
              value: _budgetAlert,
              onChanged: (v) {
                setState(() => _budgetAlert = v);
                _saveBool(_kBudgetAlert, v);
              },
            ),
          ),
          const SizedBox(height: 14),
          _sectionTitle('Data & Security'),
          _tile(
            icon: Icons.file_download_rounded,
            title: 'Export Data',
            subtitle: 'Pilih format Excel / JSON / PDF',
            onTap: _busy ? null : _exportData,
          ),
          _tile(
            icon: Icons.vpn_key_rounded,
            title: 'Change Password',
            subtitle: 'Ganti password akun kamu',
            onTap: _busy ? null : _changePassword,
          ),
          _tile(
            icon: Icons.delete_forever_rounded,
            title: 'Clear All Data',
            subtitle: 'Hapus semua transaksi dan budget',
            onTap: _busy ? null : _clearAllData,
          ),
          const SizedBox(height: 14),
          _sectionTitle('About'),
          _tile(
            icon: Icons.info_outline_rounded,
            title: 'App Version',
            subtitle: 'Spendly v1.0.0',
          ),
          const SizedBox(height: 20),
          if (_busy) const Center(child: CircularProgressIndicator()),
          const SizedBox(height: 12),
          SizedBox(
            height: 50,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFFFF5A6E)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () async {
                await ref.read(authNotifierProvider.notifier).signOut();
                if (!context.mounted) return;
                context.goNamed('auth');
              },
              icon: const Icon(Icons.logout_rounded, color: Color(0xFFFF5A6E)),
              label: const Text(
                'Logout',
                style: TextStyle(
                  color: Color(0xFFFF5A6E),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String text) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        text,
        style: TextStyle(
          color: isDark ? Colors.white70 : const Color(0xFF5B6275),
          fontSize: 12,
          letterSpacing: 0.4,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _tile({
    required IconData icon,
    required String title,
    required String subtitle,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF151A2A) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? Colors.white10 : const Color(0xFFDCE2F0),
        ),
      ),
      child: ListTile(
        onTap: onTap,
        leading: Icon(
          icon,
          color: isDark ? Colors.white70 : const Color(0xFF415073),
        ),
        title: Text(
          title,
          style: TextStyle(
            color: isDark ? Colors.white : const Color(0xFF1A1E2A),
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(
            color: isDark ? Colors.white54 : const Color(0xFF5B6275),
            fontSize: 12,
          ),
        ),
        trailing:
            trailing ??
            Icon(
              Icons.chevron_right_rounded,
              color: isDark ? Colors.white38 : const Color(0xFF8C94A8),
            ),
      ),
    );
  }
}
