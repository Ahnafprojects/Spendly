import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class OnboardingState {
  final int currentStep;
  final String name;
  final int avatarIndex;
  final String currency;
  final String accountName;
  final String accountType;
  final double initialBalance;
  final double monthlyBudget;
  final bool skipBudget;
  final bool isSaving;

  const OnboardingState({
    this.currentStep = 0,
    this.name = '',
    this.avatarIndex = 0,
    this.currency = 'IDR',
    this.accountName = 'Dompet Utama',
    this.accountType = 'cash',
    this.initialBalance = 0,
    this.monthlyBudget = 3000000,
    this.skipBudget = false,
    this.isSaving = false,
  });

  OnboardingState copyWith({
    int? currentStep,
    String? name,
    int? avatarIndex,
    String? currency,
    String? accountName,
    String? accountType,
    double? initialBalance,
    double? monthlyBudget,
    bool? skipBudget,
    bool? isSaving,
  }) {
    return OnboardingState(
      currentStep: currentStep ?? this.currentStep,
      name: name ?? this.name,
      avatarIndex: avatarIndex ?? this.avatarIndex,
      currency: currency ?? this.currency,
      accountName: accountName ?? this.accountName,
      accountType: accountType ?? this.accountType,
      initialBalance: initialBalance ?? this.initialBalance,
      monthlyBudget: monthlyBudget ?? this.monthlyBudget,
      skipBudget: skipBudget ?? this.skipBudget,
      isSaving: isSaving ?? this.isSaving,
    );
  }
}

class OnboardingNotifier extends Notifier<OnboardingState> {
  @override
  OnboardingState build() {
    final user = Supabase.instance.client.auth.currentUser;
    final metaName =
        user?.userMetadata?['full_name']?.toString().trim() ?? '';
    return OnboardingState(name: metaName);
  }

  void setName(String v) => state = state.copyWith(name: v);
  void setAvatar(int i) => state = state.copyWith(avatarIndex: i);
  void setCurrency(String v) => state = state.copyWith(currency: v);
  void setAccountName(String v) => state = state.copyWith(accountName: v);
  void setAccountType(String v) => state = state.copyWith(accountType: v);
  void setInitialBalance(double v) =>
      state = state.copyWith(initialBalance: v);
  void setMonthlyBudget(double v) => state = state.copyWith(monthlyBudget: v);
  void setSkipBudget(bool v) => state = state.copyWith(skipBudget: v);
  void setSaving(bool v) => state = state.copyWith(isSaving: v);

  void goToStep(int s) => state = state.copyWith(currentStep: s);
  void nextStep() =>
      state = state.copyWith(currentStep: state.currentStep + 1);
  void prevStep() {
    if (state.currentStep > 0) {
      state = state.copyWith(currentStep: state.currentStep - 1);
    }
  }
}

final onboardingProvider =
    NotifierProvider<OnboardingNotifier, OnboardingState>(
      OnboardingNotifier.new,
    );
