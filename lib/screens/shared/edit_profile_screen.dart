import 'package:flutter/material.dart';

import '../../core/theme/golden_dark.dart';

import '../../models/app_user.dart';
import '../../services/auth_service.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key, required this.user});

  final AppUser user;

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameController;

  late final TextEditingController _phoneController;

  late final TextEditingController _whatsappController;

  bool _saving = false;

  bool get _seller => widget.user.isSeller;

  Color get _primary =>
      _seller ? const Color(0xFF5A1E2B) : const Color(0xFF0B2638);

  Color get _accent =>
      _seller ? const Color(0xFFF4B64A) : const Color(0xFF17A99A);

  Color get _background => GoldenDark.page(
    context,
    light: _seller ? const Color(0xFFFFF8EE) : const Color(0xFFF2F9FA),
  );

  Color get _ink =>
      _seller ? GoldenDark.sellerInk(context) : GoldenDark.clientInk(context);

  @override
  void initState() {
    super.initState();

    _nameController = TextEditingController(text: widget.user.name);

    _phoneController = TextEditingController(text: widget.user.phone);

    _whatsappController = TextEditingController(
      text: widget.user.whatsappNumber ?? '',
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _whatsappController.dispose();
    super.dispose();
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _save() async {
    if (_saving || !_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _saving = true;
    });

    try {
      await AuthService().updateProfile(
        currentProfile: widget.user,
        name: _nameController.text,
        phone: _phoneController.text,
        whatsappNumber: _seller
            ? _whatsappController.text
            : widget.user.whatsappNumber,
      );

      if (!mounted) {
        return;
      }

      Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _saving = false;
      });

      _showMessage(error.toString().replaceFirst('Exception: ', ''));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        backgroundColor: _background,
        foregroundColor: _ink,
        title: const Text(
          'Edit profile',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(22, 18, 22, 60),
          child: Center(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(28),
                      decoration: BoxDecoration(
                        color: _primary,
                        borderRadius: BorderRadius.circular(28),
                      ),
                      child: Column(
                        children: [
                          Container(
                            width: 84,
                            height: 84,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: _accent,
                              shape: BoxShape.circle,
                            ),
                            child: Text(
                              _nameController.text.trim().isEmpty
                                  ? '?'
                                  : _nameController.text
                                        .trim()[0]
                                        .toUpperCase(),
                              style: TextStyle(
                                color: _seller ? _primary : Colors.white,
                                fontSize: 30,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _seller ? 'Seller profile' : 'Client profile',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 7),
                          const Text(
                            'Your account role and email stay protected.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white60,
                              height: 1.45,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 22),
                    TextFormField(
                      controller: _nameController,
                      onChanged: (_) {
                        setState(() {});
                      },
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Full name',
                        prefixIcon: Icon(Icons.person_outline_rounded),
                      ),
                      validator: (value) {
                        if ((value ?? '').trim().length < 2) {
                          return 'Enter a valid full name.';
                        }

                        return null;
                      },
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      initialValue: widget.user.email,
                      readOnly: true,
                      decoration: const InputDecoration(
                        labelText: 'Email address',
                        prefixIcon: Icon(Icons.email_outlined),
                        suffixIcon: Icon(Icons.lock_outline_rounded),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Phone number',
                        prefixIcon: Icon(Icons.phone_outlined),
                      ),
                      validator: (value) {
                        if ((value ?? '').trim().length < 5) {
                          return 'Enter a valid phone number.';
                        }

                        return null;
                      },
                    ),
                    if (_seller) ...[
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _whatsappController,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(
                          labelText: 'Business WhatsApp',
                          prefixIcon: Icon(Icons.chat_bubble_outline_rounded),
                        ),
                        validator: (value) {
                          if ((value ?? '').trim().length < 5) {
                            return 'Enter a valid WhatsApp number.';
                          }

                          return null;
                        },
                      ),
                    ],
                    const SizedBox(height: 14),
                    TextFormField(
                      initialValue: _seller ? 'Seller' : 'Client',
                      readOnly: true,
                      decoration: const InputDecoration(
                        labelText: 'Account role',
                        prefixIcon: Icon(Icons.verified_user_outlined),
                        suffixIcon: Icon(Icons.lock_outline_rounded),
                      ),
                    ),
                    const SizedBox(height: 24),
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: _primary,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(0, 56),
                      ),
                      onPressed: _saving ? null : _save,
                      icon: _saving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.save_outlined),
                      label: Text(_saving ? 'Saving...' : 'Save changes'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
