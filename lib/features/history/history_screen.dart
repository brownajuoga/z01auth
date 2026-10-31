import 'package:flutter/material.dart';
import '../../core/theme/z01_theme.dart';
import '../../models/presence_state.dart';
import '../../services/api_client.dart';
import 'widgets/attendance_detail_sheet.dart';

/// Frame 4: History (monthly summary + daily attendance log)
/// Dynamically loaded and synchronized via ApiClient
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final ApiClient _apiClient = ApiClient.instance;

  static const _monthNames = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  late String _selectedMonth;
  late int _selectedMonthIndex;
  late int _selectedYear;

  AttendanceSummaryStats _summary = const AttendanceSummaryStats(
    daysPresent: 0,
    avgHours: 0.0,
    verificationRatePercent: 100,
  );

  List<AttendanceRecord> _records = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedMonthIndex = now.month;
    _selectedYear = now.year;
    _selectedMonth = '${_monthNames[now.month - 1]} ${now.year}';
    _fetchHistory();
  }

  Future<void> _fetchHistory() async {
    setState(() => _isLoading = true);

    final monthKey = '$_selectedYear-${_selectedMonthIndex.toString().padLeft(2, '0')}';
    try {
      final data = await _apiClient.getAttendanceHistory(monthKey);
      if (!mounted) return;

      final summaryMap = data['summary'] as Map<String, dynamic>? ?? {};
      final daysList = data['days'] as List<dynamic>? ?? [];

      setState(() {
        _summary = AttendanceSummaryStats.fromJson(summaryMap);
        _records = daysList
            .map((item) => AttendanceRecord.fromJson(item as Map<String, dynamic>))
            .toList();
        _isLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _switchMonth() {
    setState(() {
      if (_selectedMonthIndex == 1) {
        _selectedMonthIndex = 12;
        _selectedYear -= 1;
      } else {
        _selectedMonthIndex -= 1;
      }
      _selectedMonth = '${_monthNames[_selectedMonthIndex - 1]} $_selectedYear';
    });
    _fetchHistory();
  }

  @override
  Widget build(BuildContext context) {
    final p = Z01Palette.of(context);

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ---------- Header + month picker ----------
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'History',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: p.text,
                    ),
                  ),
                  GestureDetector(
                    onTap: _switchMonth,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                      decoration: BoxDecoration(
                        color: p.cardElevated,
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: Row(
                        children: [
                          Text(
                            _selectedMonth,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: p.text,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(Icons.keyboard_arrow_down_rounded,
                              size: 18, color: p.muted),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // ---------- Summary ----------
              Container(
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
                decoration: BoxDecoration(
                  color: p.card,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: p.border),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _statColumn(p, 'DAYS PRESENT', '${_summary.daysPresent}d'),
                    ),
                    Container(width: 1, height: 32, color: p.border),
                    Expanded(
                      child: _statColumn(p, 'AVG HOURS', '${_summary.avgHours.toStringAsFixed(1)}h'),
                    ),
                    Container(width: 1, height: 32, color: p.border),
                    Expanded(
                      child: _statColumn(
                          p, 'VERIFIED', '${_summary.verificationRatePercent}%'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              Text(
                'DAILY LOG',
                style: TextStyle(fontSize: 11, letterSpacing: 0.9, color: p.muted),
              ),
              const SizedBox(height: 10),

              // ---------- Daily cards ----------
              Expanded(
                child: _isLoading
                    ? Center(
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: p.brand,
                        ),
                      )
                    : _records.isEmpty
                        ? Center(
                            child: Text(
                              'No attendance logs recorded for $_selectedMonth',
                              style: TextStyle(fontSize: 13, color: p.muted),
                            ),
                          )
                        : ListView.separated(
                            physics: const BouncingScrollPhysics(),
                            itemCount: _records.length,
                            separatorBuilder: (_, _) => const SizedBox(height: 12),
                            itemBuilder: (context, index) =>
                                _recordCard(p, _records[index]),
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _recordCard(Z01Palette p, AttendanceRecord item) {
    return Material(
      color: p.card,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => AttendanceDetailSheet.show(context, item),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: item.isActive ? p.brand : p.border,
              width: item.isActive ? 1.4 : 1.0,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Text(
                      item.dateTitle,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: p.text,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: item.isActive ? p.brand : p.cardElevated,
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Text(
                      item.isActive ? 'Active' : item.duration,
                      style: Z01Theme.monoStyle(
                        context: context,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: item.isActive ? p.onBrand : p.text,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _timeBlock(p, 'IN', item.timeIn),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Icon(Icons.arrow_forward_rounded,
                        size: 16, color: p.muted),
                  ),
                  _timeBlock(p, item.isActive ? 'LAST SEEN' : 'OUT', item.timeOut),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _timeBlock(Z01Palette p, String label, String time) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 10, letterSpacing: 0.8, color: p.muted),
        ),
        const SizedBox(height: 3),
        Text(
          time,
          style: Z01Theme.monoStyle(context: context, fontSize: 14),
        ),
      ],
    );
  }

  Widget _statColumn(Z01Palette p, String title, String value) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          style: TextStyle(fontSize: 10, letterSpacing: 0.8, color: p.muted),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: Z01Theme.monoStyle(context: context, fontSize: 20),
        ),
      ],
    );
  }
}