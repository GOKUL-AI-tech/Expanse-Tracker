import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/services/notification_service.dart';
import '../../../data/models/profile_model.dart';
import '../providers/profile_provider.dart';
import '../../auth/providers/auth_provider.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _nameCtrl = TextEditingController();
  final _countryCtrl = TextEditingController();
  bool _isEditing = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _countryCtrl.dispose();
    super.dispose();
  }

  void _startEdit(ProfileModel profile) {
    _nameCtrl.text = profile.fullName ?? '';
    _countryCtrl.text = profile.country ?? '';
    setState(() => _isEditing = true);
  }

  Future<void> _saveProfile(ProfileModel profile) async {
    final updated = profile.copyWith(
      fullName: _nameCtrl.text.trim(),
      country: _countryCtrl.text.trim(),
    );
    await ref.read(profileProvider.notifier).updateProfile(updated);
    setState(() => _isEditing = false);
  }

  Future<void> _pickAvatar(ProfileModel profile) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (picked == null) return;
    final url = await ref.read(profileProvider.notifier).uploadAvatar(File(picked.path));
    if (url != null) {
      final updated = profile.copyWith(profileImage: url);
      await ref.read(profileProvider.notifier).updateProfile(updated);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(profileProvider);
    final themeMode = ref.watch(themeModeProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          profile.value != null && !_isEditing
              ? IconButton(
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: () => _startEdit(profile.value!),
                )
              : const SizedBox(),
        ],
      ),
      body: profile.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (p) {
          if (p == null) return const Center(child: Text('No profile found'));

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Avatar
              Center(
                child: GestureDetector(
                  onTap: () => _pickAvatar(p),
                  child: Stack(
                    children: [
                      CircleAvatar(
                        radius: 56,
                        backgroundColor: AppColors.primary.withOpacity(0.1),
                        backgroundImage: p.profileImage != null
                            ? NetworkImage(p.profileImage!)
                            : null,
                        child: p.profileImage == null
                            ? Text(
                                (p.fullName ?? 'U').substring(0, 1).toUpperCase(),
                                style: GoogleFonts.poppins(
                                    fontSize: 36,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.primary),
                              )
                            : null,
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: const BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.camera_alt, color: Colors.white, size: 16),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: Text(
                  p.fullName ?? 'User',
                  style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w700),
                ),
              ),
              Center(
                child: Text(
                  p.email ?? '',
                  style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: isDark ? AppColors.darkSubtext : AppColors.lightSubtext),
                ),
              ),
              const SizedBox(height: 32),

              // Edit fields
              if (_isEditing) ...[
                TextField(
                  controller: _nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Full Name',
                    prefixIcon: Icon(Icons.person_outlined),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _countryCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Country',
                    prefixIcon: Icon(Icons.flag_outlined),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => setState(() => _isEditing = false),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => _saveProfile(p),
                        child: const Text('Save'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
              ],

              // Settings Section
              _SectionHeader('Preferences', isDark),
              const SizedBox(height: 8),

              // Currency
              _SettingTile(
                icon: Icons.currency_rupee,
                title: 'Currency',
                subtitle: p.currency,
                isDark: isDark,
                onTap: () => _showCurrencyPicker(context, p),
              ),

              // Theme
              _SettingTile(
                icon: Icons.palette_outlined,
                title: 'Theme',
                subtitle: themeMode == ThemeMode.dark
                    ? 'Dark'
                    : themeMode == ThemeMode.light
                        ? 'Light'
                        : 'System',
                isDark: isDark,
                onTap: () => _showThemePicker(context),
              ),

              const SizedBox(height: 16),
              _SectionHeader('Data', isDark),
              const SizedBox(height: 8),

              _SettingTile(
                icon: Icons.receipt_long_outlined,
                title: 'Expenses',
                subtitle: 'Manage your expenses',
                isDark: isDark,
                onTap: () => context.push('/expenses'),
              ),
              _SettingTile(
                icon: Icons.account_balance_outlined,
                title: 'Income',
                subtitle: 'Manage your income',
                isDark: isDark,
                onTap: () => context.push('/income'),
              ),
              _SettingTile(
                icon: Icons.account_balance_wallet_outlined,
                title: 'Budgets',
                subtitle: 'Manage your budgets',
                isDark: isDark,
                onTap: () => context.push('/budget'),
              ),
              _SettingTile(
                icon: Icons.savings_outlined,
                title: 'Savings Goals',
                subtitle: 'Manage your goals',
                isDark: isDark,
                onTap: () => context.push('/savings'),
              ),
              _SettingTile(
                icon: Icons.picture_as_pdf_outlined,
                title: 'Reports',
                subtitle: 'Export financial reports',
                isDark: isDark,
                onTap: () => context.push('/reports'),
              ),

              const SizedBox(height: 16),
              _SectionHeader('Account', isDark),
              const SizedBox(height: 8),

              _NotificationSettingsCard(isDark: isDark),

              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    await ref.read(authNotifierProvider.notifier).signOut();
                  },
                  icon: const Icon(Icons.logout, color: AppColors.error),
                  label: Text('Sign Out',
                      style: GoogleFonts.poppins(color: AppColors.error)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.error),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
              const SizedBox(height: 80),
            ],
          );
        },
      ),
    );
  }

  void _showCurrencyPicker(BuildContext context, ProfileModel profile) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text('Select Currency',
                style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600)),
          ),
          ...AppConstants.currencies.map((c) => ListTile(
            title: Text('${c['code']} - ${c['name']}', style: GoogleFonts.poppins()),
            leading: Text(c['symbol']!, style: const TextStyle(fontSize: 20)),
            trailing: profile.currency == c['code']
                ? const Icon(Icons.check, color: AppColors.primary)
                : null,
            onTap: () {
              ref.read(profileProvider.notifier).updateProfile(
                    profile.copyWith(currency: c['code']),
                  );
              Navigator.pop(ctx);
            },
          )),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  void _showThemePicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text('Theme',
                style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600)),
          ),
          ListTile(
            leading: const Icon(Icons.brightness_auto),
            title: Text('System Default', style: GoogleFonts.poppins()),
            onTap: () {
              ref.read(themeModeProvider.notifier).setThemeMode(ThemeMode.system);
              Navigator.pop(ctx);
            },
          ),
          ListTile(
            leading: const Icon(Icons.light_mode),
            title: Text('Light', style: GoogleFonts.poppins()),
            onTap: () {
              ref.read(themeModeProvider.notifier).setThemeMode(ThemeMode.light);
              Navigator.pop(ctx);
            },
          ),
          ListTile(
            leading: const Icon(Icons.dark_mode),
            title: Text('Dark', style: GoogleFonts.poppins()),
            onTap: () {
              ref.read(themeModeProvider.notifier).setThemeMode(ThemeMode.dark);
              Navigator.pop(ctx);
            },
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final bool isDark;
  const _SectionHeader(this.title, this.isDark);

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: GoogleFonts.poppins(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: isDark ? AppColors.darkSubtext : AppColors.lightSubtext,
        letterSpacing: 0.5,
      ),
    );
  }
}

