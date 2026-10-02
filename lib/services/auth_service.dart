import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/app_user.dart';

class AuthService {
  AuthService({FirebaseAuth? auth, FirebaseFirestore? firestore})
    : _authOverride = auth,
      _firestoreOverride = firestore;

  final FirebaseAuth? _authOverride;
  final FirebaseFirestore? _firestoreOverride;

  FirebaseAuth get _auth {
    return _authOverride ?? FirebaseAuth.instance;
  }

  FirebaseFirestore get _firestore {
    return _firestoreOverride ?? FirebaseFirestore.instance;
  }

  Stream<User?> get authStateChanges {
    return _auth.authStateChanges();
  }

  User? get currentUser {
    return _auth.currentUser;
  }

  Stream<AppUser?> watchProfile(User firebaseUser) {
    return _firestore.collection('users').doc(firebaseUser.uid).snapshots().map(
      (document) {
        final data = document.data();

        if (!document.exists || data == null) {
          return AppUser(
            uid: firebaseUser.uid,
            name: firebaseUser.displayName?.trim().isNotEmpty == true
                ? firebaseUser.displayName!.trim()
                : 'Golden Finds Client',
            email: firebaseUser.email ?? '',
            phone: '',
            role: 'client',
          );
        }

        return AppUser.fromMap(data);
      },
    );
  }

  Stream<AppUser?> get currentAppUserStream {
    return _auth.authStateChanges().asyncExpand((firebaseUser) {
      if (firebaseUser == null) {
        return Stream<AppUser?>.value(null);
      }

      return watchProfile(firebaseUser);
    });
  }

  Future<AppUser> register({
    required String name,
    required String email,
    required String password,
    required String phone,
    required String role,
    String? whatsappNumber,
  }) async {
    UserCredential? credential;

    try {
      final cleanName = name.trim();
      final cleanEmail = email.trim();
      final cleanPhone = phone.trim();
      final cleanWhatsapp = whatsappNumber?.trim();

      if (cleanName.length < 2) {
        throw Exception('Enter your full name.');
      }

      if (role != 'client' && role != 'seller') {
        throw Exception('Invalid Golden Finds role.');
      }

      if (role == 'seller' &&
          (cleanWhatsapp == null || cleanWhatsapp.isEmpty)) {
        throw Exception('Seller WhatsApp number is required.');
      }

      credential = await _auth.createUserWithEmailAndPassword(
        email: cleanEmail,
        password: password,
      );

      final firebaseUser = credential.user;

      if (firebaseUser == null) {
        throw Exception('Unable to create Firebase account.');
      }

      await firebaseUser.updateDisplayName(cleanName);

      final appUser = AppUser(
        uid: firebaseUser.uid,
        name: cleanName,
        email: cleanEmail,
        phone: cleanPhone,
        role: role,
        whatsappNumber: cleanWhatsapp == null || cleanWhatsapp.isEmpty
            ? null
            : cleanWhatsapp,
      );

      await _firestore.collection('users').doc(firebaseUser.uid).set({
        ...appUser.toMap(),
        'createdAt': FieldValue.serverTimestamp(),
      });

      return appUser;
    } catch (error) {
      final createdUser = credential?.user;

      if (createdUser != null) {
        try {
          await createdUser.delete();
        } catch (_) {}
      }

      rethrow;
    }
  }

  Future<UserCredential> login({
    required String email,
    required String password,
  }) async {
    final cleanEmail = email.trim();

    final credential = await _auth.signInWithEmailAndPassword(
      email: cleanEmail,
      password: password,
    );

    if (credential.user == null) {
      throw Exception('Unable to sign in.');
    }

    return credential;
  }

  Future<AppUser?> getCurrentAppUser() async {
    final firebaseUser = _auth.currentUser;

    if (firebaseUser == null) {
      return null;
    }

    final document = await _firestore
        .collection('users')
        .doc(firebaseUser.uid)
        .get();

    final data = document.data();

    if (!document.exists || data == null) {
      return AppUser(
        uid: firebaseUser.uid,
        name: firebaseUser.displayName?.trim().isNotEmpty == true
            ? firebaseUser.displayName!.trim()
            : 'Golden Finds Client',
        email: firebaseUser.email ?? '',
        phone: '',
        role: 'client',
      );
    }

    return AppUser.fromMap(data);
  }

  Future<void> updateProfile({
    required AppUser currentProfile,
    required String name,
    required String phone,
    String? whatsappNumber,
  }) async {
    final firebaseUser = _auth.currentUser;

    if (firebaseUser == null) {
      throw Exception('Your session has expired.');
    }

    if (firebaseUser.uid != currentProfile.uid) {
      throw Exception('You cannot edit another user profile.');
    }

    final cleanName = name.trim();
    final cleanPhone = phone.trim();
    final cleanWhatsapp = whatsappNumber?.trim() ?? '';

    if (cleanName.length < 2) {
      throw Exception('Enter a valid full name.');
    }

    if (cleanPhone.length < 5) {
      throw Exception('Enter a valid phone number.');
    }

    if (currentProfile.isSeller && cleanWhatsapp.length < 5) {
      throw Exception('Enter a valid seller WhatsApp number.');
    }

    await firebaseUser.updateDisplayName(cleanName);

    final userReference = _firestore
        .collection('users')
        .doc(currentProfile.uid);

    await userReference.update({
      'name': cleanName,
      'phone': cleanPhone,
      'whatsappNumber': currentProfile.isSeller
          ? cleanWhatsapp
          : currentProfile.whatsappNumber,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    if (!currentProfile.isSeller) {
      return;
    }

    final products = await _firestore
        .collection('products')
        .where('sellerId', isEqualTo: currentProfile.uid)
        .get();

    if (products.docs.isEmpty) {
      return;
    }

    const batchLimit = 400;

    for (var start = 0; start < products.docs.length; start += batchLimit) {
      final end = (start + batchLimit) < products.docs.length
          ? start + batchLimit
          : products.docs.length;

      final batch = _firestore.batch();

      for (final document in products.docs.sublist(start, end)) {
        batch.update(document.reference, {
          'sellerName': cleanName,
          'sellerWhatsapp': cleanWhatsapp,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();
    }
  }

  Future<void> logout() async {
    await _auth.signOut();
  }
}
