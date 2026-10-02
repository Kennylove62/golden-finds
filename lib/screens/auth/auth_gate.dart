import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../models/app_user.dart';
import '../../services/auth_service.dart';
import '../client/client_home_screen.dart';
import '../seller/seller_dashboard_screen.dart';
import '../visitor/home_screen.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  final AuthService _authService = AuthService();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: _authService.authStateChanges,
      initialData: _authService.currentUser,
      builder: (context, authSnapshot) {
        if (authSnapshot.connectionState == ConnectionState.waiting &&
            authSnapshot.data == null) {
          return const _GoldenLoadingScreen(
            message: 'Checking your session...',
          );
        }

        final firebaseUser = authSnapshot.data;

        if (firebaseUser == null) {
          return const VisitorHomeScreen();
        }

        return StreamBuilder<AppUser?>(
          stream: _authService.watchProfile(firebaseUser),
          builder: (context, profileSnapshot) {
            if (profileSnapshot.connectionState == ConnectionState.waiting &&
                profileSnapshot.data == null) {
              return _GoldenLoadingScreen(
                message: 'Welcome ${firebaseUser.displayName ?? ''}...',
              );
            }

            if (profileSnapshot.hasError) {
              return _ProfileErrorScreen(
                firebaseUser: firebaseUser,
                error: profileSnapshot.error,
              );
            }

            final profile = profileSnapshot.data;

            if (profile == null) {
              return const _GoldenLoadingScreen(
                message: 'Loading your profile...',
              );
            }

            final role = profile.role.trim().toLowerCase();

            if (role == 'seller') {
              return SellerDashboardScreen(user: profile);
            }

            return ClientHomeScreen(user: profile);
          },
        );
      },
    );
  }
}

class _GoldenLoadingScreen extends StatelessWidget {
  const _GoldenLoadingScreen({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF090909),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: const Color(0xFF151515),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFD6B35A)),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFD6B35A).withValues(alpha: 0.20),
                    blurRadius: 32,
                  ),
                ],
              ),
              child: const Icon(
                Icons.diamond_outlined,
                color: Color(0xFFF2D57E),
                size: 42,
              ),
            ),
            const SizedBox(height: 26),
            const Text(
              'GOLDEN FINDS',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w900,
                letterSpacing: 3,
              ),
            ),
            const SizedBox(height: 22),
            const SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(
                color: Color(0xFFD6B35A),
                strokeWidth: 2.5,
              ),
            ),
            const SizedBox(height: 18),
            Text(message, style: const TextStyle(color: Colors.white54)),
          ],
        ),
      ),
    );
  }
}

class _ProfileErrorScreen extends StatelessWidget {
  const _ProfileErrorScreen({required this.firebaseUser, required this.error});

  final User firebaseUser;
  final Object? error;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF7F2),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 560),
            padding: const EdgeInsets.all(30),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: const Color(0xFFFFD8C7)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 78,
                  height: 78,
                  decoration: const BoxDecoration(
                    color: Color(0xFFFFE9DF),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.cloud_off_outlined,
                    color: Color(0xFFB94A2E),
                    size: 36,
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Account connected',
                  style: TextStyle(fontSize: 25, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 8),
                Text(
                  firebaseUser.email ?? '',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.black54),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Firebase Authentication accepted your account, '
                  'but Golden Finds could not read your Firestore profile.',
                  textAlign: TextAlign.center,
                  style: TextStyle(height: 1.5),
                ),
                const SizedBox(height: 18),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8F8F8),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    error.toString(),
                    style: const TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () async {
                      await AuthService().logout();
                    },
                    icon: const Icon(Icons.logout_rounded),
                    label: const Text('Sign out'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
