import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../shared/services/currency_settings.dart';
import 'onboarding_notifier.dart';

class OnboardingService {
  static const _kOnboardingCompleted = 'onboarding_completed';

  static Future<void> completeOnboarding(OnboardingState data) async {
    final client = Supabase.instance.client;
    final user = client.auth.currentUser;
    if (user == null) throw Exception('User belum login');

    final now = DateTime.now();
    final nowIso = now.toIso8601String();

    // 1. Update user metadata with full_name (for fast client-side access)
    await client.auth.updateUser(
      UserAttributes(data: {'full_name': data.name.trim()}),
    );

    // 2. Upsert profile row
    await client.from('profiles').upsert({
      'id': user.id,
      'full_name': data.name.trim(),
      'updated_at': nowIso,
    }, onConflict: 'id');

    // 3. Apply currency setting
    await CurrencySettings.setCurrencyCode(data.currency);

    // 4. Insert first account
    await client.from('accounts').insert({
      'user_id': user.id,
      'name': data.accountName.trim(),
      'type': data.accountType,
      'icon': _iconForType(data.accountType),
      'color': _colorForType(data.accountType),
      'initial_balance': data.initialBalance,
      'is_default': true,
      'created_at': nowIso,
      'updated_at': nowIso,
    });

    // 5. Insert monthly budget (if not skipped)
    if (!data.skipBudget) {
      final monthStart = DateTime(now.year, now.month, 1);
      final monthStr = DateFormat('yyyy-MM-dd').format(monthStart);
      await client.from('budgets').upsert({
        'user_id': user.id,
        'category': 'total',
        'month': monthStr,
        'limit_amount': data.monthlyBudget,
      }, onConflict: 'user_id, category, month');
    }

    // 6. Mark onboarding as complete
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kOnboardingCompleted, true);
  }

  static Future<bool> isCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    final val = prefs.getBool(_kOnboardingCompleted);
    return val == true;
  }

  static String _iconForType(String type) {
    switch (type) {
      case 'bank':
        return 'bank';
      case 'ewallet':
        return 'phone';
      default:
        return 'cash';
    }
  }

  static String _colorForType(String type) {
    switch (type) {
      case 'bank':
        return '#2E90FA';
      case 'ewallet':
        return '#8B5CF6';
      default:
        return '#00C2A8';
    }
  }
}
