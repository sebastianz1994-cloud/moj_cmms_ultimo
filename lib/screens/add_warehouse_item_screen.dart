import 'package:flutter/material.dart';
import '../database/db_helper.dart';
import '../app_strings.dart';

class AddWarehouseItemScreen extends StatefulWidget {
  const AddWarehouseItemScreen({
    super.key,
    required this.strings,
    this.item,
  });

  final AppStrings strings;
  final Map<String, dynamic>? item;

  @override
  State<AddWarehouseItemScreen> createState() => _AddWarehouseItemScreenState();
}

class _AddWarehouseItemScreenState extends State<AddWarehouseItemScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _codeController = TextEditingController();
  final _quantityController = TextEditingController(text: '0');
  final _minQtyController = TextEditingController(text: '1');
  final _categoryController = TextEditingController();
  final _locationController = TextEditingController();
  
  final DBHelper _dbHelper = DBHelper.instance;

  @override
  void initState() {
    super.initState();
    if (widget.item != null) {
      _nameController.text = widget.item!['name']?.toString() ?? '';
      _codeController.text = widget.item!['code']?.toString() ?? '';
      _quantityController.text = widget.item!['quantity']?.toString() ?? '0';
      _minQtyController.text = widget.item!['min_quantity']?.toString() ?? '1';
      _categoryController.text = widget.item!['category']?.toString() ?? '';
      _locationController.text = widget.item!['location']?.toString() ?? '';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _codeController.dispose();
    _quantityController.dispose();
    _minQtyController.dispose();
    _categoryController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _saveItem() async {
    if (!_formKey.currentState!.validate()) return;

    final data = {
      'name': _nameController.text.trim(),
      'code': _codeController.text.trim(),
      'quantity': int.tryParse(_quantityController.text) ?? 0,
      'min_quantity': int.tryParse(_minQtyController.text) ?? 1,
      'category': _categoryController.text.trim(),
      'location': _locationController.text.trim(),
    };

    try {
      if (widget.item == null) {
        await _dbHelper.insertWarehouseItem(data);
      } else {
        await _dbHelper.updateWarehouseItem(widget.item!['id'], data);
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
        title: Text(widget.item == null ? s.t('addPart') : 'Edytuj część', style: const TextStyle(fontWeight: FontWeight.bold)),
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
                _buildField(s.t('name'), _nameController, Icons.inventory_2_outlined),
                _buildField(s.t('code'), _codeController, Icons.qr_code_outlined),
                _buildField(s.t('category'), _categoryController, Icons.category_outlined),
                _buildField(s.t('location'), _locationController, Icons.location_on_outlined),
                
                Row(
                  children: [
                    Expanded(child: _buildField(s.t('quantity'), _quantityController, Icons.numbers, isNumber: true)),
                    const SizedBox(width: 16),
                    Expanded(child: _buildField(s.t('minQuantity'), _minQtyController, Icons.warning_amber_outlined, isNumber: true)),
                  ],
                ),

                const SizedBox(height: 32),
                ElevatedButton.icon(
                  onPressed: _saveItem,
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

  Widget _buildField(String label, TextEditingController controller, IconData icon, {int maxLines = 1, bool isNumber = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: isNumber ? TextInputType.number : TextInputType.text,
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
}
