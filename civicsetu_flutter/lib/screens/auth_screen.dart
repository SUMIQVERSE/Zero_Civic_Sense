import 'package:flutter/material.dart';

import '../app_store.dart';
import '../localization.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key, required this.store, required this.l10n});

  final AppStore store;
  final AppLocalizations l10n;

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isRegister = false;

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.store,
      builder: (context, _) {
        final theme = Theme.of(context);
        final isBusy = widget.store.isAuthBusy;

        return Scaffold(
          body: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color(0xFF08111E),
                  Color(0xFF173451),
                  Color(0xFFECE3D6)
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            child: SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 440),
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 58,
                              height: 58,
                              decoration: BoxDecoration(
                                color: const Color(0xFFE8821C),
                                borderRadius: BorderRadius.circular(18),
                              ),
                              child: const Icon(
                                Icons.location_city_rounded,
                                color: Colors.white,
                                size: 30,
                              ),
                            ),
                            const SizedBox(height: 18),
                            Text(
                              widget.l10n.t('auth.title'),
                              style: theme.textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              widget.l10n.t('auth.subtitle'),
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: const Color(0xFF52606F),
                                height: 1.4,
                              ),
                            ),
                            const SizedBox(height: 22),
                            Row(
                              children: [
                                Expanded(
                                  child: FilledButton(
                                    onPressed: isBusy
                                        ? null
                                        : () =>
                                            setState(() => _isRegister = false),
                                    style: FilledButton.styleFrom(
                                      backgroundColor: _isRegister
                                          ? theme.colorScheme
                                              .surfaceContainerHighest
                                          : theme.colorScheme.primary,
                                      foregroundColor: _isRegister
                                          ? theme.colorScheme.onSurface
                                          : theme.colorScheme.onPrimary,
                                    ),
                                    child: Text(widget.l10n.t('auth.signIn')),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: FilledButton(
                                    onPressed: isBusy
                                        ? null
                                        : () =>
                                            setState(() => _isRegister = true),
                                    style: FilledButton.styleFrom(
                                      backgroundColor: _isRegister
                                          ? theme.colorScheme.primary
                                          : theme.colorScheme
                                              .surfaceContainerHighest,
                                      foregroundColor: _isRegister
                                          ? theme.colorScheme.onPrimary
                                          : theme.colorScheme.onSurface,
                                    ),
                                    child: Text(widget.l10n.t('auth.signUp')),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),
                            if (_isRegister) ...[
                              TextField(
                                controller: _fullNameController,
                                enabled: !isBusy,
                                textInputAction: TextInputAction.next,
                                decoration: _fieldDecoration(
                                  widget.l10n.t('auth.fullName'),
                                ),
                              ),
                              const SizedBox(height: 12),
                            ],
                            TextField(
                              controller: _emailController,
                              enabled: !isBusy,
                              keyboardType: TextInputType.emailAddress,
                              textInputAction: TextInputAction.next,
                              decoration: _fieldDecoration(
                                widget.l10n.t('common.email'),
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _passwordController,
                              enabled: !isBusy,
                              obscureText: true,
                              textInputAction: _isRegister
                                  ? TextInputAction.next
                                  : TextInputAction.done,
                              decoration: _fieldDecoration(
                                widget.l10n.t('auth.password'),
                              ),
                            ),
                            if (_isRegister) ...[
                              const SizedBox(height: 12),
                              TextField(
                                controller: _confirmPasswordController,
                                enabled: !isBusy,
                                obscureText: true,
                                textInputAction: TextInputAction.done,
                                decoration: _fieldDecoration(
                                  widget.l10n.t('auth.confirmPassword'),
                                ),
                              ),
                            ],
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
                            const SizedBox(height: 18),
                            SizedBox(
                              width: double.infinity,
                              child: FilledButton.icon(
                                onPressed: isBusy ? null : _submit,
                                icon: isBusy
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2),
                                      )
                                    : Icon(
                                        _isRegister
                                            ? Icons.person_add_alt_1_rounded
                                            : Icons.login_rounded,
                                      ),
                                label: Text(
                                  _isRegister
                                      ? widget.l10n.t('auth.createAccount')
                                      : widget.l10n.t('auth.signIn'),
                                ),
                              ),
                            ),
                            const SizedBox(height: 14),
                            Row(
                              children: [
                                const Expanded(child: Divider()),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12),
                                  child: Text(
                                      widget.l10n.t('auth.orContinueWith')),
                                ),
                                const Expanded(child: Divider()),
                              ],
                            ),
                            const SizedBox(height: 14),
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                onPressed: isBusy ? null : _continueWithGoogle,
                                icon: const Icon(Icons.g_mobiledata_rounded,
                                    size: 28),
                                label: Text(
                                  widget.l10n.t('auth.continueWithGoogle'),
                                ),
                              ),
                            ),
                            const SizedBox(height: 14),
                            Text(
                              _isRegister
                                  ? widget.l10n.t('auth.registerHint')
                                  : widget.l10n.t('auth.signInHint'),
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: const Color(0xFF52606F),
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
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

  Future<void> _submit() async {
    widget.store.clearAuthMessage();
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    if (email.isEmpty || password.isEmpty) {
      _showMessage(widget.l10n.t('citizen.requiredFields'));
      return;
    }
    if (_isRegister) {
      if (_fullNameController.text.trim().isEmpty) {
        _showMessage(widget.l10n.t('citizen.requiredFields'));
        return;
      }
      if (password.length < 6) {
        _showMessage(widget.l10n.t('auth.passwordTooShort'));
        return;
      }
      if (password != _confirmPasswordController.text) {
        _showMessage(widget.l10n.t('auth.passwordMismatch'));
        return;
      }
    }

    try {
      final message = _isRegister
          ? await widget.store.signUpWithPassword(
              fullName: _fullNameController.text.trim(),
              email: email,
              password: password,
            )
          : await widget.store.signInWithPassword(
              email: email,
              password: password,
            );
      if (!mounted) {
        return;
      }
      if (_isRegister && message.contains('Verify your email')) {
        setState(() => _isRegister = false);
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

  Future<void> _continueWithGoogle() async {
    widget.store.clearAuthMessage();
    try {
      final message = await widget.store.signInWithGoogle();
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
