import 'package:flutter/material.dart';

import '../app_store.dart';
import '../localization.dart';
import '../models.dart';

class ProfileOnboardingScreen extends StatefulWidget {
  const ProfileOnboardingScreen({
    super.key,
    required this.store,
    required this.l10n,
  });

  final AppStore store;
  final AppLocalizations l10n;

  @override
  State<ProfileOnboardingScreen> createState() =>
      _ProfileOnboardingScreenState();
}

class _ProfileOnboardingScreenState extends State<ProfileOnboardingScreen> {
  late final TextEditingController _fullNameController;
  late final TextEditingController _emailController;
  late final TextEditingController _phoneController;
  late final TextEditingController _stateController;
  late final TextEditingController _cityController;
  late final TextEditingController _addressController;
  late final TextEditingController _organizationController;
  late final TextEditingController _registrationController;
  UserRole? _selectedRole;

  @override
  void initState() {
    super.initState();
    final draft = widget.store.pendingProfileDraft ?? const ProfileSetupDraft();
    _fullNameController = TextEditingController(text: draft.fullName);
    _emailController = TextEditingController(text: draft.email);
    _phoneController = TextEditingController(text: draft.phone);
    _stateController = TextEditingController(text: draft.state);
    _cityController = TextEditingController(text: draft.city);
    _addressController = TextEditingController(text: draft.address);
    _organizationController =
        TextEditingController(text: draft.organizationName);
    _registrationController = TextEditingController(text: draft.registrationId);
    _selectedRole = draft.role;
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _stateController.dispose();
    _cityController.dispose();
    _addressController.dispose();
    _organizationController.dispose();
    _registrationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.store,
      builder: (context, _) {
        final isBusy = widget.store.isAuthBusy;
        final theme = Theme.of(context);
        final needsOrganization = _selectedRole == UserRole.contractor ||
            _selectedRole == UserRole.ngo;

        return Scaffold(
          appBar: AppBar(
            title: Text(widget.l10n.t('auth.profileSetup')),
            actions: [
              IconButton(
                onPressed: isBusy ? null : () => widget.store.logout(),
                icon: const Icon(Icons.logout_rounded),
                tooltip: widget.l10n.t('common.logout'),
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            children: [
              Text(
                widget.l10n.t('auth.profileSetup'),
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                widget.l10n.t('auth.profileSubtitle'),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFF52606F),
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _fullNameController,
                enabled: !isBusy,
                decoration: _fieldDecoration(widget.l10n.t('auth.fullName')),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _emailController,
                enabled: false,
                decoration: _fieldDecoration(widget.l10n.t('common.email')),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _phoneController,
                enabled: !isBusy,
                keyboardType: TextInputType.phone,
                decoration: _fieldDecoration(widget.l10n.t('common.phone')),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<UserRole>(
                initialValue: _selectedRole,
                decoration: _fieldDecoration(widget.l10n.t('auth.role')),
                items: UserRole.values
                    .map(
                      (role) => DropdownMenuItem(
                        value: role,
                        child: Text(widget.l10n.roleLabel(role)),
                      ),
                    )
                    .toList(),
                onChanged: isBusy
                    ? null
                    : (value) => setState(() => _selectedRole = value),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _stateController,
                enabled: !isBusy,
                decoration: _fieldDecoration(widget.l10n.t('common.state')),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _cityController,
                enabled: !isBusy,
                decoration: _fieldDecoration(widget.l10n.t('common.city')),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _addressController,
                enabled: !isBusy,
                maxLines: 2,
                decoration: _fieldDecoration(widget.l10n.t('auth.address')),
              ),
              if (needsOrganization) ...[
                const SizedBox(height: 12),
                TextField(
                  controller: _organizationController,
                  enabled: !isBusy,
                  decoration: _fieldDecoration(
                    widget.l10n.t('auth.organizationName'),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              TextField(
                controller: _registrationController,
                enabled: !isBusy,
                decoration: _fieldDecoration(
                  widget.l10n.t('common.registration'),
                ),
              ),
              if (widget.store.authMessage != null) ...[
                const SizedBox(height: 14),
                Text(
                  widget.store.authMessage!,
                  style: const TextStyle(
                    color: Color(0xFFB91C1C),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: isBusy ? null : _saveProfile,
                  icon: isBusy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.verified_user_rounded),
                  label: Text(widget.l10n.t('auth.completeProfile')),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  InputDecoration _fieldDecoration(String label) {
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide.none,
      ),
    );
  }

  Future<void> _saveProfile() async {
    widget.store.clearAuthMessage();
    final draft = ProfileSetupDraft(
      fullName: _fullNameController.text.trim(),
      email: _emailController.text.trim(),
      phone: _phoneController.text.trim(),
      role: _selectedRole,
      state: _stateController.text.trim(),
      city: _cityController.text.trim(),
      address: _addressController.text.trim(),
      organizationName: _organizationController.text.trim(),
      registrationId: _registrationController.text.trim(),
    );
    if (!draft.isComplete) {
      _showMessage(widget.l10n.t('citizen.requiredFields'));
      return;
    }
    try {
      final message = await widget.store.completeProfile(draft);
      if (!mounted) {
        return;
      }
      _showMessage(message);
    } catch (_) {
      if (!mounted) {
        return;
      }
      if (widget.store.authMessage != null) {
        _showMessage(widget.store.authMessage!);
      }
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}
