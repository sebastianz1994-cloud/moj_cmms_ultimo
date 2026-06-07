import 'package:flutter/material.dart';
import '../database/db_helper.dart';
import '../app_strings.dart';
import '../models/app_user.dart';
import 'add_user_screen.dart';

class UsersScreen extends StatefulWidget {
  const UsersScreen({super.key, required this.strings, this.isEmbedded = false});
  final AppStrings strings;
  final bool isEmbedded;

  @override
  State<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen> {
  final DBHelper _dbHelper = DBHelper.instance;
  List<AppUser> _users = [];
  List<AppUser> _filteredUsers = [];
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    setState(() => _isLoading = true);
    final users = await _dbHelper.getUsers();
    setState(() {
      _users = users;
      _applyFilter();
      _isLoading = false;
    });
  }

  void _applyFilter() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredUsers = _users.where((user) {
        return user.username.toLowerCase().contains(query);
      }).toList();
    });
  }

  Future<void> _openAddScreen([AppUser? user]) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddUserScreen(
          strings: widget.strings,
          user: user,
        ),
      ),
    );

    if (result == true) {
      _loadUsers();
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.strings;

    Widget body = SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 15, offset: const Offset(0, 5))],
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header (Add button & Search)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: const BorderRadius.only(topLeft: Radius.circular(16), topRight: Radius.circular(16)),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      ElevatedButton.icon(
                        onPressed: () => _openAddScreen(),
                        icon: const Icon(Icons.person_add_outlined, size: 18),
                        label: Text(s.t('addUser'), style: const TextStyle(fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue.shade700,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 2,
                        ),
                      ),
                      const Spacer(),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Search Bar
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('SZUKAJ UŻYTKOWNIKA', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey.shade600)),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Expanded(
                                  child: Container(
                                    height: 36,
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      border: Border.all(color: Colors.grey.shade300),
                                      borderRadius: const BorderRadius.only(topLeft: Radius.circular(8), bottomLeft: Radius.circular(8)),
                                    ),
                                    child: TextField(
                                      controller: _searchController,
                                      style: const TextStyle(fontSize: 12),
                                      onChanged: (_) => _applyFilter(),
                                      decoration: InputDecoration(
                                        hintText: 'Wyszukaj po nazwie użytkownika...',
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                        border: InputBorder.none,
                                        isDense: true,
                                      ),
                                    ),
                                  ),
                                ),
                                Container(
                                  height: 36,
                                  width: 44,
                                  decoration: BoxDecoration(
                                    color: Colors.blue.shade700,
                                    borderRadius: const BorderRadius.only(topRight: Radius.circular(8), bottomRight: Radius.circular(8)),
                                  ),
                                  child: const Icon(Icons.search, size: 18, color: Colors.white),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  height: 36,
                                  width: 44,
                                  decoration: BoxDecoration(
                                    color: Colors.red.shade400,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: IconButton(
                                    icon: const Icon(Icons.close, size: 18, color: Colors.white),
                                    onPressed: () {
                                      _searchController.clear();
                                      _applyFilter();
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const Divider(height: 1),

            // The Table
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.all(32.0),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_filteredUsers.isEmpty)
              const Padding(
                padding: EdgeInsets.all(32.0),
                child: Center(child: Text('Brak użytkowników w bazie', style: TextStyle(color: Colors.grey))),
              )
            else
              Table(
                border: TableBorder(
                  horizontalInside: BorderSide(color: Colors.grey.shade100),
                  verticalInside: BorderSide(color: Colors.grey.shade100),
                ),
                columnWidths: const {
                  0: FlexColumnWidth(1.5),  // Nazwa użytkownika
                  1: FlexColumnWidth(2.5),  // Uprawnienia
                  2: FixedColumnWidth(100), // Akcje
                },
                children: [
                  // Header Row
                  TableRow(
                    decoration: BoxDecoration(color: Colors.grey.shade50),
                    children: [
                      _buildHeaderCell(s.t('username').toUpperCase()),
                      _buildHeaderCell('UPRAWNIENIA'),
                      _buildHeaderCell('AKCJE', textAlign: TextAlign.center),
                    ],
                  ),
                  // Data Rows
                  ..._filteredUsers.map((user) {
                    return TableRow(
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 14.0),
                          child: Row(
                            children: [
                              Icon(user.isAdmin ? Icons.shield : Icons.person, size: 16, color: user.isAdmin ? Colors.orange : Colors.blue),
                              const SizedBox(width: 8),
                              Text(user.username, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 14.0),
                          child: Text(
                            user.isAdmin
                                ? s.t('admin')
                                : [
                                    if (user.canManageAssets) s.t('permManageAssets'),
                                    if (user.canReportFailure) s.t('permReportFailure'),
                                    if (user.canManageUsers) s.t('permManageUsers'),
                                  ].join(' | '),
                            style: const TextStyle(fontSize: 10, color: Colors.black54),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit_outlined, color: Colors.blue, size: 20),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                onPressed: () => _openAddScreen(user),
                              ),
                              if (!user.isAdmin) ...[
                                const SizedBox(width: 8),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  onPressed: () async {
                                    final confirm = await showDialog<bool>(
                                      context: context,
                                      builder: (context) => AlertDialog(
                                        title: const Text('Usuń użytkownika'),
                                        content: Text('Czy na pewno chcesz usunąć użytkownika ${user.username}?'),
                                        actions: [
                                          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Anuluj')),
                                          TextButton(
                                            onPressed: () => Navigator.pop(context, true),
                                            child: const Text('Usuń', style: TextStyle(color: Colors.red)),
                                          ),
                                        ],
                                      ),
                                    );
                                    if (confirm == true) {
                                      await _dbHelper.deleteUser(user.id!);
                                      _loadUsers();
                                    }
                                  },
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ],
              ),
          ],
        ),
      ),
    );

    if (widget.isEmbedded) {
      return body;
    }

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(s.t('usersTile'), style: const TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
      body: body,
    );
  }

  Widget _buildHeaderCell(String text, {TextAlign textAlign = TextAlign.start}) {
    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: Text(
        text,
        textAlign: textAlign,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 10, color: Colors.black87),
      ),
    );
  }
}
