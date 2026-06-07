import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_calendar/calendar.dart';
import 'package:intl/intl.dart';
import '../app_strings.dart';
import '../database/db_helper.dart';
import '../models/task.dart';
import 'add_task_screen.dart';

class PlanningScreen extends StatefulWidget {
  const PlanningScreen({super.key, required this.currentUsername, this.isEmbedded = false});

  final String currentUsername;
  final bool isEmbedded;

  @override
  State<PlanningScreen> createState() => _PlanningScreenState();
}

class _PlanningScreenState extends State<PlanningScreen> {
  final CalendarController _calendarController = CalendarController();
  final DBHelper _dbHelper = DBHelper.instance;
  List<Task> _tasks = [];
  bool _isLoading = true;
  CalendarView _currentView = CalendarView.week;

  @override
  void initState() {
    super.initState();
    _loadTasks();
  }

  Future<void> _loadTasks() async {
    setState(() => _isLoading = true);
    final taskMaps = await _dbHelper.getTasks();
    setState(() {
      _tasks = taskMaps.map(Task.fromMap).toList();
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);

    Widget body = Column(
      children: [
        // Header with view switcher - styled like the image
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
              _buildViewButton('Dzień', CalendarView.day),
              _buildViewButton('Tydzień', CalendarView.week),
              _buildViewButton('Miesiąc', CalendarView.month),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.add_circle, color: Colors.blue, size: 32),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute<bool>(
                      builder: (_) => AddTaskScreen(currentUsername: widget.currentUsername),
                    ),
                  ).then((value) {
                    if (value == true) _loadTasks();
                  });
                },
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
                  dataSource: TaskDataSource(_tasks),
                  headerHeight: 0, // Hidden because we have custom header
                  onTap: (CalendarTapDetails details) {
                    if (details.appointments != null && details.appointments!.isNotEmpty) {
                      final task = details.appointments!.first as Task;
                      Navigator.push(
                        context,
                        MaterialPageRoute<bool>(
                          builder: (_) => AddTaskScreen(currentUsername: widget.currentUsername, task: task),
                        ),
                      ).then((value) {
                        if (value == true) _loadTasks();
                      });
                    }
                  },
                  onViewChanged: (viewChangedDetails) {
                    // Update header month/year when view changes
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      setState(() {});
                    });
                  },
                  firstDayOfWeek: 1, // Monday
                  timeSlotViewSettings: const TimeSlotViewSettings(
                    startHour: 6,
                    endHour: 22,
                    timeFormat: 'HH:mm',
                  ),
                  monthViewSettings: const MonthViewSettings(
                    showAgenda: true,
                    appointmentDisplayMode: MonthAppointmentDisplayMode.indicator,
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
        title: Text(s.t('planning'), style: const TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadTasks,
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

class TaskDataSource extends CalendarDataSource {
  TaskDataSource(List<Task> source) {
    appointments = source;
  }

  @override
  DateTime getStartTime(int index) {
    final task = appointments![index] as Task;
    return task.dateStart != null ? DateTime.parse(task.dateStart!) : DateTime.now();
  }

  @override
  DateTime getEndTime(int index) {
    final task = appointments![index] as Task;
    // If dateEnd is null, default to 1 hour after start
    if (task.dateEnd != null) return DateTime.parse(task.dateEnd!);
    final start = task.dateStart != null ? DateTime.parse(task.dateStart!) : DateTime.now();
    return start.add(const Duration(hours: 1));
  }

  @override
  String getSubject(int index) {
    final task = appointments![index] as Task;
    return task.title;
  }

  @override
  Color getColor(int index) {
    final task = appointments![index] as Task;
    switch (task.status) {
      case 'Zaplanowane':
        return Colors.purple.shade300;
      case 'Zrealizowane':
        return Colors.green.shade300;
      case 'Anulowane':
        return Colors.grey.shade300;
      default:
        return Colors.blue.shade300;
    }
  }
}
