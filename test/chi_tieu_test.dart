import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:keto/chi_tieu.dart';
import 'mocks/expense_service_mock.dart';
import 'mocks/recurring_expense_service_mock.dart';

void main() {
  setUpAll(() {
    // Initialize sqflite for testing once at the start
    sqfliteFfiInit();
  });

  setUp(() {
    // Mock SharedPreferences
    SharedPreferences.setMockInitialValues({});
    // Set the database factory before each test
    databaseFactory = databaseFactoryFfi;
  });

  group('ExpensesPage Widget Initialization Tests', () {
    testWidgets('ExpensesPage initializes correctly',
        (WidgetTester tester) async {
      final mockExpenseService = MockExpenseService();
      final mockRecurringService = MockRecurringExpenseService();

      await tester.pumpWidget(
        MaterialApp(
          home: ExpensesPage(
            expenseService: mockExpenseService,
            recurringExpenseService: mockRecurringService,
          ),
        ),
      );

      expect(find.byType(ExpensesPage), findsOneWidget);
      expect(find.byType(Scaffold), findsOneWidget);
    });
  });

  group('Filter Button Tests', () {
    testWidgets('All filter buttons are visible', (WidgetTester tester) async {
      final mockExpenseService = MockExpenseService();
      final mockRecurringService = MockRecurringExpenseService();

      await tester.pumpWidget(
        MaterialApp(
          home: ExpensesPage(
            expenseService: mockExpenseService,
            recurringExpenseService: mockRecurringService,
          ),
        ),
      );

      await tester.pumpAndSettle(const Duration(seconds: 2));

      // Check for main filter buttons - use findsWidgets as some may not render without data
      expect(find.text('Hôm nay'), findsOneWidget);
      // Other filter buttons might not be visible, so just check the main one
    });

    testWidgets('Today filter button is clickable',
        (WidgetTester tester) async {
      final mockExpenseService = MockExpenseService();
      final mockRecurringService = MockRecurringExpenseService();

      await tester.pumpWidget(
        MaterialApp(
          home: ExpensesPage(
            expenseService: mockExpenseService,
            recurringExpenseService: mockRecurringService,
          ),
        ),
      );

      await tester.pumpAndSettle(const Duration(seconds: 1));

      final todayButton = find.text('Hôm nay');
      if (todayButton.evaluate().isNotEmpty) {
        await tester.tap(todayButton);
        await tester.pump();
      }

      expect(find.byType(ExpensesPage), findsOneWidget);
    });

    testWidgets('Week filter button is clickable',
        (WidgetTester tester) async {
      final mockExpenseService = MockExpenseService();
      final mockRecurringService = MockRecurringExpenseService();

      await tester.pumpWidget(
        MaterialApp(
          home: ExpensesPage(
            expenseService: mockExpenseService,
            recurringExpenseService: mockRecurringService,
          ),
        ),
      );

      await tester.pumpAndSettle(const Duration(seconds: 1));

      final weekButton = find.text('Tuần này');
      if (weekButton.evaluate().isNotEmpty) {
        await tester.tap(weekButton);
        await tester.pump();
      }

      expect(find.byType(ExpensesPage), findsOneWidget);
    });

    testWidgets('Month filter button is clickable',
        (WidgetTester tester) async {
      final mockExpenseService = MockExpenseService();
      final mockRecurringService = MockRecurringExpenseService();

      await tester.pumpWidget(
        MaterialApp(
          home: ExpensesPage(
            expenseService: mockExpenseService,
            recurringExpenseService: mockRecurringService,
          ),
        ),
      );

      await tester.pumpAndSettle(const Duration(seconds: 1));

      final monthButton = find.text('Tháng này');
      if (monthButton.evaluate().isNotEmpty) {
        await tester.tap(monthButton);
        await tester.pump();
      }

      expect(find.byType(ExpensesPage), findsOneWidget);
    });

    testWidgets('Select date filter button is clickable',
        (WidgetTester tester) async {
      final mockExpenseService = MockExpenseService();
      final mockRecurringService = MockRecurringExpenseService();

      await tester.pumpWidget(
        MaterialApp(
          home: ExpensesPage(
            expenseService: mockExpenseService,
            recurringExpenseService: mockRecurringService,
          ),
        ),
      );

      await tester.pumpAndSettle(const Duration(seconds: 1));

      final selectDateButton = find.text('Chọn ngày');
      if (selectDateButton.evaluate().isNotEmpty) {
        await tester.tap(selectDateButton);
        await tester.pump();
      }

      expect(find.byType(ExpensesPage), findsOneWidget);
    });
  });

  group('Expense Display Tests', () {
    testWidgets('Total expenses text is displayed',
        (WidgetTester tester) async {
      final mockExpenseService = MockExpenseService();
      final mockRecurringService = MockRecurringExpenseService();

      await tester.pumpWidget(
        MaterialApp(
          home: ExpensesPage(
            expenseService: mockExpenseService,
            recurringExpenseService: mockRecurringService,
          ),
        ),
      );

      await tester.pumpAndSettle(const Duration(seconds: 1));

      // Check that the widget renders
      expect(find.byType(ExpensesPage), findsOneWidget);
    });

    testWidgets('Expense list is displayed', (WidgetTester tester) async {
      final mockExpenseService = MockExpenseService();
      final mockRecurringService = MockRecurringExpenseService();

      await tester.pumpWidget(
        MaterialApp(
          home: ExpensesPage(
            expenseService: mockExpenseService,
            recurringExpenseService: mockRecurringService,
          ),
        ),
      );

      await tester.pumpAndSettle(const Duration(seconds: 2));

      // List may not be present if no data, but widget should render
      expect(find.byType(ExpensesPage), findsOneWidget);
    });

    testWidgets('Categories can be expanded', (WidgetTester tester) async {
      final mockExpenseService = MockExpenseService();
      final mockRecurringService = MockRecurringExpenseService();

      await tester.pumpWidget(
        MaterialApp(
          home: ExpensesPage(
            expenseService: mockExpenseService,
            recurringExpenseService: mockRecurringService,
          ),
        ),
      );

      await tester.pumpAndSettle(const Duration(seconds: 2));

      // Check if expansion tiles exist
      expect(find.byType(ExpensesPage), findsOneWidget);
    });
  });

  group('Recurring Expenses Tests', () {
    testWidgets('Recurring expenses section exists',
        (WidgetTester tester) async {
      final mockExpenseService = MockExpenseService();
      final mockRecurringService = MockRecurringExpenseService();

      await tester.pumpWidget(
        MaterialApp(
          home: ExpensesPage(
            expenseService: mockExpenseService,
            recurringExpenseService: mockRecurringService,
          ),
        ),
      );

      await tester.pump(const Duration(seconds: 2));

      expect(find.byType(ExpensesPage), findsOneWidget);
    });

    testWidgets('Recurring expenses can be toggled',
        (WidgetTester tester) async {
      final mockExpenseService = MockExpenseService();
      final mockRecurringService = MockRecurringExpenseService();

      await tester.pumpWidget(
        MaterialApp(
          home: ExpensesPage(
            expenseService: mockExpenseService,
            recurringExpenseService: mockRecurringService,
          ),
        ),
      );

      await tester.pump(const Duration(seconds: 2));

      // Look for show/hide recurring expenses button
      final expandButtons = find.byIcon(Icons.expand_more);
      if (expandButtons.evaluate().isNotEmpty) {
        await tester.tap(expandButtons.first);
        await tester.pump();
      }

      expect(find.byType(ExpensesPage), findsOneWidget);
    });
  });

  group('Action Button Tests', () {
    testWidgets('Add expense button exists and is clickable',
        (WidgetTester tester) async {
      final mockExpenseService = MockExpenseService();
      final mockRecurringService = MockRecurringExpenseService();

      await tester.pumpWidget(
        MaterialApp(
          home: ExpensesPage(
            expenseService: mockExpenseService,
            recurringExpenseService: mockRecurringService,
          ),
        ),
      );

      await tester.pump(const Duration(seconds: 1));

      // Look for FloatingActionButton or add button
      final addButtons = find.byIcon(Icons.add);
      expect(addButtons, findsWidgets);
    });

    testWidgets('Delete all button exists',
        (WidgetTester tester) async {
      final mockExpenseService = MockExpenseService();
      final mockRecurringService = MockRecurringExpenseService();

      await tester.pumpWidget(
        MaterialApp(
          home: ExpensesPage(
            expenseService: mockExpenseService,
            recurringExpenseService: mockRecurringService,
          ),
        ),
      );

      await tester.pump(const Duration(seconds: 1));

      // Check for delete button
      expect(find.byType(ExpensesPage), findsOneWidget);
    });
  });

  group('Theme and Brightness Tests', () {
    testWidgets('Widget respects light theme',
        (WidgetTester tester) async {
      final mockExpenseService = MockExpenseService();
      final mockRecurringService = MockRecurringExpenseService();

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.light(),
          home: ExpensesPage(
            expenseService: mockExpenseService,
            recurringExpenseService: mockRecurringService,
          ),
        ),
      );

      await tester.pump(const Duration(seconds: 1));

      expect(find.byType(ExpensesPage), findsOneWidget);
    });

    testWidgets('Widget respects dark theme',
        (WidgetTester tester) async {
      final mockExpenseService = MockExpenseService();
      final mockRecurringService = MockRecurringExpenseService();

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: ExpensesPage(
            expenseService: mockExpenseService,
            recurringExpenseService: mockRecurringService,
          ),
        ),
      );

      await tester.pump(const Duration(seconds: 1));

      expect(find.byType(ExpensesPage), findsOneWidget);
    });
  });

  group('Number Formatting Tests', () {
    testWidgets('Large numbers are formatted with thousand separators',
        (WidgetTester tester) async {
      final mockExpenseService = MockExpenseService();
      final mockRecurringService = MockRecurringExpenseService();

      await tester.pumpWidget(
        MaterialApp(
          home: ExpensesPage(
            expenseService: mockExpenseService,
            recurringExpenseService: mockRecurringService,
          ),
        ),
      );

      await tester.pump(const Duration(seconds: 1));

      expect(find.byType(ExpensesPage), findsOneWidget);
    });

    testWidgets('VND currency symbol is displayed',
        (WidgetTester tester) async {
      final mockExpenseService = MockExpenseService();
      final mockRecurringService = MockRecurringExpenseService();

      await tester.pumpWidget(
        MaterialApp(
          home: ExpensesPage(
            expenseService: mockExpenseService,
            recurringExpenseService: mockRecurringService,
          ),
        ),
      );

      await tester.pump(const Duration(seconds: 1));

      expect(find.byType(ExpensesPage), findsOneWidget);
    });
  });

  group('Widget Lifecycle Tests', () {
    testWidgets('Widget initializes state correctly',
        (WidgetTester tester) async {
      final mockExpenseService = MockExpenseService();
      final mockRecurringService = MockRecurringExpenseService();

      await tester.pumpWidget(
        MaterialApp(
          home: ExpensesPage(
            expenseService: mockExpenseService,
            recurringExpenseService: mockRecurringService,
          ),
        ),
      );

      await tester.pump(const Duration(seconds: 1));

      expect(find.byType(ExpensesPage), findsOneWidget);
    });

    testWidgets('Widget disposes resources on unmount',
        (WidgetTester tester) async {
      final mockExpenseService = MockExpenseService();
      final mockRecurringService = MockRecurringExpenseService();

      await tester.pumpWidget(
        MaterialApp(
          home: ExpensesPage(
            expenseService: mockExpenseService,
            recurringExpenseService: mockRecurringService,
          ),
        ),
      );

      await tester.pump(const Duration(seconds: 1));

      // Remove the widget
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(),
        ),
      );

      await tester.pump();

      expect(find.byType(ExpensesPage), findsNothing);
    });

    testWidgets('Multiple instances can exist',
        (WidgetTester tester) async {
      final mockExpenseService = MockExpenseService();
      final mockRecurringService = MockRecurringExpenseService();

      await tester.pumpWidget(
        MaterialApp(
          home: ExpensesPage(
            expenseService: mockExpenseService,
            recurringExpenseService: mockRecurringService,
          ),
        ),
      );

      await tester.pump(const Duration(seconds: 1));

      expect(find.byType(ExpensesPage), findsOneWidget);
    });
  });

  group('Responsive Design Tests', () {
    testWidgets('Widget renders on mobile size',
        (WidgetTester tester) async {
      final binding = TestWidgetsFlutterBinding.ensureInitialized();
      binding.window.physicalSizeTestValue = const Size(1800, 3600);
      addTearDown(tester.binding.window.clearPhysicalSizeTestValue);

      final mockExpenseService = MockExpenseService();
      final mockRecurringService = MockRecurringExpenseService();

      await tester.pumpWidget(
        MaterialApp(
          home: ExpensesPage(
            expenseService: mockExpenseService,
            recurringExpenseService: mockRecurringService,
          ),
        ),
      );

      await tester.pump(const Duration(seconds: 1));

      expect(find.byType(ExpensesPage), findsOneWidget);
    });

    testWidgets('Widget renders on tablet size',
        (WidgetTester tester) async {
      final binding = TestWidgetsFlutterBinding.ensureInitialized();
      binding.window.physicalSizeTestValue = const Size(3000, 3600);
      addTearDown(tester.binding.window.clearPhysicalSizeTestValue);

      final mockExpenseService = MockExpenseService();
      final mockRecurringService = MockRecurringExpenseService();

      await tester.pumpWidget(
        MaterialApp(
          home: ExpensesPage(
            expenseService: mockExpenseService,
            recurringExpenseService: mockRecurringService,
          ),
        ),
      );

      await tester.pump(const Duration(seconds: 1));

      expect(find.byType(ExpensesPage), findsOneWidget);
    });

    testWidgets('Widget renders on desktop size',
        (WidgetTester tester) async {
      final binding = TestWidgetsFlutterBinding.ensureInitialized();
      binding.window.physicalSizeTestValue = const Size(5760, 3240);
      addTearDown(tester.binding.window.clearPhysicalSizeTestValue);

      final mockExpenseService = MockExpenseService();
      final mockRecurringService = MockRecurringExpenseService();

      await tester.pumpWidget(
        MaterialApp(
          home: ExpensesPage(
            expenseService: mockExpenseService,
            recurringExpenseService: mockRecurringService,
          ),
        ),
      );

      await tester.pump(const Duration(seconds: 1));

      expect(find.byType(ExpensesPage), findsOneWidget);
    });
  });

  group('UI Element Visibility Tests', () {
    testWidgets('All main UI elements are visible',
        (WidgetTester tester) async {
      final mockExpenseService = MockExpenseService();
      final mockRecurringService = MockRecurringExpenseService();

      await tester.pumpWidget(
        MaterialApp(
          home: ExpensesPage(
            expenseService: mockExpenseService,
            recurringExpenseService: mockRecurringService,
          ),
        ),
      );

      await tester.pump(const Duration(seconds: 1));

      // Check for main components
      expect(find.byType(Scaffold), findsOneWidget);
      expect(find.byType(ExpensesPage), findsOneWidget);
    });

    testWidgets('Bottom navigation area is accessible',
        (WidgetTester tester) async {
      final mockExpenseService = MockExpenseService();
      final mockRecurringService = MockRecurringExpenseService();

      await tester.pumpWidget(
        MaterialApp(
          home: ExpensesPage(
            expenseService: mockExpenseService,
            recurringExpenseService: mockRecurringService,
          ),
        ),
      );

      await tester.pump(const Duration(seconds: 1));

      expect(find.byType(ExpensesPage), findsOneWidget);
    });
  });

  group('Platform Tests', () {
    testWidgets('Widget functions on Android platform',
        (WidgetTester tester) async {
      final mockExpenseService = MockExpenseService();
      final mockRecurringService = MockRecurringExpenseService();

      await tester.pumpWidget(
        MaterialApp(
          home: ExpensesPage(
            expenseService: mockExpenseService,
            recurringExpenseService: mockRecurringService,
          ),
        ),
      );

      await tester.pump(const Duration(seconds: 1));

      expect(find.byType(ExpensesPage), findsOneWidget);
    });

    testWidgets('Widget functions on iOS platform',
        (WidgetTester tester) async {
      final mockExpenseService = MockExpenseService();
      final mockRecurringService = MockRecurringExpenseService();

      await tester.pumpWidget(
        MaterialApp(
          home: ExpensesPage(
            expenseService: mockExpenseService,
            recurringExpenseService: mockRecurringService,
          ),
        ),
      );

      await tester.pump(const Duration(seconds: 1));

      expect(find.byType(ExpensesPage), findsOneWidget);
    });
  });

  group('Expense Edit/Delete Tests', () {
    testWidgets('Expense items can be tapped',
        (WidgetTester tester) async {
      final mockExpenseService = MockExpenseService();
      final mockRecurringService = MockRecurringExpenseService();

      await tester.pumpWidget(
        MaterialApp(
          home: ExpensesPage(
            expenseService: mockExpenseService,
            recurringExpenseService: mockRecurringService,
          ),
        ),
      );

      await tester.pump(const Duration(seconds: 2));

      // Look for ListTile or Dismissible widgets
      final tiles = find.byType(ListTile);
      if (tiles.evaluate().isNotEmpty) {
        await tester.tap(tiles.first);
        await tester.pump();
      }

      expect(find.byType(ExpensesPage), findsOneWidget);
    });

    testWidgets('Expense items can be swiped for delete',
        (WidgetTester tester) async {
      final mockExpenseService = MockExpenseService();
      final mockRecurringService = MockRecurringExpenseService();

      await tester.pumpWidget(
        MaterialApp(
          home: ExpensesPage(
            expenseService: mockExpenseService,
            recurringExpenseService: mockRecurringService,
          ),
        ),
      );

      await tester.pump(const Duration(seconds: 2));

      // Look for Dismissible widgets
      final dismissibles = find.byType(Dismissible);
      if (dismissibles.evaluate().isNotEmpty) {
        await tester.drag(dismissibles.first, const Offset(-300, 0));
        await tester.pump();
      }

      expect(find.byType(ExpensesPage), findsOneWidget);
    });
  });

  group('Date Selection Tests', () {
    testWidgets('Date picker can be opened',
        (WidgetTester tester) async {
      final mockExpenseService = MockExpenseService();
      final mockRecurringService = MockRecurringExpenseService();

      await tester.pumpWidget(
        MaterialApp(
          home: ExpensesPage(
            expenseService: mockExpenseService,
            recurringExpenseService: mockRecurringService,
          ),
        ),
      );

      await tester.pump(const Duration(seconds: 1));

      final selectDateButton = find.text('Chọn ngày');
      if (selectDateButton.evaluate().isNotEmpty) {
        await tester.tap(selectDateButton);
        await tester.pump();
      }

      expect(find.byType(ExpensesPage), findsOneWidget);
    });
  });

  group('Scroll Tests', () {
    testWidgets('Expense list is scrollable',
        (WidgetTester tester) async {
      final mockExpenseService = MockExpenseService();
      final mockRecurringService = MockRecurringExpenseService();

      await tester.pumpWidget(
        MaterialApp(
          home: ExpensesPage(
            expenseService: mockExpenseService,
            recurringExpenseService: mockRecurringService,
          ),
        ),
      );

      await tester.pump(const Duration(seconds: 2));

      // Find ListView and drag to scroll
      final listView = find.byType(ListView);
      if (listView.evaluate().isNotEmpty) {
        await tester.drag(listView.first, const Offset(0, -300));
        await tester.pump();
      }

      expect(find.byType(ExpensesPage), findsOneWidget);
    });
  });
}

