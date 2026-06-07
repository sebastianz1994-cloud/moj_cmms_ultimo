import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../utils/file_service.dart';
import '../app_strings.dart';

class ListaProdukcyjnaPage extends StatefulWidget {
  const ListaProdukcyjnaPage({super.key});

  @override
  State<ListaProdukcyjnaPage> createState() => _ListaProdukcyjnaPageState();
}

class _ListaProdukcyjnaPageState extends State<ListaProdukcyjnaPage>
    with AutomaticKeepAliveClientMixin {
  
  // Lista wpisów (np. stempli czasowych)
  List<Map<String, dynamic>> _productionEntries = [];
  bool _isLoading = true;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  /// Wczytuje dane z pliku przy inicjalizacji strony.
  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);
    final loadedData = await FileService.loadProductionList();
    if (mounted) {
      setState(() {
        _productionEntries = loadedData;
        _isLoading = false;
      });
    }
  }

  /// Dodaje nowy wpis z aktualnym czasem i automatycznie zapisuje do pliku.
  Future<void> _addEntry(AppStrings s) async {
    final now = DateTime.now();
    final timestamp = DateFormat('yyyy-MM-dd HH:mm:ss').format(now);
    
    final newEntry = {
      'id': now.millisecondsSinceEpoch.toString(),
      'timestamp': timestamp,
      'description': s.t('newProductionEntry'),
    };

    setState(() {
      _productionEntries.add(newEntry);
    });

    // Automatyczny zapis na dysk po każdym dodaniu
    await FileService.saveProductionList(_productionEntries);
  }

  /// Finalizuje proces: przesyła dane do API, usuwa plik i czyści listę.
  Future<void> _finalizeAndReset(AppStrings s) async {
    if (_productionEntries.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(s.t('noDataToSave'))),
      );
      return;
    }

    try {
      // Symulacja wysyłania danych do API
      debugPrint('Wysyłanie danych do API: ${jsonEncode(_productionEntries)}');
      
      // Tutaj miejsce na właściwy kod API:
      // await ApiService.postProductionData(_productionEntries);

      // Po udanym przesłaniu - fizyczne usunięcie pliku z dysku
      await FileService.deleteProductionFile();

      // Czyszczenie listy w aplikacji
      setState(() {
        _productionEntries.clear();
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(s.t('dataSentReset'))),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${s.t('errorFinalizing')} $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Wymagane przez AutomaticKeepAliveClientMixin
    final s = AppStrings.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(s.t('productionList')),
        actions: [
          TextButton.icon(
            onPressed: () => _finalizeAndReset(s),
            icon: const Icon(Icons.cloud_upload, color: Colors.white),
            label: Text(s.t('save'), style: const TextStyle(color: Colors.white)),
            style: TextButton.styleFrom(
              backgroundColor: Colors.green.shade700,
              padding: const EdgeInsets.symmetric(horizontal: 16),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _productionEntries.isEmpty
              ? Center(
                  child: Text(
                    s.t('listEmptyAddWithPlus'),
                    style: const TextStyle(color: Colors.grey),
                  ),
                )
              : ListView.builder(
                  itemCount: _productionEntries.length,
                  itemBuilder: (context, index) {
                    final entry = _productionEntries[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      elevation: 2,
                      child: ListTile(
                        leading: const Icon(Icons.access_time, color: Colors.blue),
                        title: Text('${s.t('entry')}: ${entry['timestamp']}'),
                        subtitle: Text(entry['description'] ?? ''),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.red),
                          onPressed: () async {
                            setState(() {
                              _productionEntries.removeAt(index);
                            });
                            await FileService.saveProductionList(_productionEntries);
                          },
                        ),
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _addEntry(s),
        backgroundColor: Colors.blue.shade700,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildHeaderCell(String text) {
    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: Text(
        text,
        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey),
      ),
    );
  }
}
