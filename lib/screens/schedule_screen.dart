import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_calendar/calendar.dart';
import '../database/db_helper.dart';
import '../app_strings.dart';
import 'package:intl/intl.dart';

class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({super.key, required this.strings, this.isEmbedded = false});
  final AppStrings strings;
  final bool isEmbedded;

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  final CalendarController _calendarController = CalendarController();
  final DBHelper _dbHelper = DBHelper.instance;
  List<Map<String, dynamic>> _entries = [];
  bool _isLoading = true;
  CalendarView _currentView = CalendarView.month;

  @override
  void initState() {
    super.initState();
    _loadSchedule();
  }

  Future<void> _loadSchedule() async {
    setState(() => _isLoading = true);
    // Fetch a wider range for the calendar, or just use a LIKE pattern for current year/month
    final monthStr = DateFormat('yyyy').format(_calendarController.displayDate ?? DateTime.now());
    final entries = await _dbHelper.getScheduleEntries(monthStr);
    setState(() {
      _entries = entries;
      _isLoading = false;
    });
  }

  Future<void> _addEntryDialog({DateTime? initialDate, Map<String, dynamic>? existingEntry}) async {
    final s = widget.strings;
    final formKey = GlobalKey<FormState>();
    final usernameController = TextEditingController(text: existingEntry?['username']);
    DateTime selectedDate = initialDate ?? (existingEntry != null ? DateTime.parse(existingEntry['date']) : DateTime.now());
    String selectedShift = existingEntry?['shift'] ?? 'Morning';
    
    final List<Map<String, dynamic>> shifts = [
      {'val': 'Morning', 'label': s.t('shiftMorning'), 'color': Colors.orange},
      {'val': 'Afternoon', 'label': s.t('shiftAfternoon'), 'color': Colors.blue},
      {'val': 'Night', 'label': s.t('shiftNight'), 'color': Colors.indigo},
    ];

    Color selectedColor = shifts.firstWhere((s) => s['val'] == selectedShift)['color'] as Color;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(existingEntry == null ? s.t('addSchedule') : 'Edytuj grafik'),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: usernameController,
                    decoration: InputDecoration(
                      labelText: s.t('username'),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    validator: (v) => v == null || v.isEmpty ? s.t('requiredField') : null,
                  ),
                  const SizedBox(height: 12),
                  InkWell(
                    onTap: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: selectedDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2030),
                      );
                      if (date != null) setDialogState(() => selectedDate = date);
                    },
                    child: InputDecorator(
                      decoration: InputDecoration(
                        labelText: 'Date',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text(DateFormat('yyyy-MM-dd').format(selectedDate)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: selectedShift,
                    items: shifts.map((sh) => DropdownMenuItem(value: sh['val'] as String, child: Text(sh['label'] as String))).toList(),
                    onChanged: (v) {
                      setDialogState(() {
                        selectedShift = v!;
                        selectedColor = shifts.firstWhere((sh) => sh['val'] == v)['color'] as Color;
                      });
                    },
                    decoration: InputDecoration(
                      labelText: 'Shift',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            if (existingEntry != null)
              TextButton(
                onPressed: () async {
                  await _dbHelper.deleteScheduleEntry(existingEntry['id'] as int);
                  if (mounted) {
                    Navigator.pop(context);
                    _loadSchedule();
                  }
                },
                child: Text(s.t('delete'), style: const TextStyle(color: Colors.red)),
              ),
            TextButton(onPressed: () => Navigator.pop(context), child: Text(s.t('cancel'))),
            ElevatedButton(
              onPressed: () async {
                if (formKey.currentState!.validate()) {
                  final data = {
                    'username': usernameController.text.trim(),
                    'date': DateFormat('yyyy-MM-dd').format(selectedDate),
                    'shift': selectedShift,
                    'color_hex': selectedColor.value.toRadixString(16),
                  };
                  
                  if (existingEntry == null) {
                    await _dbHelper.insertScheduleEntry(data);
                  } else {
                    await _dbHelper.updateScheduleEntry(existingEntry['id'] as int, data);
                  }
                  
                  if (mounted) {
                    Navigator.pop(context);
                    _loadSchedule();
                  }
                }
              },
              child: Text(s.t('save')),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.strings;

    Widget body = Column(
      children: [
        // Header with month/year and view switcher
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: Colors.white,
          child: Row(
            children: [
              Text(
                DateFormat('MMMM yyyy').format(_calendarController.displayDate ?? DateTime.now()),
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              _buildViewButton('Tydzień', CalendarView.week),
              _buildViewButton('Miesiąc', CalendarView.month),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.add_circle, color: Colors.blue, size: 32),
                onPressed: () => _addEntryDialog(),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : SfCalendar(
                  view: _currentView,
                  controller: _calendarController,
                  dataSource: ScheduleDataSource(_entries),
                  headerHeight: 0,
                  firstDayOfWeek: 1,
                  onTap: (details) {
                    if (details.targetElement == CalendarElement.calendarCell && details.appointments == null) {
                      _addEntryDialog(initialDate: details.date);
                    } else if (details.appointments != null && details.appointments!.isNotEmpty) {
                      _addEntryDialog(existingEntry: details.appointments!.first as Map<String, dynamic>);
                    }
                  },
                  onViewChanged: (details) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      setState(() {});
                    });
                  },
                  monthViewSettings: const MonthViewSettings(
                    showAgenda: true,
                    appointmentDisplayMode: MonthAppointmentDisplayMode.indicator,
                    agendaStyle: AgendaStyle(
                      appointmentTextStyle: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ),
                  timeSlotViewSettings: const TimeSlotViewSettings(
                    startHour: 0,
                    endHour: 24,
                    timeFormat: 'HH:mm',
                  ),
                ),
        ),
      ],
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
        title: Text(s.t('schedule'), style: const TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadSchedule,
          ),
        ],
      ),
      body: body,
    );
  }

  Widget _buildViewButton(String label, CalendarView view) {
    bool isSelected = _currentView == view;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: ChoiceChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (selected) {
          if (selected) {
            setState(() {
              _currentView = view;
              _calendarController.view = view;
            });
          }
        },
        selectedColor: Colors.blue.shade100,
        labelStyle: TextStyle(
          color: isSelected ? Colors.blue.shade700 : Colors.black87,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
    );
  }
}

