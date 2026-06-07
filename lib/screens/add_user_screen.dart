import 'package:flutter/material.dart';
import '../database/db_helper.dart';
import '../app_strings.dart';
import '../models/app_user.dart';

class AddUserScreen extends StatefulWidget {
  const AddUserScreen({
    super.key,
    required this.strings,
    this.user,
  });

  final AppStrings strings;
  final AppUser? user;

  @override
  State<AddUserScreen> createState() => _AddUserScreenState();
}

class _AddUserScreenState extends State<AddUserScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  
  bool _canManageAssets = true;
  bool _canReportFailure = true;
  bool _canManageUsers = false;
  
  final DBHelper _dbHelper = DBHelper.instance;

  @override
  void initState() {
    super.initState();
    if (widget.user != null) {
      _usernameController.text = widget.user!.username;
      _passwordController.text = widget.user!.password;
      _canManageAssets = widget.user!.canManageAssets;
      _canReportFailure = widget.user!.canReportFailure;
      _canManageUsers = widget.user!.canManageUsers;
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _saveUser() async {
    if (!_formKey.currentState!.validate()) return;

    final userData = AppUser(
      id: widget.user?.id,
      username: _usernameController.text.trim(),
      password: _passwordController.text.trim(),
      isAdmin: widget.user?.isAdmin ?? false,
      canManageUsers: _canManageUsers,
      canManageAssets: _canManageAssets,
      canReportFailure: _canReportFailure,
    );

    try {
      if (widget.user == null) {
        final existing = await _dbHelper.getUserByUsername(userData.username);
        if (existing != null) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(widget.strings.t('userExists'))),
            );
          }
          return;
        }
        await _dbHelper.insertUser(userData);
      } else {
        await _dbHelper.updateUser(userData);
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(widget.strings.t('saveSuccess'))),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Błąd zapisu: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.strings;

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Text(widget.user == null ? s.t('addUser') : 'Edytuj użytkownika', style: const TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildField(s.t('username'), _usernameController, Icons.person_outline),
                _buildField(s.t('password'), _passwordController, Icons.lock_outline, isPassword: true),
                
                const SizedBox(height: 16),
                Text('Uprawnienia', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey.shade700)),
                const SizedBox(height: 8),
                
                _buildPermissionTile(s.t('permManageAssets'), _canManageAssets, (v) => setState(() => _canManageAssets = v)),
                _buildPermissionTile(s.t('permReportFailure'), _canReportFailure, (v) => setState(() => _canReportFailure = v)),
                _buildPermissionTile(s.t('permManageUsers'), _canManageUsers, (v) => setState(() => _canManageUsers = v)),

                const SizedBox(height: 32),
                ElevatedButton.icon(
                  onPressed: _saveUser,
                  icon: const Icon(Icons.save),
                  label: Text(s.t('save'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade700,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 2,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildField(String label, TextEditingController controller, IconData icon, {bool isPassword = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        obscureText: isPassword,
        style: const TextStyle(fontSize: 14),
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, size: 20),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          filled: true,
          fillColor: Colors.grey.shade50,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
        validator: (value) => value == null || value.trim().isEmpty ? 'To pole jest wymagane' : null,
      ),
    );
  }

  Widget _buildPermissionTile(String label, bool value, Function(bool) onChanged) {
    return CheckboxListTile(
      title: Text(label, style: const TextStyle(fontSize: 14)),
      value: value,
      onChanged: (v) => onChanged(v ?? false),
      contentPadding: EdgeInsets.zero,
      controlAffinity: ListTileControlAffinity.leading,
      activeColor: Colors.blue.shade700,
    );
  }
}
