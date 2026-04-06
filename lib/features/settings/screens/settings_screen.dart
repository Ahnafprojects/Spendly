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
import '../../../shared/services/app_text.dart';
import '../../../shared/services/currency_settings.dart';
import '../../../shared/services/language_settings.dart';
import '../../../shared/services/offline_store.dart';
import '../../../shared/widgets/app_notice.dart';
import '../../auth/auth_notifier.dart';
import '../../auth/auth_service.dart';
import '../../spaces/space_notifier.dart';

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
  String _currencyCode = CurrencySettings.current.code;
  String _languageCode = LanguageSettings.current.code;

  String _t(String id, String en) => AppText.t(id: id, en: en);

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
      _currencyCode = CurrencySettings.current.code;
      _languageCode = LanguageSettings.current.code;
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
                  _t(
                    'Bisa dibuka di Excel / Google Sheets',
                    'Can be opened in Excel / Google Sheets',
                  ),
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
                  _t(
                    'Laporan ringkas transaksi dan budget',
                    'Compact transaction and budget report',
                  ),
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
      if (userId == null) {
        throw Exception(_t('User belum login', 'User is not logged in'));
      }

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
        AppNotice.success(
          context,
          '${_t('Export sukses', 'Export success')}: ${file.path}',
        );
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
        AppNotice.success(
          context,
          '${_t('Export sukses', 'Export success')}: ${file.path}',
        );
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
                _t('Ringkasan', 'Summary'),
                style: pw.TextStyle(
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.Bullet(
                text:
                    '${_t('Total transaksi', 'Total transactions')}: ${txList.length}',
              ),
              pw.Bullet(
                text:
                    '${_t('Total pemasukan', 'Total income')}: ${CurrencySettings.format(totalIncome)}',
              ),
              pw.Bullet(
                text:
                    '${_t('Total pengeluaran', 'Total expense')}: ${CurrencySettings.format(totalExpense)}',
              ),
              pw.Bullet(
                text:
                    '${_t('Total budget', 'Total budgets')}: ${budgetList.length}',
              ),
              pw.SizedBox(height: 12),
              pw.Text(
                _t('5 Transaksi Terbaru', '5 Latest Transactions'),
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
        AppNotice.success(
          context,
          '${_t('Export PDF sukses', 'PDF export success')}: ${file.path}',
        );
      }
    } catch (e) {
      if (!mounted) return;
      AppNotice.error(
        context,
        '${_t('Gagal export data', 'Failed to export data')}: $e',
      );
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
        title: Text(_t('Hapus Semua Data?', 'Delete All Data?')),
        content: Text(
          _t(
            'Semua transaksi dan budget kamu akan dihapus permanen. Lanjutkan?',
            'All your transactions and budgets will be permanently deleted. Continue?',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(_t('Batal', 'Cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(_t('Hapus', 'Delete')),
          ),
        ],
      ),
    );
    if (ok != true) return;

    setState(() => _busy = true);
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) {
        throw Exception(_t('User belum login', 'User is not logged in'));
      }

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
      AppNotice.success(
        context,
        _t(
          'Semua data lokal berhasil dihapus',
          'All local data has been deleted',
        ),
      );
    } catch (e) {
      if (!mounted) return;
      AppNotice.error(
        context,
        '${_t('Gagal hapus data', 'Failed to delete data')}: $e',
      );
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
          title: Text(_t('Ganti Password', 'Change Password')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: passController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: _t('Password Baru', 'New Password'),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: confirmController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: _t('Konfirmasi Password', 'Confirm Password'),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(_t('Batal', 'Cancel')),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(_t('Simpan', 'Save')),
            ),
          ],
        ),
      );

      if (!mounted) return;
      if (ok != true) return;
      final pass = passController.text.trim();
      final confirm = confirmController.text.trim();
      if (pass.length < 8) {
        AppNotice.warning(
          context,
          _t(
            'Password minimal 8 karakter',
            'Password must be at least 8 characters',
          ),
        );
        return;
      }
      if (pass != confirm) {
        AppNotice.warning(
          context,
          _t(
            'Konfirmasi password tidak cocok',
            'Password confirmation does not match',
          ),
        );
        return;
      }

      setState(() => _busy = true);
      await ref.read(authServiceProvider).updatePassword(pass);
      if (!mounted) return;
      AppNotice.success(
        context,
        _t('Password berhasil diperbarui', 'Password updated successfully'),
      );
    } catch (e) {
      if (!mounted) return;
      AppNotice.error(
        context,
        '${_t('Gagal ganti password', 'Failed to change password')}: $e',
      );
    } finally {
      passController.dispose();
      confirmController.dispose();
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pickCurrency() async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (_) {
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: CurrencySettings.options.map((option) {
              final active = option.code == _currencyCode;
              return ListTile(
                title: Text('${option.code} (${option.symbol.trim()})'),
                subtitle: Text(option.label),
                trailing: active
                    ? const Icon(Icons.check_circle, color: Color(0xFF2E90FA))
                    : null,
                onTap: () => Navigator.pop(context, option.code),
              );
            }).toList(),
          ),
        );
      },
    );

    if (!mounted || selected == null || selected == _currencyCode) return;
    await ref.read(appCurrencyProvider.notifier).setCurrency(selected);
    if (!mounted) return;
    setState(() => _currencyCode = selected);
    AppNotice.success(
      context,
      '${_t('Mata uang diubah ke', 'Currency changed to')} $selected',
    );
  }

  Future<void> _pickLanguage() async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (_) {
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: LanguageSettings.options.map((option) {
              final active = option.code == _languageCode;
              final cc = option.locale.countryCode;
              final localeText = cc == null
                  ? option.locale.languageCode
                  : '${option.locale.languageCode}_$cc';
              return ListTile(
                title: Text(option.label),
                subtitle: Text(localeText),
                trailing: active
                    ? const Icon(Icons.check_circle, color: Color(0xFF2E90FA))
                    : null,
                onTap: () => Navigator.pop(context, option.code),
              );
            }).toList(),
          ),
        );
      },
    );

    if (!mounted || selected == null || selected == _languageCode) return;
    await ref.read(appLanguageProvider.notifier).setLanguage(selected);
    if (!mounted) return;
    setState(() => _languageCode = selected);
    AppNotice.success(
      context,
      '${_t('Bahasa diubah ke', 'Language changed to')} ${selected.toUpperCase()}',
    );
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
    final pendingInvites =
        ref.watch(spaceInboxInvitationsProvider).valueOrNull?.length ?? 0;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        title: Text(_t('Pengaturan', 'Settings')),
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
                      Text(
                        _t('Akun Kamu', 'Your Account'),
                        style: const TextStyle(fontWeight: FontWeight.w700),
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
          _sectionTitle(_t('Preferensi', 'Preferences')),
          _tile(
            icon: Icons.dark_mode_rounded,
            title: _t('Mode Gelap', 'Dark Mode'),
            subtitle: _t('Atur mode tema aplikasi', 'Adjust app theme mode'),
            trailing: Switch(
              value: isDark,
              onChanged: (v) => ref
                  .read(themeProvider.notifier)
                  .setThemeMode(v ? ThemeMode.dark : ThemeMode.light),
            ),
          ),
          _tile(
            icon: Icons.attach_money_rounded,
            title: _t('Mata Uang', 'Currency'),
            subtitle: _currencyCode,
            onTap: _pickCurrency,
          ),
          _tile(
            icon: Icons.language_rounded,
            title: _t('Bahasa', 'Language'),
            subtitle:
                LanguageSettings.byCode(_languageCode)?.label ??
                _languageCode.toUpperCase(),
            onTap: _pickLanguage,
          ),
          _tile(
            icon: Icons.notifications_active_rounded,
            title: _t('Notifikasi Push', 'Push Notifications'),
            subtitle: _t(
              'Aktif/nonaktif notifikasi aplikasi',
              'Enable/disable app notifications',
            ),
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
            title: _t('Peringatan Budget', 'Budget Alerts'),
            subtitle: _t(
              'Notifikasi budget hampir habis',
              'Alerts when budget is near limit',
            ),
            trailing: Switch(
              value: _budgetAlert,
              onChanged: (v) {
                setState(() => _budgetAlert = v);
                _saveBool(_kBudgetAlert, v);
              },
            ),
          ),
          const SizedBox(height: 14),
          _sectionTitle(_t('Shared Space', 'Shared Space')),
          _tile(
            icon: Icons.groups_rounded,
            title: _t('Shared Members', 'Shared Members'),
            subtitle: _t(
              'Kelola anggota dan role shared space',
              'Manage shared members and roles',
            ),
            onTap: () => context.pushNamed('members'),
          ),
          _tile(
            icon: Icons.mail_outline_rounded,
            title: _t('Invitation Inbox', 'Invitation Inbox'),
            subtitle: pendingInvites > 0
                ? '$pendingInvites ${_t('undangan pending', 'pending invitations')}'
                : _t('Tidak ada undangan pending', 'No pending invitations'),
            onTap: () => context.pushNamed('invitation-inbox'),
          ),
          _tile(
            icon: Icons.history_toggle_off_rounded,
            title: _t('Activity Feed', 'Activity Feed'),
            subtitle: _t(
              'Lihat aktivitas terbaru shared space',
              'See latest shared space activities',
            ),
            onTap: () => context.pushNamed('space-activity'),
          ),
          const SizedBox(height: 14),
          _sectionTitle(_t('Data & Keamanan', 'Data & Security')),
          _tile(
            icon: Icons.file_download_rounded,
            title: _t('Ekspor Data', 'Export Data'),
            subtitle: _t(
              'Pilih format Excel / JSON / PDF',
              'Choose Excel / JSON / PDF format',
            ),
            onTap: _busy ? null : _exportData,
          ),
          _tile(
            icon: Icons.vpn_key_rounded,
            title: _t('Ganti Password', 'Change Password'),
            subtitle: _t(
              'Ganti password akun kamu',
              'Change your account password',
            ),
            onTap: _busy ? null : _changePassword,
          ),
          _tile(
            icon: Icons.delete_forever_rounded,
            title: _t('Hapus Semua Data', 'Clear All Data'),
            subtitle: _t(
              'Hapus semua transaksi dan budget',
              'Delete all transactions and budgets',
            ),
            onTap: _busy ? null : _clearAllData,
          ),
          const SizedBox(height: 14),
          _sectionTitle(_t('Tentang', 'About')),
          _tile(
            icon: Icons.info_outline_rounded,
            title: _t('Versi Aplikasi', 'App Version'),
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
              label: Text(
                _t('Keluar', 'Logout'),
                style: const TextStyle(
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