// ── Notification Settings Card ────────────────────────────────────────────────

class _NotificationSettingsCard extends StatefulWidget {
  final bool isDark;
  const _NotificationSettingsCard({required this.isDark});

  @override
  State<_NotificationSettingsCard> createState() =>
      _NotificationSettingsCardState();
}

class _NotificationSettingsCardState
    extends State<_NotificationSettingsCard> {
  final _svc = NotificationService();
  bool _spendingReminder = false;
  String _spendingInterval = '1hour';
  bool _dailySummary = false;
  bool _weeklyReport = false;
  bool _budgetAlert = true;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final s = await _svc.getSettings();
    if (mounted) {
      setState(() {
        _spendingReminder = s['spending_reminder'] as bool;
        _spendingInterval = s['spending_interval'] as String;
        _dailySummary = s['daily_summary'] as bool;
        _weeklyReport = s['weekly_report'] as bool;
        _budgetAlert = s['budget_alert'] as bool;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final textColor =
        widget.isDark ? AppColors.darkText : AppColors.lightText;
    final subColor =
        widget.isDark ? AppColors.darkSubtext : AppColors.lightSubtext;
    final cardColor =
        widget.isDark ? AppColors.darkCard : AppColors.lightCard;
    final borderColor =
        widget.isDark ? AppColors.darkBorder : AppColors.lightBorder;

    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: const Icon(Icons.notifications_active_rounded,
                    color: AppColors.primary, size: 18),
              ),
              const SizedBox(width: 10),
              Text('Push Notifications',
                  style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: textColor)),
            ]),
          ),
          const Divider(height: 1),

          if (_loading)
            const Padding(
              padding: EdgeInsets.all(20),
              child: Center(child: CircularProgressIndicator()),
            )
          else ...[

            // ── Spending Reminder ──────────────────────────────────────
            _NotifRow(
              icon: Icons.timer_rounded,
              color: AppColors.primary,
              title: 'Spending Reminder',
              subtitle: 'Reminds you to log expenses',
              value: _spendingReminder,
              isDark: widget.isDark,
              onChanged: (v) async {
                final granted = await _svc.requestPermission();
                if (!granted && mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('Please enable notifications in Settings'),
                    backgroundColor: AppColors.warning,
                  ));
                  return;
                }
                setState(() => _spendingReminder = v);
                if (v) {
                  await _svc.scheduleSpendingReminder(_spendingInterval);
                } else {
                  await _svc.cancelSpendingReminder();
                }
              },
            ),

            // Interval picker (only visible when reminder is ON)
            if (_spendingReminder)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Reminder interval',
                        style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: subColor)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _IntervalChip(
                          label: '30 min',
                          value: '30min',
                          selected: _spendingInterval == '30min',
                          isDark: widget.isDark,
                          onTap: () async {
                            setState(() => _spendingInterval = '30min');
                            await _svc.scheduleSpendingReminder('30min');
                          },
                        ),
                        const SizedBox(width: 8),
                        _IntervalChip(
                          label: '1 hour',
                          value: '1hour',
                          selected: _spendingInterval == '1hour',
                          isDark: widget.isDark,
                          onTap: () async {
                            setState(() => _spendingInterval = '1hour');
                            await _svc.scheduleSpendingReminder('1hour');
                          },
                        ),
                        const SizedBox(width: 8),
                        _IntervalChip(
                          label: '2 hours',
                          value: '2hours',
                          selected: _spendingInterval == '2hours',
                          isDark: widget.isDark,
                          onTap: () async {
                            setState(() => _spendingInterval = '2hours');
                            await _svc.scheduleSpendingReminder('2hours');
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),

            const Divider(height: 1),

            // ── Daily Summary ──────────────────────────────────────────
            _NotifRow(
              icon: Icons.bar_chart_rounded,
              color: AppColors.accent,
              title: 'Daily Summary',
              subtitle: 'Spending recap at 9 PM every day',
              value: _dailySummary,
              isDark: widget.isDark,
              onChanged: (v) async {
                setState(() => _dailySummary = v);
                await _svc.scheduleDailySummary(v);
              },
            ),
            const Divider(height: 1),

            // ── Weekly Report ──────────────────────────────────────────
            _NotifRow(
              icon: Icons.calendar_today_rounded,
              color: AppColors.savings,
              title: 'Weekly Report',
              subtitle: 'Every Monday at 8 AM',
              value: _weeklyReport,
              isDark: widget.isDark,
              onChanged: (v) async {
                setState(() => _weeklyReport = v);
                await _svc.scheduleWeeklyReport(v);
              },
            ),
            const Divider(height: 1),

            // ── Budget Alert ───────────────────────────────────────────
            _NotifRow(
              icon: Icons.warning_amber_rounded,
              color: AppColors.warning,
              title: 'Budget Alerts',
              subtitle: 'Alert when 80%+ of budget is used',
              value: _budgetAlert,
              isDark: widget.isDark,
              onChanged: (v) async {
                setState(() => _budgetAlert = v);
                await _svc.setBudgetAlertEnabled(v);
              },
            ),
          ],
        ],
      ),
    );
  }
}

