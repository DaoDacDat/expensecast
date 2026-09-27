import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../viewmodels/auth_view_model.dart';
import '../widgets/privacy_note.dart';
import 'history_view.dart';
import 'login_view.dart';

/// Tab "More": History & Export + Settings & Privacy (Figure 9).
class MoreView extends StatefulWidget {
  const MoreView({super.key});

  @override
  State<MoreView> createState() => _MoreViewState();
}

class _MoreViewState extends State<MoreView> {
  bool _syncOptIn = false;
  bool _notifyAtRisk = true;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final auth = context.watch<AuthViewModel>();

    return Scaffold(
      appBar: AppBar(title: const Text('More')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          ListTile(
            leading: const CircleAvatar(child: Icon(Icons.person_outline)),
            title: Text(auth.email.isEmpty ? 'Signed in' : auth.email),
            subtitle: const Text('Local account'),
          ),
          const Divider(height: 24),

          ListTile(
            leading: const Icon(Icons.history),
            title: const Text('History & Export'),
            subtitle: const Text('Browse past transactions, export CSV'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const HistoryView()),
            ),
          ),
          const Divider(height: 24),

          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(
              'Privacy',
              style: theme.textTheme.titleSmall?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          SwitchListTile(
            value: _syncOptIn,
            onChanged: (v) => setState(() => _syncOptIn = v),
            title: const Text('Encrypted backup & sync'),
            subtitle: const Text(
              'Off by default. Only encrypted transaction metadata is sent — '
              'never receipt images.',
            ),
          ),
          SwitchListTile(
            value: _notifyAtRisk,
            onChanged: (v) => setState(() => _notifyAtRisk = v),
            title: const Text('At-risk notifications'),
            subtitle: const Text(
              'Alert me when a category is predicted to exceed its budget.',
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: PrivacyNote(
              text: 'OCR and forecasting run on this device. Receipt images are '
                  'deleted after the fields are extracted.',
            ),
          ),

          const Divider(height: 32),
          ListTile(
            leading: Icon(Icons.logout, color: theme.colorScheme.error),
            title: Text(
              'Log out',
              style: TextStyle(color: theme.colorScheme.error),
            ),
            onTap: () {
              context.read<AuthViewModel>().signOut();
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const LoginView()),
                (route) => false,
              );
            },
          ),
          const SizedBox(height: 12),
          Center(
            child: Text(
              'ExpenseCast · Milestone 1 build',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
