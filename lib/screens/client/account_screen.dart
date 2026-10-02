import 'package:flutter/material.dart';

import '../../models/app_user.dart';
import '../../services/auth_service.dart';

class AccountScreen extends StatelessWidget {
  const AccountScreen({super.key, required this.user});

  final AppUser user;

  @override
  Widget build(BuildContext context) {
    final isSeller = user.role == 'seller';

    final primary = isSeller
        ? const Color(0xFF57202A)
        : const Color(0xFF0D2235);

    final accent = isSeller ? const Color(0xFFF4B64A) : const Color(0xFF18A999);

    final background = isSeller
        ? const Color(0xFFFFF8EE)
        : const Color(0xFFF2F8FA);

    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        backgroundColor: background,
        title: Text(
          isSeller ? 'Seller Profile' : 'Client Profile',
          style: TextStyle(color: primary, fontWeight: FontWeight.w900),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 14, 24, 40),
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(30),
              decoration: BoxDecoration(
                color: primary,
                borderRadius: BorderRadius.circular(isSeller ? 22 : 32),
              ),
              child: Column(
                children: [
                  Container(
                    width: 92,
                    height: 92,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: accent,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      user.name.trim().isNotEmpty
                          ? user.name.trim()[0].toUpperCase()
                          : 'G',
                      style: TextStyle(
                        color: primary,
                        fontSize: 36,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    user.name,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    user.email,
                    style: const TextStyle(color: Colors.white60),
                  ),
                  const SizedBox(height: 18),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(color: accent),
                    ),
                    child: Text(
                      isSeller ? 'SELLER ACCOUNT' : 'CLIENT ACCOUNT',
                      style: TextStyle(
                        color: accent,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 26),

            _ProfileInfo(
              icon: Icons.person_outline,
              title: 'Full name',
              value: user.name,
              primary: primary,
              accent: accent,
            ),

            const SizedBox(height: 12),

            _ProfileInfo(
              icon: Icons.email_outlined,
              title: 'Email',
              value: user.email,
              primary: primary,
              accent: accent,
            ),

            const SizedBox(height: 12),

            _ProfileInfo(
              icon: Icons.phone_outlined,
              title: 'Phone',
              value: user.phone.isEmpty ? 'Not provided' : user.phone,
              primary: primary,
              accent: accent,
            ),

            if (isSeller) ...[
              const SizedBox(height: 12),
              _ProfileInfo(
                icon: Icons.chat_outlined,
                title: 'WhatsApp',
                value: user.whatsappNumber?.isNotEmpty == true
                    ? user.whatsappNumber!
                    : 'Not provided',
                primary: primary,
                accent: accent,
              ),
            ],

            const SizedBox(height: 30),

            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: primary,
                  foregroundColor: Colors.white,
                ),
                onPressed: () async {
                  await AuthService().logout();

                  if (!context.mounted) {
                    return;
                  }

                  Navigator.of(context).popUntil((route) => route.isFirst);
                },
                icon: const Icon(Icons.logout_rounded),
                label: const Text(
                  'Sign out',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileInfo extends StatelessWidget {
  const _ProfileInfo({
    required this.icon,
    required this.title,
    required this.value,
    required this.primary,
    required this.accent,
  });

  final IconData icon;
  final String title;
  final String value;
  final Color primary;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: primary.withValues(alpha: 0.10)),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.13),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: primary),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(color: Colors.black45, fontSize: 11),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(color: primary, fontWeight: FontWeight.w800),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