class _NotifRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final bool value;
  final bool isDark;
  final ValueChanged<bool> onChanged;

  const _NotifRow({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.isDark,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(9),
          ),
          child: Icon(icon, color: color, size: 17),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title,
                style: GoogleFonts.poppins(
                    fontSize: 13, fontWeight: FontWeight.w600)),
            Text(subtitle,
                style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: isDark
                        ? AppColors.darkSubtext
                        : AppColors.lightSubtext)),
          ]),
        ),
        Switch.adaptive(
          value: value,
          onChanged: onChanged,
          activeColor: AppColors.primary,
        ),
      ]),
    );
  }
}

class _IntervalChip extends StatelessWidget {
  final String label;
  final String value;
  final bool selected;
  final bool isDark;
  final VoidCallback onTap;

  const _IntervalChip({
    required this.label,
    required this.value,
    required this.selected,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected
                ? AppColors.primary
                : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: selected
                ? Colors.white
                : (isDark ? AppColors.darkText : AppColors.lightText),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _SettingTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool isDark;
  final VoidCallback onTap;

  const _SettingTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
      ),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: AppColors.primary, size: 20),
        ),
        title: Text(title, style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w500)),
        subtitle: Text(subtitle,
            style: GoogleFonts.poppins(
                fontSize: 12,
                color: isDark ? AppColors.darkSubtext : AppColors.lightSubtext)),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
