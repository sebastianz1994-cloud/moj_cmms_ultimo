import 'package:flutter/material.dart';
import '../database/db_helper.dart';
import '../app_strings.dart';
import '../models/asset.dart';

class AddAssetScreen extends StatefulWidget {
  const AddAssetScreen({
    super.key,
    required this.strings,
    this.asset,
  });

  final AppStrings strings;
  final Asset? asset;

  @override
  State<AddAssetScreen> createState() => _AddAssetScreenState();
}

class _AddAssetScreenState extends State<AddAssetScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nazwaController = TextEditingController();
  final _kodController = TextEditingController();
  final _lokalizacjaController = TextEditingController();
  final _opisController = TextEditingController();
  final _docController = TextEditingController();
  
  final DBHelper _dbHelper = DBHelper.instance;

  @override
  void initState() {
    super.initState();
    if (widget.asset != null) {
      _nazwaController.text = widget.asset!.nazwa;
      _kodController.text = widget.asset!.kod;
      _lokalizacjaController.text = widget.asset!.lokalizacja;
      _opisController.text = widget.asset!.opis;
      _docController.text = widget.asset!.dokumentacja ?? '';
    }
  }

  @override
  void dispose() {
    _nazwaController.dispose();
    _kodController.dispose();
    _lokalizacjaController.dispose();
    _opisController.dispose();
    _docController.dispose();
    super.dispose();
  }

  Future<void> _saveAsset() async {
    if (!_formKey.currentState!.validate()) return;

    final assetData = Asset(
      id: widget.asset?.id,
      nazwa: _nazwaController.text.trim(),
      kod: _kodController.text.trim(),
      lokalizacja: _lokalizacjaController.text.trim(),
      opis: _opisController.text.trim(),
      dokumentacja: _docController.text.trim(),
    );

    try {
      if (widget.asset == null) {
        await _dbHelper.insertAsset(assetData);
      } else {
        await _dbHelper.updateAsset(assetData);
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
          SnackBar(content: Text('${widget.strings.t('errorSaving')} $e')),
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
        title: Text(widget.asset == null ? s.t('addMachine') : s.t('editMachine'), style: const TextStyle(fontWeight: FontWeight.bold)),
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
                _buildField(s.t('name'), _nazwaController, Icons.precision_manufacturing_outlined, s),
                _buildField(s.t('code'), _kodController, Icons.qr_code_outlined, s),
                _buildField(s.t('location'), _lokalizacjaController, Icons.location_on_outlined, s),
                _buildField(s.t('description'), _opisController, Icons.description_outlined, s, maxLines: 3),
                _buildField(s.t('documentation'), _docController, Icons.link_outlined, s),

                const SizedBox(height: 32),
                ElevatedButton.icon(
                  onPressed: _saveAsset,
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

  Widget _buildField(String label, TextEditingController controller, IconData icon, AppStrings s, {int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        style: const TextStyle(fontSize: 14),
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, size: 20),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          filled: true,
          fillColor: Colors.grey.shade50,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
        validator: (value) => value == null || value.trim().isEmpty ? s.t('requiredField') : null,
      ),
    );
  }
}