class ScheduleDataSource extends CalendarDataSource {
  ScheduleDataSource(List<Map<String, dynamic>> source) {
    appointments = source;
  }

  @override
  DateTime getStartTime(int index) {
    final entry = appointments![index] as Map<String, dynamic>;
    final date = DateTime.parse(entry['date']);
    switch (entry['shift']) {
      case 'Morning':
        return DateTime(date.year, date.month, date.day, 6);
      case 'Afternoon':
        return DateTime(date.year, date.month, date.day, 14);
      case 'Night':
        return DateTime(date.year, date.month, date.day, 22);
      default:
        return date;
    }
  }

  @override
  DateTime getEndTime(int index) {
    final entry = appointments![index] as Map<String, dynamic>;
    final date = DateTime.parse(entry['date']);
    switch (entry['shift']) {
      case 'Morning':
        return DateTime(date.year, date.month, date.day, 14);
      case 'Afternoon':
        return DateTime(date.year, date.month, date.day, 22);
      case 'Night':
        return DateTime(date.year, date.month, date.day, 22).add(const Duration(hours: 8));
      default:
        return date.add(const Duration(hours: 8));
    }
  }

  @override
  String getSubject(int index) {
    final entry = appointments![index] as Map<String, dynamic>;
    return '${entry['username']} (${entry['shift']})';
  }

  @override
  Color getColor(int index) {
    final entry = appointments![index] as Map<String, dynamic>;
    return Color(int.parse(entry['color_hex'], radix: 16));
  }
}
