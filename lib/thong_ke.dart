import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:fl_chart/fl_chart.dart';
import 'database/database_helper.dart';
import 'models/sold_item_model.dart';
import 'models/expense_model.dart';

class StatisticsPage extends StatefulWidget {
  const StatisticsPage({super.key});

  @override
  State<StatisticsPage> createState() => _StatisticsPageState();
}

class _StatisticsPageState extends State<StatisticsPage> {
  final DatabaseHelper _db = DatabaseHelper();

  // Color palette for pie charts
  static const List<Color> _pieChartColors = [
    Colors.red,
    Colors.orange,
    Colors.purple,
    Colors.pink,
    Colors.deepOrange,
    Colors.amber,
    Colors.teal,
    Colors.indigo,
  ];

  // Date range
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now();
  String _selectedPeriod = 'Hôm nay';

  // Week selector for sales chart (0 = current week, -1 = last week, etc.)
  int _weekOffset = 0;

  // Statistics data
  int _totalRevenue = 0;
  int _totalExpenses = 0;
  int _netProfit = 0;
  int _itemsSold = 0;

  List<SoldItem> _soldItems = [];
  List<Expense> _expenses = [];

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initializeLocale();
    _loadStatistics();
  }

  Future<void> _initializeLocale() async {
    await initializeDateFormatting('vi', null);
  }

  Future<void> _loadStatistics() async {
    setState(() => _isLoading = true);

    try {
      // Load data based on date range
      final soldItems = await _db.getSoldItemsByDateRange(_startDate, _endDate);
      final expenses = await _db.getExpensesByDateRange(_startDate, _endDate);

      // Calculate totals
      int totalRevenue = 0;
      int totalItemsSold = 0;

      for (var item in soldItems) {
        totalRevenue += item.priceAfterDiscount;
        totalItemsSold += item.quantity;
      }

      int totalExpenses = expenses.fold(
        0,
        (sum, expense) => sum + expense.amount,
      );

      setState(() {
        _soldItems = soldItems;
        _expenses = expenses;
        _totalRevenue = totalRevenue;
        _totalExpenses = totalExpenses;
        _netProfit = totalRevenue - totalExpenses;
        _itemsSold = totalItemsSold;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Lỗi tải dữ liệu: $e')));
      }
    }
  }

  void _changePeriod(String period) {
    final now = DateTime.now();
    setState(() {
      _selectedPeriod = period;

      switch (period) {
        case 'Hôm nay':
          _startDate = DateTime(now.year, now.month, now.day);
          _endDate = now;
          break;
        case 'Tuần này':
          final weekday = now.weekday;
          _startDate = now.subtract(Duration(days: weekday - 1));
          _startDate = DateTime(
            _startDate.year,
            _startDate.month,
            _startDate.day,
          );
          _endDate = now;
          break;
        case 'Tháng này':
          _startDate = DateTime(now.year, now.month, 1);
          _endDate = now;
          break;
        case 'Tháng trước':
          final lastMonth = DateTime(now.year, now.month - 1, 1);
          _startDate = lastMonth;
          _endDate = DateTime(now.year, now.month, 0, 23, 59, 59);
          break;
      }
    });

    _loadStatistics();
  }

  Future<void> _selectCustomDateRange() async {
    try {
      final DateTimeRange? picked = await showDateRangePicker(
        context: context,
        firstDate: DateTime(2020),
        lastDate: DateTime.now(),
        initialDateRange: DateTimeRange(start: _startDate, end: _endDate),
      );

      if (picked != null) {
        setState(() {
          _selectedPeriod = 'Tùy chỉnh';
          _startDate = picked.start;
          _endDate = picked.end;
        });
        _loadStatistics();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi chọn ngày: $e')),
        );
      }
    }
  }

  String _formatCurrency(int amount) {
    final formatter = NumberFormat.currency(locale: 'vi_VN', symbol: '₫');
    return formatter.format(amount);
  }

  String _formatDate(DateTime date) {
    return DateFormat('dd/MM/yyyy').format(date);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadStatistics,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildPeriodSelector(),
                    const SizedBox(height: 16),
                    _buildDateRangeDisplay(),
                    const SizedBox(height: 20),
                    _buildSummaryCards(),
                    const SizedBox(height: 24),
                    _buildTrendLineChart(),
                    const SizedBox(height: 24),
                    _buildDailySalesChart(),
                    const SizedBox(height: 24),
                    _buildTopProductsList(),
                    const SizedBox(height: 24),
                    _buildExpensesPieChart(),
                    const SizedBox(height: 24),
                    _buildExpensesCategoryBreakdown(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildPeriodSelector() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _buildPeriodChip('Hôm nay'),
          _buildPeriodChip('Tuần này'),
          _buildPeriodChip('Tháng này'),
          _buildPeriodChip('Tháng trước'),
          _buildCustomDateChip(),
        ],
      ),
    );
  }

  Widget _buildPeriodChip(String label) {
    final isSelected = _selectedPeriod == label;
    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: ChoiceChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (selected) {
          if (selected) _changePeriod(label);
        },
        selectedColor: Colors.blue,
        labelStyle: TextStyle(
          color: isSelected ? Colors.white : (Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black),
        ),
      ),
    );
  }

  Widget _buildCustomDateChip() {
    final isSelected = _selectedPeriod == 'Tùy chỉnh';
    return ChoiceChip(
      label: const Text('Tùy chỉnh'),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) _selectCustomDateRange();
      },
      selectedColor: Colors.blue,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : (Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black),
      ),
    );
  }

  Widget _buildDateRangeDisplay() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.calendar_today, size: 16, color: Colors.blue),
          const SizedBox(width: 8),
          Text(
            '${_formatDate(_startDate)} - ${_formatDate(_endDate)}',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.blue,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCards() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildSummaryCard(
                'Doanh thu',
                _formatCurrency(_totalRevenue),
                Icons.trending_up,
                Colors.green,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildSummaryCard(
                'Chi phí',
                _formatCurrency(_totalExpenses),
                Icons.trending_down,
                Colors.red,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildSummaryCard(
                'Lợi nhuận',
                _formatCurrency(_netProfit),
                Icons.account_balance_wallet,
                _netProfit >= 0 ? Colors.blue : Colors.red,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildSummaryCard(
                'Đã bán',
                '$_itemsSold sản phẩm',
                Icons.shopping_cart,
                Colors.orange,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSummaryCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Card(
      elevation: 10,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDailySalesChart() {
    // Always use last 7 days for this section, regardless of period selector
    final now = DateTime.now();

    // Get the start of the week (Monday) with offset
    // weekday: Monday=1, Sunday=7
    final DateTime baseDate = now.subtract(Duration(days: _weekOffset * 7));
    final DateTime startOfWeek = baseDate.subtract(
      Duration(days: baseDate.weekday - 1),
    );

    // Generate 7 days starting from Monday
    final List<DateTime> last7Days = List.generate(7, (index) {
      return startOfWeek.add(Duration(days: index));
    });

    final sevenDaysAgo = startOfWeek;
    final endOfWeek = startOfWeek.add(
      const Duration(days: 6, hours: 23, minutes: 59, seconds: 59),
    );

    // Load sold items for the week directly from database
    return FutureBuilder<List<SoldItem>>(
      future: _db.getSoldItemsByDateRange(sevenDaysAgo, endOfWeek),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox(
            height: 300,
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final last7DaysSoldItems = snapshot.data ?? [];

        // Group sales by date and product
        Map<String, Map<String, dynamic>> dailySalesData = {};

        for (var date in last7Days) {
          final dateKey = DateFormat('yyyy-MM-dd').format(date);
          dailySalesData[dateKey] = {
            'date': date,
            'products': <String, int>{},
            'total': 0,
          };
        }

        // Process last 7 days sold items
        for (var item in last7DaysSoldItems) {
          final dateKey = DateFormat('yyyy-MM-dd').format(item.timestamp);
          if (dailySalesData.containsKey(dateKey)) {
            final productName = item.product?.name ?? 'Khác';
            dailySalesData[dateKey]!['products'][productName] =
                ((dailySalesData[dateKey]!['products']
                        as Map<String, int>)[productName] ??
                    0) +
                item.quantity;
            dailySalesData[dateKey]!['total'] =
                (dailySalesData[dateKey]!['total'] as int) + item.quantity;
          }
        }

        // Find max value for chart scaling
        int maxQuantity = 10; // Minimum scale
        int totalWeek = 0;
        for (var data in dailySalesData.values) {
          final total = data['total'] as int;
          totalWeek += total;
          if (total > maxQuantity) maxQuantity = total;
        }
        maxQuantity =
            ((maxQuantity / 10).ceil() + 1) * 10; // Round up to nearest 10

        // Calculate average
        final average = totalWeek / 7;

        // Always show total week sales
        final referenceTotal = totalWeek;

        // Calculate comparison with previous week
        final previousWeekStartOfWeek = startOfWeek.subtract(
          const Duration(days: 7),
        );
        final previousWeekEndOfWeek = previousWeekStartOfWeek.add(
          const Duration(days: 6, hours: 23, minutes: 59, seconds: 59),
        );

        return FutureBuilder<List<SoldItem>>(
          future: _db.getSoldItemsByDateRange(
            previousWeekStartOfWeek,
            previousWeekEndOfWeek,
          ),
          builder: (context, prevSnapshot) {
            int previousWeekTotal = 0;

            if (prevSnapshot.hasData) {
              for (var item in (prevSnapshot.data ?? [])) {
                previousWeekTotal += item.quantity as int;
              }
            }

            int percentChange = 0;
            bool isIncrease = true;
            if (previousWeekTotal > 0) {
              percentChange =
                  (((referenceTotal - previousWeekTotal) / previousWeekTotal) *
                          100)
                      .abs()
                      .round();
              isIncrease = referenceTotal >= previousWeekTotal;
            }

            return Card(
              elevation: 10,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Số lượng bán ra',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).brightness == Brightness.dark
                                    ? Colors.white
                                    : Colors.black,
                            letterSpacing: 0.5,
                          ),
                        ),
                        Column(
                          children: [
                            Row(
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.arrow_back),
                                  onPressed: () {
                                    setState(() => _weekOffset++);
                                  },
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  iconSize: 20,
                                ),
                                const SizedBox(width: 8),
                                IconButton(
                                  icon: const Icon(Icons.arrow_forward),
                                  onPressed: _weekOffset > 0
                                      ? () {
                                          setState(() => _weekOffset--);
                                        }
                                      : null,
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  iconSize: 20,
                                ),
                              ],
                            ),
                            Padding(
                              padding: const EdgeInsets.only(top: 4.0),
                              child: Builder(
                                builder: (context) {
                                  final baseDate = now.subtract(
                                    Duration(days: _weekOffset * 7),
                                  );
                                  final weekStart = baseDate.subtract(
                                    Duration(days: baseDate.weekday - 1),
                                  );
                                  final weekEnd = weekStart.add(
                                    const Duration(days: 6),
                                  );
                                  return Text(
                                    '${DateFormat('dd/MM').format(weekStart)} - ${DateFormat('dd/MM').format(weekEnd)}',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Theme.of(context).brightness == Brightness.dark
                                    ? Colors.white
                                    : Colors.black54,
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '$referenceTotal',
                              style: const TextStyle(
                                fontSize: 48,
                                fontWeight: FontWeight.w300,
                                letterSpacing: -1,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Padding(
                              padding: const EdgeInsets.only(bottom: 12.0),
                              child: Text(
                                'bán được tuần này',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w400,
                                  color: Theme.of(context).brightness == Brightness.dark
                                    ? Colors.white
                                    : Colors.black54,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (previousWeekTotal > 0)
                          Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Row(
                              children: [
                                Icon(
                                  isIncrease
                                      ? Icons.arrow_upward
                                      : Icons.arrow_downward,
                                  size: 16,
                                  color: isIncrease ? Colors.green : Colors.red,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '$percentChange% so với tuần trước',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isIncrease
                                        ? Colors.green
                                        : Colors.red,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    // Bar chart
                    SizedBox(
                      height: 200,
                      child: Stack(
                        children: [
                          // Bars
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: last7Days.asMap().entries.map((entry) {
                              final index = entry.key;
                              final date = entry.value;
                              final dateKey = DateFormat(
                                'yyyy-MM-dd',
                              ).format(date);
                              final dayData = dailySalesData[dateKey]!;
                              final products =
                                  dayData['products'] as Map<String, int>;
                              final total = dayData['total'] as int;
                              final isToday =
                                  _weekOffset == 0 &&
                                  dateKey ==
                                      DateFormat('yyyy-MM-dd').format(now);

                              return Expanded(
                                child: GestureDetector(
                                  onTap: () {
                                    if (total > 0) {
                                      _showProductDetails(
                                        date,
                                        products,
                                        total,
                                      );
                                    }
                                  },
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      // Number above bar
                                      if (total > 0)
                                        Padding(
                                          padding: const EdgeInsets.only(
                                            bottom: 4.0,
                                          ),
                                          child: Text(
                                            '$total',
                                            style:  TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                              color: Theme.of(context).brightness == Brightness.dark
                                                ? Colors.white
                                                : Colors.black45,
                                            ),
                                          ),
                                        ),
                                      // Bar
                                      Center(
                                        child: Container(
                                          width: 35,
                                          height: total > 0
                                              ? (total / maxQuantity) * 120
                                              : 2,
                                          decoration: BoxDecoration(
                                            color: total > 0
                                                ? (isToday
                                                      ? Colors.blue
                                                      : Colors.blue.shade200)
                                                : Colors.grey[300],
                                            borderRadius:
                                                const BorderRadius.vertical(
                                                  top: Radius.circular(4),
                                                ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      // Day label - fixed pattern
                                      Text(
                                        _getFixedDayLabel(index),
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: isToday
                                            ? (Theme.of(context).brightness == Brightness.dark
                                              ? Colors.white
                                              : Colors.black)
                                            : (Theme.of(context).brightness == Brightness.dark
                                              ? Colors.white54
                                              : Colors.grey),
                                          fontWeight: isToday
                                              ? FontWeight.bold
                                              : FontWeight.normal,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                          // Average line
                          if (average > 0)
                            Positioned(
                              left: 0,
                              right: 0,
                              bottom: 30 + (average / maxQuantity) * 120,
                              child: Row(
                                children: [
                                  Expanded(
                                    child: DashedLine(color: Colors.green),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Info text
                    Center(
                      child: Text(
                        'Nhấn vào cột để xem chi tiết',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey[600],
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  String _getFixedDayLabel(int index) {
    // Always fixed pattern: T2, T3, T4, T5, T6, T7, CN
    // Index 0 = T2, Index 1 = T3, Index 2 = T4, etc., Index 6 = CN
    const days = ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];
    return days[index];
  }

  void _showProductDetails(
    DateTime date,
    Map<String, int> products,
    int total,
  ) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        final sortedProducts = products.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));

        return Container(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.calendar_today, color: Colors.blue),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      DateFormat('EEEE, dd/MM/yyyy', 'vi').format(date),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Bán được $total sản phẩm',
                style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              ),
              const Divider(height: 24),
              const Text(
                'Số lượng bán ra:',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: sortedProducts.length,
                  itemBuilder: (context, index) {
                    final entry = sortedProducts[index];
                    final percent = (entry.value / total * 100).toStringAsFixed(1);
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6.0),
                      child: Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: Colors.blue,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              entry.key,
                              style: const TextStyle(fontSize: 14),
                            ),
                          ),
                          Text(
                            '${entry.value} ($percent%)',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTrendLineChart() {
    // Group data by date
    Map<DateTime, Map<String, int>> dailyData = {};

    // Process sold items
    for (var item in _soldItems) {
      final dateOnly = DateTime(
        item.timestamp.year,
        item.timestamp.month,
        item.timestamp.day,
      );
      if (!dailyData.containsKey(dateOnly)) {
        dailyData[dateOnly] = {'revenue': 0, 'expenses': 0};
      }
      dailyData[dateOnly]!['revenue'] =
          (dailyData[dateOnly]!['revenue'] ?? 0) + item.priceAfterDiscount;
    }

    // Process expenses
    for (var expense in _expenses) {
      final dateOnly = DateTime(
        expense.timestamp.year,
        expense.timestamp.month,
        expense.timestamp.day,
      );
      if (!dailyData.containsKey(dateOnly)) {
        dailyData[dateOnly] = {'revenue': 0, 'expenses': 0};
      }
      dailyData[dateOnly]!['expenses'] =
          (dailyData[dateOnly]!['expenses'] ?? 0) + expense.amount;
    }

    // Sort by date (oldest to newest)
    final sortedDates = dailyData.keys.toList()..sort();
    final sortedDateStrings = sortedDates
        .map((date) => DateFormat('dd/MM').format(date))
        .toList();

    if (sortedDates.isEmpty) {
      return Card(
        elevation: 10,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              const Text(
                'Xu hướng Doanh thu & Chi phí',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Text(
                'Chưa có dữ liệu để hiển thị',
                style: TextStyle(color: Colors.grey[600]),
              ),
            ],
          ),
        ),
      );
    }

    // Prepare chart data (ensure no negative values)
    List<FlSpot> revenueSpots = [];
    List<FlSpot> expenseSpots = [];

    for (int i = 0; i < sortedDates.length; i++) {
      final date = sortedDates[i];
      final data = dailyData[date]!;
      final revenue = (data['revenue'] ?? 0).toDouble();
      final expenses = (data['expenses'] ?? 0).toDouble();

      // Ensure values are never negative
      revenueSpots.add(FlSpot(i.toDouble(), revenue.clamp(0, double.infinity)));
      expenseSpots.add(
        FlSpot(i.toDouble(), expenses.clamp(0, double.infinity)),
      );
    }

    // Calculate max value for Y axis
    double maxY = 0;
    for (var data in dailyData.values) {
      final revenue = data['revenue'] ?? 0;
      final expenses = data['expenses'] ?? 0;
      if (revenue > maxY) maxY = revenue.toDouble();
      if (expenses > maxY) maxY = expenses.toDouble();
    }
    maxY = (maxY * 1.2); // Add 20% padding
    if (maxY == 0) maxY = 100000; // Default if no data

    return Card(
      elevation: 10,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Xu hướng Doanh thu & Chi phí',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const SizedBox(height: 20),
            SizedBox(
              height: 250,
              child: LineChart(
                LineChartData(
                  clipData: FlClipData.all(),
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: maxY / 5,
                    getDrawingHorizontalLine: (value) {
                      // Don't draw grid lines below 0
                      if (value < 0) return FlLine(strokeWidth: 0);
                      return FlLine(color: Colors.grey[300]!, strokeWidth: 1);
                    },
                  ),
                  titlesData: FlTitlesData(
                    show: true,
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 30,
                        interval: 1,
                        getTitlesWidget: (double value, TitleMeta meta) {
                          if (value.toInt() >= 0 &&
                              value.toInt() < sortedDateStrings.length) {
                            return Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: Text(
                                sortedDateStrings[value.toInt()],
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Theme.of(context).brightness == Brightness.dark
                                    ? Colors.white
                                    : Colors.black,
                                ),
                              ),
                            );
                          }
                          return const Text('');
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        interval: maxY / 5,
                        reservedSize: 45,
                        getTitlesWidget: (double value, TitleMeta meta) {
                          // Don't show negative values on Y axis
                          if (value < 0) return const Text('');
                          return Text(
                            _formatCompactCurrency(value.toInt()),
                            style: TextStyle(
                              fontSize: 10,
                              color: Theme.of(context).brightness == Brightness.dark
                                    ? Colors.white
                                    : Colors.black,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  borderData: FlBorderData(
                    show: true,
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  minX: 0,
                  maxX: (sortedDates.length - 1).toDouble(),
                  minY: 0.0,
                  maxY: maxY,
                  lineBarsData: [
                    LineChartBarData(
                      spots: revenueSpots,
                      isCurved: true,
                      color: Colors.green,
                      barWidth: 3,
                      isStrokeCapRound: true,
                      dotData: FlDotData(
                        show: true,
                        getDotPainter: (spot, percent, barData, index) {
                          return FlDotCirclePainter(
                            radius: 4,
                            color: Colors.green,
                            strokeWidth: 2,
                            strokeColor: Colors.white,
                          );
                        },
                      ),
                      belowBarData: BarAreaData(
                        show: true,
                        color: Colors.green.withValues(alpha: 0.1),
                      ),
                    ),
                    LineChartBarData(
                      spots: expenseSpots,
                      isCurved: true,
                      color: Colors.red,
                      barWidth: 3,
                      isStrokeCapRound: true,
                      dotData: FlDotData(
                        show: true,
                        getDotPainter: (spot, percent, barData, index) {
                          return FlDotCirclePainter(
                            radius: 4,
                            color: Colors.red,
                            strokeWidth: 2,
                            strokeColor: Colors.white,
                          );
                        },
                      ),
                      belowBarData: BarAreaData(
                        show: true,
                        color: Colors.red.withValues(alpha: 0.1),
                      ),
                    ),
                  ],
                  lineTouchData: LineTouchData(
                    touchTooltipData: LineTouchTooltipData(
                      getTooltipItems: (List<LineBarSpot> touchedSpots) {
                        if (touchedSpots.isEmpty) return [];

                        // Get date from first spot (show only once)
                        final index = touchedSpots.first.x.toInt();
                        final date = sortedDates[index];
                        final dateStr = DateFormat('dd/MM/yyyy').format(date);

                        return touchedSpots.asMap().entries.map((entry) {
                          final spotIndex = entry.key;
                          final spot = entry.value;

                          // Show date in white only for the first item
                          if (spotIndex == 0) {
                            return LineTooltipItem(
                              '$dateStr\n',
                              const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                              children: [
                                TextSpan(
                                  text: _formatCurrency(spot.y.toInt()),
                                  style: TextStyle(
                                    color: spot.bar.color,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            );
                          } else {
                            return LineTooltipItem(
                              _formatCurrency(spot.y.toInt()),
                              TextStyle(
                                color: spot.bar.color,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            );
                          }
                        }).toList();
                      },
                      tooltipPadding: const EdgeInsets.all(8),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatCompactCurrency(int amount) {
    if (amount >= 1000000) {
      return '${(amount / 1000000).toStringAsFixed(1)} Tr';
    }
    return amount.toString();
  }

  Widget _buildTopProductsList() {
    // Calculate top selling products
    final Map<int, Map<String, dynamic>> productStats = {};

    for (var item in _soldItems) {
      if (!productStats.containsKey(item.productId)) {
        productStats[item.productId] = {
          'product': item.product,
          'quantity': 0,
          'revenue': 0,
        };
      }
      productStats[item.productId]!['quantity'] += item.quantity;
      productStats[item.productId]!['revenue'] += item.priceAfterDiscount;
    }

    final topProducts = productStats.entries.toList()
      ..sort(
        (a, b) =>
            (b.value['revenue'] as int).compareTo(a.value['revenue'] as int),
      );

    final top5 = topProducts.take(5).toList();

    if (top5.isEmpty) {
      return Card(
        elevation: 10,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              const Text(
                'Sản phẩm bán chạy',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Text(
                'Chưa có dữ liệu bán hàng',
                style: TextStyle(color: Colors.grey[600]),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      elevation: 10,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Sản phẩm bán chạy',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            ...top5.map((entry) {
              final product = entry.value['product'];
              final quantity = entry.value['quantity'];
              final revenue = entry.value['revenue'];

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.blue.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.inventory_2, color: Colors.blue),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            product?.name ?? 'Sản phẩm',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Text(
                            'Đã bán: $quantity',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      _formatCurrency(revenue),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildExpensesPieChart() {
    // Calculate expenses by category
    final Map<String, int> categoryTotals = {};

    for (var expense in _expenses) {
      categoryTotals[expense.category] =
          (categoryTotals[expense.category] ?? 0) + expense.amount;
    }

    if (categoryTotals.isEmpty) {
      return Card(
        elevation: 10,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              const Text(
                'Biểu đồ Chi phí',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Text(
                'Chưa có dữ liệu chi phí',
                style: TextStyle(color: Colors.grey[600]),
              ),
            ],
          ),
        ),
      );
    }

    // Sort by value (largest first) to ensure consistent ordering
    final sortedCategoriesForChart = categoryTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    // Create pie chart sections
    List<PieChartSectionData> sections = [];
    int colorIndex = 0;

    for (var entry in sortedCategoriesForChart) {
      final percent = _totalExpenses > 0
          ? (entry.value / _totalExpenses * 100)
          : 0.0;

      sections.add(
        PieChartSectionData(
          color: _pieChartColors[colorIndex % _pieChartColors.length],
          value: entry.value.toDouble(),
          title: '${percent.toStringAsFixed(1)}%',
          radius: 100,
          titleStyle: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      );
      colorIndex++;
    }

    return Card(
      elevation: 10,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Biểu đồ Chi phí',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            // Pie Chart only (larger, full width)
            SizedBox(
              height: 250,
              child: PieChart(
                PieChartData(
                  sections: sections,
                  sectionsSpace: 2,
                  centerSpaceRadius: 40,
                  borderData: FlBorderData(show: false),
                  pieTouchData: PieTouchData(
                    touchCallback: (FlTouchEvent event, pieTouchResponse) {
                      // Optional: Add interaction here
                    },
                  ),
                ),
              ),
            ),
            const SizedBox(height: 25),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.shade200, width: 1.5),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Tổng chi phí:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: Colors.red,
                    ),
                  ),
                  Text(
                    _formatCurrency(_totalExpenses),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: Colors.red,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExpensesCategoryBreakdown() {
    // Calculate expenses by category
    final Map<String, int> categoryTotals = {};

    for (var expense in _expenses) {
      categoryTotals[expense.category] =
          (categoryTotals[expense.category] ?? 0) + expense.amount;
    }

    final sortedCategories = categoryTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    if (sortedCategories.isEmpty) {
      return Card(
        elevation: 10,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              const Text(
                'Chi phí theo danh mục',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Text(
                'Chưa có dữ liệu chi phí',
                style: TextStyle(color: Colors.grey[600]),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      elevation: 10,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Chi phí theo danh mục',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            ...sortedCategories.asMap().entries.map((entry) {
              final colorIndex = entry.key;
              final categoryEntry = entry.value;
              final pieColor =
                  _pieChartColors[colorIndex % _pieChartColors.length];
              final percent = _totalExpenses > 0
                  ? (categoryEntry.value / _totalExpenses)
                  : 0.0;

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 10.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        // Color indicator dot
                        Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: pieColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            categoryEntry.key,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        Text(
                          _formatCurrency(categoryEntry.value),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.red,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: percent,
                              backgroundColor: Colors.grey[200],
                              valueColor: AlwaysStoppedAnimation<Color>(
                                pieColor,
                              ),
                              minHeight: 8,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${(percent * 100).toStringAsFixed(1)}%',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }
}

// Custom DashedLine widget for average line
class DashedLine extends StatelessWidget {
  final Color color;
  final double dashWidth;
  final double dashSpace;

  const DashedLine({
    super.key,
    required this.color,
    this.dashWidth = 5,
    this.dashSpace = 3,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final boxWidth = constraints.constrainWidth();
        final dashCount = (boxWidth / (dashWidth + dashSpace)).floor();
        return Flex(
          direction: Axis.horizontal,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(dashCount, (_) {
            return SizedBox(
              width: dashWidth,
              height: 1,
              child: DecoratedBox(decoration: BoxDecoration(color: color)),
            );
          }),
        );
      },
    );
  }
}
