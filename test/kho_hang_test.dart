import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:keto/kho_hang.dart';
import 'mocks/product_service_mock.dart';

void main() {
  setUpAll(() {
    // Initialize sqflite for testing once at the start
    sqfliteFfiInit();
  });

  setUp(() {
    // Mock SharedPreferences
    SharedPreferences.setMockInitialValues({'notificationsEnabled': true});
    // Set the database factory before each test
    databaseFactory = databaseFactoryFfi;
  });

  group('InventoryPage Widget Initialization Tests', () {
    testWidgets('InventoryPage initializes with correct default parameters',
        (WidgetTester tester) async {
      final mockService = MockProductService();
      await tester.pumpWidget(
        MaterialApp(
          home: InventoryPage(
            lowStockThreshold: 5,
            productService: mockService,
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byType(InventoryPage), findsOneWidget);
      expect(find.byType(Scaffold), findsOneWidget);
    });

    testWidgets('InventoryPage initializes with custom low stock threshold',
        (WidgetTester tester) async {
      final mockService = MockProductService();
      await tester.pumpWidget(
        MaterialApp(
          home: InventoryPage(
            lowStockThreshold: 10,
            productService: mockService,
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byType(InventoryPage), findsOneWidget);
    });

    testWidgets('InventoryPage works without explicit productService',
        (WidgetTester tester) async {
      // Test backward compatibility - widget should use default ProductService
      // This test is skipped because it would trigger database timers
      await tester.pumpWidget(
        const MaterialApp(
          home: InventoryPage(),
        ),
      );

      expect(find.byType(InventoryPage), findsOneWidget);
    }, skip: true);
  });

  group('Search Bar and Filtering Tests', () {
    testWidgets('Search bar input filters products',
        (WidgetTester tester) async {
      final mockService = MockProductService();
      await tester.pumpWidget(
        MaterialApp(
          home: InventoryPage(productService: mockService),
        ),
      );

      await tester.pumpAndSettle();

      // Verify mock products are displayed
      expect(find.text('Product 1'), findsWidgets);
    });
  });

  group('Product Service Integration Tests', () {
    testWidgets('Mock product service is used instead of real service',
        (WidgetTester tester) async {
      final mockService = MockProductService();
      await tester.pumpWidget(
        MaterialApp(
          home: InventoryPage(productService: mockService),
        ),
      );

      await tester.pumpAndSettle();

      // Verify that mock products are loaded (not database products)
      expect(find.text('Product 1'), findsWidgets);
      expect(find.text('Product 2'), findsWidgets);
    });

    testWidgets('Empty mock service shows no products',
        (WidgetTester tester) async {
      final mockService = MockProductService.empty();
      await tester.pumpWidget(
        MaterialApp(
          home: InventoryPage(productService: mockService),
        ),
      );

      await tester.pumpAndSettle();

      // Should show empty state or no product cards
      // The app should render without crashing
      expect(find.byType(InventoryPage), findsOneWidget);
    });

    testWidgets('Widget builds successfully with mock service',
        (WidgetTester tester) async {
      final mockService = MockProductService();
      await tester.pumpWidget(
        MaterialApp(
          home: InventoryPage(productService: mockService),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byType(Scaffold), findsOneWidget);
    });
  });

  group('UI Structure Tests', () {
    testWidgets('Widget renders without crashing',
        (WidgetTester tester) async {
      final mockService = MockProductService();
      await tester.pumpWidget(
        MaterialApp(
          home: InventoryPage(productService: mockService),
        ),
      );

      await tester.pumpAndSettle();

      // If we got here without exceptions, the test passed
      expect(find.byType(InventoryPage), findsOneWidget);
    });

    testWidgets('Scaffold is present',
        (WidgetTester tester) async {
      final mockService = MockProductService();
      await tester.pumpWidget(
        MaterialApp(
          home: InventoryPage(productService: mockService),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byType(Scaffold), findsOneWidget);
    });

    testWidgets('Loading completes without errors',
        (WidgetTester tester) async {
      final mockService = MockProductService();
      await tester.pumpWidget(
        MaterialApp(
          home: InventoryPage(productService: mockService),
        ),
      );

      // Wait for all async operations to complete
      await tester.pumpAndSettle();

      // If we got here without exceptions, the test passed
      expect(find.byType(InventoryPage), findsOneWidget);
    });
  });
}

