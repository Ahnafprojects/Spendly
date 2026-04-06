import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../onboarding_notifier.dart';

const _kAvatarOptions = <(IconData, Color)>[
  (Icons.person_rounded, Color(0xFF2E90FA)),
  (Icons.face_rounded, Color(0xFF00C2A8)),
  (Icons.person_2_rounded, Color(0xFFFF5A6E)),
  (Icons.sentiment_satisfied_alt_rounded, Color(0xFFFFB020)),
  (Icons.face_3_rounded, Color(0xFF8B5CF6)),
  (Icons.supervised_user_circle_rounded, Color(0xFF06B6D4)),
  (Icons.emoji_emotions_rounded, Color(0xFFEC4899)),
  (Icons.face_6_rounded, Color(0xFF10B981)),
  (Icons.person_4_rounded, Color(0xFFF59E0B)),
  (Icons.account_circle_rounded, Color(0xFF3B82F6)),
  (Icons.spa_rounded, Color(0xFF14B8A6)),
  (Icons.auto_awesome_rounded, Color(0xFFE11D48)),
];

class StepNameAvatar extends ConsumerStatefulWidget {
  final VoidCallback onNext;

  const StepNameAvatar({super.key, required this.onNext});

  @override
  ConsumerState<StepNameAvatar> createState() => _StepNameAvatarState();
}

class _StepNameAvatarState extends ConsumerState<StepNameAvatar> {
  late TextEditingController _nameCtrl;

  @override
  void initState() {
    super.initState();
    final initial = ref.read(onboardingProvider).name;
    _nameCtrl = TextEditingController(text: initial);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  bool get _canContinue =>
      ref.read(onboardingProvider).name.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(onboardingProvider);
    final notifier = ref.read(onboardingProvider.notifier);

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          28,
          20,
          28,
          MediaQuery.of(context).viewInsets.bottom + 24,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Siapa namamu?',
              style: TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.w800,
                height: 1.2,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Kami akan personalisasi pengalaman untukmu',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5),
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 32),

            // Name field
            _NameField(
              controller: _nameCtrl,
              onChanged: notifier.setName,
            ),
            const SizedBox(height: 16),

            // Live preview
            AnimatedOpacity(
              opacity: state.name.trim().isNotEmpty ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 200),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF2E90FA).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFF2E90FA).withValues(alpha: 0.25),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.waving_hand_rounded,
                      color: Color(0xFF2E90FA),
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Halo, ${state.name.trim().isNotEmpty ? state.name.trim() : '...'}!',
                        style: const TextStyle(
                          color: Color(0xFF2E90FA),
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 32),

            // Avatar section
            Text(
              'Pilih avatar',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 14,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.3,
              ),
            ),
            const SizedBox(height: 14),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 6,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 1,
              ),
              itemCount: _kAvatarOptions.length,
              itemBuilder: (_, i) {
                final (icon, color) = _kAvatarOptions[i];
                final selected = state.avatarIndex == i;
                return GestureDetector(
                  onTap: () => notifier.setAvatar(i),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [
                          color.withValues(
                            alpha: selected ? 1.0 : 0.18,
                          ),
                          color.withValues(
                            alpha: selected ? 0.75 : 0.08,
                          ),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      border: Border.all(
                        color: selected
                            ? color
                            : Colors.white.withValues(alpha: 0.08),
                        width: selected ? 2.5 : 1,
                      ),
                      boxShadow: selected
                          ? [
                              BoxShadow(
                                color: color.withValues(alpha: 0.4),
                                blurRadius: 10,
                                spreadRadius: 0,
                              ),
                            ]
                          : [],
                    ),
                    child: Icon(
                      icon,
                      color: selected
                          ? Colors.white
                          : color.withValues(alpha: 0.7),
                      size: 22,
                    ),
                  ),
                );
              },
            ),

            const SizedBox(height: 36),

            // Continue button
            SizedBox(
              width: double.infinity,
              height: 52,
              child: AnimatedOpacity(
                opacity: _canContinue ? 1.0 : 0.45,
                duration: const Duration(milliseconds: 200),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    gradient: const LinearGradient(
                      colors: [Color(0xFF2E90FA), Color(0xFF00C2A8)],
                    ),
                  ),
                  child: ElevatedButton(
                    onPressed: _canContinue ? widget.onNext : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text(
                      'Lanjut',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NameField extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  const _NameField({required this.controller, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      autofocus: true,
      onChanged: onChanged,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 22,
        fontWeight: FontWeight.w600,
      ),
      textCapitalization: TextCapitalization.words,
      decoration: InputDecoration(
        hintText: 'Nama lengkapmu',
        hintStyle: TextStyle(
          color: Colors.white.withValues(alpha: 0.25),
          fontSize: 22,
          fontWeight: FontWeight.w400,
        ),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.06),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: Colors.white.withValues(alpha: 0.12),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: Colors.white.withValues(alpha: 0.12),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(
            color: Color(0xFF2E90FA),
            width: 2,
          ),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 16,
        ),
      ),
    );
  }
}
