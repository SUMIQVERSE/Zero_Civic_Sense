import 'dart:io';

import 'package:flutter/material.dart';

import '../app_store.dart';
import '../localization.dart';
import '../models.dart';

class PortalScaffold extends StatelessWidget {
  const PortalScaffold({
    super.key,
    required this.store,
    required this.l10n,
    required this.title,
    required this.child,
    this.floatingActionButton,
    this.floatingActionButtonLocation,
  });

  final AppStore store;
  final AppLocalizations l10n;
  final String title;
  final Widget child;
  final Widget? floatingActionButton;
  final FloatingActionButtonLocation? floatingActionButtonLocation;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
            Text(
              l10n.t('app.tagline'),
              style: Theme.of(context).textTheme.labelMedium,
            ),
          ],
        ),
        actions: [
          PopupMenuButton<AppLanguage>(
            tooltip: l10n.t('common.language'),
            onSelected: (value) {
              store.setLanguage(value);
            },
            itemBuilder: (context) {
              return AppLanguage.values.map((lang) {
                return PopupMenuItem<AppLanguage>(
                  value: lang,
                  child: Text(lang.label),
                );
              }).toList();
            },
            icon: Chip(label: Text(store.language.label)),
          ),
          IconButton(
            tooltip: l10n.t('common.logout'),
            onPressed: () {
              store.logout();
            },
            icon: const Icon(Icons.logout_rounded),
          ),
        ],
      ),
      body: child,
      floatingActionButton: floatingActionButton,
      floatingActionButtonLocation: floatingActionButtonLocation,
    );
  }
}

class StatCard extends StatelessWidget {
  const StatCard({
    super.key,
    required this.label,
    required this.value,
    this.color = const Color(0xFF0B1C2D),
    this.background = Colors.white,
    this.icon,
  });

  final String label;
  final String value;
  final Color color;
  final Color background;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: background,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (icon != null) ...[
              Icon(icon, color: color),
              const SizedBox(height: 10),
            ],
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
            const SizedBox(height: 6),
            Text(label, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

class AppImage extends StatelessWidget {
  const AppImage({
    super.key,
    required this.source,
    this.height = 160,
    this.borderRadius = 18,
  });

  final String source;
  final double height;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final imageWidget = isNetworkResource(source)
        ? Image.network(source, fit: BoxFit.cover, errorBuilder: _fallback)
        : File(source).existsSync()
            ? Image.file(File(source),
                fit: BoxFit.cover, errorBuilder: _fallback)
            : _fallback(context, Object(), StackTrace.empty);

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: imageWidget,
      ),
    );
  }

  Widget _fallback(BuildContext context, Object error, StackTrace? stackTrace) {
    return Container(
      color: const Color(0xFFE5E7EB),
      alignment: Alignment.center,
      child: const Icon(Icons.image_not_supported_outlined, size: 32),
    );
  }
}

class InfoPill extends StatelessWidget {
  const InfoPill({
    super.key,
    required this.label,
    this.color = const Color(0xFF0B1C2D),
    this.background = const Color(0xFFF3F4F6),
    this.icon,
  });

  final String label;
  final Color color;
  final Color background;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 6),
          ],
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class CommentSection extends StatefulWidget {
  const CommentSection({
    super.key,
    required this.store,
    required this.l10n,
    required this.issue,
  });

  final AppStore store;
  final AppLocalizations l10n;
  final Issue issue;

  @override
  State<CommentSection> createState() => _CommentSectionState();
}

class _CommentSectionState extends State<CommentSection> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final comments = widget.store.commentsFor(widget.issue.id);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.l10n.t('common.comments'),
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
        if (comments.isEmpty)
          Text(widget.l10n.t('common.noComments'))
        else
          ...comments.map(
            (comment) => Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    comment.userName,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  Text(comment.content),
                  const SizedBox(height: 4),
                  Text(
                    formatShortDate(comment.createdAt),
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ],
              ),
            ),
          ),
        const SizedBox(height: 12),
        TextField(
          controller: _controller,
          decoration: InputDecoration(
            hintText: widget.l10n.t('common.addComment'),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
          ),
          maxLines: 2,
        ),
        const SizedBox(height: 8),
        FilledButton(
          onPressed: _submit,
          child: Text(widget.l10n.t('common.submit')),
        ),
      ],
    );
  }

  void _submit() {
    final user = widget.store.currentUser;
    final text = _controller.text.trim();
    if (user == null || text.isEmpty) {
      return;
    }
    widget.store.addComment(
      IssueComment(
        id: 'comment-${DateTime.now().microsecondsSinceEpoch}',
        issueId: widget.issue.id,
        userId: user.id,
        userName: user.fullName,
        content: text,
        createdAt: DateTime.now(),
      ),
    );
    _controller.clear();
    setState(() {});
  }
}
