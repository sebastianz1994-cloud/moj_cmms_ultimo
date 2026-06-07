import 'package:flutter/material.dart';
import '../app_strings.dart';
import 'current_failures_screen.dart';
import 'report_failure_screen.dart';
import 'history_screen.dart';

class FailuresScreen extends StatefulWidget {
  const FailuresScreen({
    super.key,
    required this.strings,
    required this.currentUsername,
    this.isEmbedded = false,
  });

  final AppStrings strings;
  final String currentUsername;
  final bool isEmbedded;

  @override
  State<FailuresScreen> createState() => _FailuresScreenState();
}

class _FailuresScreenState extends State<FailuresScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);

    Widget body = TabBarView(
      controller: _tabController,
      children: [
        // Tab 1: Current Failures
        SingleChildScrollView(
          padding: const EdgeInsets.all(12),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 15, offset: const Offset(0, 5))],
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: CurrentFailuresScreen(
              strings: s,
              currentUsername: widget.currentUsername,
            ),
          ),
        ),
        // Tab 2: History
        SingleChildScrollView(
          padding: const EdgeInsets.all(12),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 15, offset: const Offset(0, 5))],
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: HistoryScreen(strings: s),
          ),
        ),
      ],
    );

    if (widget.isEmbedded) {
      return Column(
        children: [
          TabBar(
            controller: _tabController,
            labelColor: Colors.blue.shade700,
            unselectedLabelColor: Colors.grey,
            indicatorColor: Colors.blue.shade700,
            indicatorWeight: 3,
            labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            tabs: [
              Tab(text: s.t('currentFailuresTab')),
              Tab(text: s.t('historyFailuresTab')),
            ],
          ),
          Expanded(child: body),
        ],
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(s.t('failures'), style: const TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.blue.shade700,
          unselectedLabelColor: Colors.grey,
          indicatorColor: Colors.blue.shade700,
          indicatorWeight: 3,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          tabs: [
            Tab(text: s.t('currentFailuresTab')),
            Tab(text: s.t('historyFailuresTab')),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf_outlined),
            tooltip: s.t('downloadReport'),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Report generation starting... (PDF)')),
              );
            },
          ),
        ],
      ),
      body: body,
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.blue.shade700,
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute<void>(
              builder: (_) => ReportFailureScreen(
                strings: s,
                currentUsername: widget.currentUsername,
              ),
            ),
          ).then((_) {
            setState(() {}); 
          });
        },
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}
