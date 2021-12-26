import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:possystem/models/customer/customer_setting.dart';
import 'package:possystem/models/customer/customer_setting_option.dart';
import 'package:possystem/models/menu/catalog.dart';
import 'package:possystem/models/menu/product.dart';
import 'package:possystem/models/menu/product_ingredient.dart';
import 'package:possystem/models/menu/product_quantity.dart';
import 'package:possystem/models/order/order_product.dart';
import 'package:possystem/models/repository/cart.dart';
import 'package:possystem/models/repository/cashier.dart';
import 'package:possystem/models/repository/customer_settings.dart';
import 'package:possystem/models/repository/menu.dart';
import 'package:possystem/models/repository/quantities.dart';
import 'package:possystem/models/repository/seller.dart';
import 'package:possystem/models/repository/stock.dart';
import 'package:possystem/models/stock/ingredient.dart';
import 'package:possystem/models/stock/quantity.dart';
import 'package:possystem/routes.dart';
import 'package:possystem/settings/currency_setting.dart';
import 'package:possystem/settings/order_awakening_setting.dart';
import 'package:possystem/settings/order_outlook_setting.dart';
import 'package:possystem/settings/order_product_axis_count_setting.dart';
import 'package:possystem/settings/setting.dart';
import 'package:possystem/translator.dart';
import 'package:possystem/ui/order/order_screen.dart';
import 'package:provider/provider.dart';

import '../../mocks/mock_cache.dart';
import '../../mocks/mock_database.dart';
import '../../mocks/mock_storage.dart';
import '../../test_helpers/translator.dart';

void main() {
  group('Order actions', () {
    void prepareData() {
      SettingsProvider([
        CurrencySetting(),
        OrderOutlookSetting(),
        OrderAwakeningSetting(),
        OrderProductAxisCountSetting(),
      ]).loadSetting();

      Stock().replaceItems({
        'i-1': Ingredient(id: 'i-1', name: 'i-1'),
        'i-2': Ingredient(id: 'i-2', name: 'i-2'),
      });
      Quantities().replaceItems({
        'q-1': Quantity(id: 'q-1', name: 'q-1'),
        'q-2': Quantity(id: 'q-2', name: 'q-2')
      });
      final ingreidnet1 = ProductIngredient(
        id: 'pi-1',
        ingredient: Stock.instance.getItem('i-1'),
        amount: 5,
        quantities: {
          'pq-1': ProductQuantity(
            id: 'pq-1',
            quantity: Quantities.instance.getItem('q-1'),
            amount: 5,
            additionalCost: 5,
            additionalPrice: 10,
          ),
          'pq-2': ProductQuantity(
            id: 'pq-2',
            quantity: Quantities.instance.getItem('q-2'),
            amount: -5,
            additionalCost: -5,
            additionalPrice: -10,
          ),
        },
      );
      final ingreidnet2 = ProductIngredient(
        id: 'pi-2',
        ingredient: Stock.instance.getItem('i-2'),
        amount: 3,
      );
      final product = Product(id: 'p-1', name: 'p-1', price: 17, ingredients: {
        'pi-1': ingreidnet1..prepareItem(),
        'pi-2': ingreidnet2..prepareItem(),
      });
      Menu().replaceItems({
        'c-1': Catalog(
          id: 'c-1',
          name: 'c-1',
          index: 1,
          products: {'p-1': product..prepareItem()},
        )..prepareItem(),
        'c-2': Catalog(
          name: 'c-2',
          id: 'c-2',
          index: 2,
          products: {'p-2': Product(id: 'p-2', name: 'p-2', price: 11)},
        )..prepareItem(),
      });

      final s1 = CustomerSetting(
          id: 'c-1', options: {'co-1': CustomerSettingOption(id: 'co-1')});
      final s2 = CustomerSetting(
          id: 'c-2', options: {'co-2': CustomerSettingOption(id: 'co-2')});
      CustomerSettings().replaceItems({
        'c-1': s1..prepareItem(),
        'c-2': s2..prepareItem(),
      });

      Cart.instance = Cart();
      Cart.instance.replaceAll(products: [
        OrderProduct(Menu.instance.getProduct('p-1')!),
        OrderProduct(Menu.instance.getProduct('p-2')!),
      ], customerSettings: {
        'c-1': 'co-1',
        'c-2': 'co-2'
      });
      Seller();
    }

    Map<String, Object> getDbData() {
      return {
        'id': 1,
        'createdAt': 12345678,
        'encodedProducts': jsonEncode([
          {
            'singlePrice': 10,
            'originalPrice': 10,
            'count': 1,
            'productId': 'p-1',
            'productName': 'p-1',
            'isDiscount': false,
            'ingredients': [
              {
                'name': 'i-1',
                'id': 'i-1',
                'amount': 10,
                'additionalPrice': 10,
                'additionalCost': 5,
                'quantityId': 'q-1',
                'quantityName': 'q-1',
                'productIngredientId': 'pi-1',
                'productQuantityId': 'pq-1',
              }
            ]
          },
          {
            'singlePrice': 10,
            'originalPrice': 10,
            'count': 1,
            'productId': 'p-3',
            'productName': 'p-3',
            'isDiscount': false,
            'ingredients': []
          },
        ]),
      };
    }

    void verifyOderPoped() {
      expect(Cart.instance.products.length, equals(1));
      final product = Cart.instance.products.first;
      expect(product.id, equals('p-1'));
      expect(product.isEmpty, isFalse);

      expect(find.byKey(const Key('cart_snapshot.0')), findsOneWidget);

      final w = find.byKey(const Key('cart.product.0')).evaluate().first.widget
          as ListTile;
      expect((w.title as Text).data, equals('p-1'));
      expect((w.subtitle as RichText).text.toPlainText(),
          equals(S.orderProductIngredientName('i-1', 'q-1')));
    }

    testWidgets('Leave history mode', (tester) async {
      Cart.instance.isHistoryMode = true;

      await tester.pumpWidget(const MaterialApp(home: OrderScreen()));

      expect(find.byKey(const Key('cart_snapshot.0')), findsOneWidget);
      await tester.tap(find.byKey(const Key('order.action.more')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('order.action.leave_history')));
      await tester.pumpAndSettle();

      expect(Cart.instance.products.length, isZero);
      expect(find.byKey(const Key('cart_snapshot.0')), findsNothing);
    });

    testWidgets('Show last order', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: OrderScreen()));

      act(bool? confirm) async {
        await tester.tap(find.byKey(const Key('order.action.more')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('order.action.show_last')));
        await tester.pumpAndSettle();
        if (confirm != null) {
          final a = confirm ? 'confirm' : 'cancel';
          await tester.tap(find.byKey(Key('confirm_dialog.$a')));
          await tester.pumpAndSettle();
        }
      }

      await act(false);

      // failed to stash
      when(database.count(any)).thenAnswer((_) => Future.value(5));
      await act(true);
      verifyNever(database.push(Seller.stashTable, any));
      verify(database.count(Seller.stashTable));

      // no data before
      when(database.count(any)).thenAnswer((_) => Future.value(1));
      when(database.push(Seller.stashTable, any))
          .thenAnswer((_) => Future.value(1));
      // get customer setting combination
      when(database.query(
        CustomerSettings.combinationTable,
        columns: anyNamed('columns'),
        where: anyNamed('where'),
        whereArgs: anyNamed('whereArgs'),
        limit: anyNamed('limit'),
      )).thenAnswer((_) => Future.value([
            {'id': 1}
          ]));
      // get last order
      when(database.getLast(
        any,
        columns: anyNamed('columns'),
        where: anyNamed('where'),
        whereArgs: anyNamed('whereArgs'),
        join: anyNamed('join'),
        orderByKey: anyNamed('orderByKey'),
      )).thenAnswer((_) => Future.value(null));
      await act(true);
      verify(database.push(Seller.stashTable, any));

      // should be stashed
      expect(Cart.instance.isEmpty, isTrue);

      when(database.getLast(
        any,
        columns: anyNamed('columns'),
        where: anyNamed('where'),
        whereArgs: anyNamed('whereArgs'),
        join: anyNamed('join'),
        orderByKey: anyNamed('orderByKey'),
      )).thenAnswer((_) => Future.value(getDbData()));
      await act(null);

      verifyOderPoped();
      expect(Cart.instance.isHistoryMode, isTrue);
    });

    testWidgets('Drop stashed', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: OrderScreen()));

      act(bool? confirm) async {
        await tester.tap(find.byKey(const Key('order.action.more')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('order.action.drop_stash')));
        await tester.pumpAndSettle();
        if (confirm != null) {
          final a = confirm ? 'confirm' : 'cancel';
          await tester.tap(find.byKey(Key('confirm_dialog.$a')));
          await tester.pumpAndSettle();
        }
      }

      await act(false);

      // failed to stash
      when(database.count(any)).thenAnswer((_) => Future.value(5));
      await act(true);
      verifyNever(database.push(Seller.stashTable, any));
      verify(database.count(Seller.stashTable));

      // no data before
      when(database.count(any)).thenAnswer((_) => Future.value(1));
      when(database.push(Seller.stashTable, any))
          .thenAnswer((_) => Future.value(1));
      // add customer setting combination
      when(database.push(CustomerSettings.combinationTable, any))
          .thenAnswer((_) => Future.value(2));
      // get empty customer setting combination
      when(database.query(
        CustomerSettings.combinationTable,
        columns: anyNamed('columns'),
        where: anyNamed('where'),
        whereArgs: anyNamed('whereArgs'),
        limit: anyNamed('limit'),
      )).thenAnswer((_) => Future.value([]));
      when(database.getLast(
        any,
        columns: anyNamed('columns'),
        join: anyNamed('join'),
        count: anyNamed('count'),
        orderByKey: anyNamed('orderByKey'),
      )).thenAnswer((_) => Future.value(null));
      await act(true);
      verify(database.push(Seller.stashTable, any));
      verify(database.push(CustomerSettings.combinationTable, any));
      verify(database.getLast(
        Seller.stashTable,
        columns: anyNamed('columns'),
        join: anyNamed('join'),
        count: anyNamed('count'),
        orderByKey: anyNamed('orderByKey'),
      ));

      // should be stashed
      expect(Cart.instance.isEmpty, isTrue);

      when(database.getLast(
        any,
        columns: anyNamed('columns'),
        join: anyNamed('join'),
        count: anyNamed('count'),
        orderByKey: anyNamed('orderByKey'),
      )).thenAnswer((_) => Future.value(getDbData()));
      await act(null);

      verifyOderPoped();
    });

    testWidgets('Stash', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: OrderScreen()));

      act() async {
        await tester.tap(find.byKey(const Key('order.action.more')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('order.action.stash')));
        await tester.pumpAndSettle();
      }

      // failed to stash
      when(database.count(any)).thenAnswer((_) => Future.value(5));
      await act();

      when(database.count(any)).thenAnswer((_) => Future.value(1));
      when(database.push(any, any)).thenAnswer((_) => Future.value(1));
      when(database.query(
        CustomerSettings.combinationTable,
        columns: anyNamed('columns'),
        where: anyNamed('where'),
        whereArgs: argThat(equals([',c-1:co-1,c-2:co-2,']), named: 'whereArgs'),
        limit: anyNamed('limit'),
      )).thenAnswer((_) => Future.value([
            {'id': 1}
          ]));
      await act();

      expect(Cart.instance.isEmpty, isTrue);
      verify(database.push(
          Seller.stashTable,
          argThat(predicate((data) =>
              data is Map &&
              data['createdAt'] != null &&
              data['customerSettingCombinationId'] == 1 &&
              data['encodedProducts'] != null))));
    });

    testWidgets('Changer', (tester) async {
      final cashier = Cashier();
      when(storage.get(any, any)).thenAnswer((_) => Future.value({
            'current': [
              {'unit': 1, 'count': 0},
              {'unit': 5, 'count': 1}
            ],
            'favorites': [
              {
                'source': {'unit': 5, 'count': 1},
                'targets': [
                  {'unit': 1, 'count': 5},
                ],
              },
            ]
          }));
      await cashier.reset();

      await tester.pumpWidget(ChangeNotifierProvider.value(
        value: cashier,
        child: MaterialApp(routes: Routes.routes, home: const OrderScreen()),
      ));

      await tester.tap(find.byKey(const Key('order.action.more')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('order.action.changer')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('cashier.changer.favorite.0')));
      await tester.tap(find.byKey(const Key('cashier.changer.apply')));
      await tester.pumpAndSettle();

      // should go back
      expect(find.byKey(const Key('order.action.more')), findsOneWidget);
      expect(cashier.at(0).count, equals(5));
      expect(cashier.at(1).count, isZero);
    });

    setUp(() {
      // disable and features
      when(cache.get(any)).thenReturn(null);

      prepareData();
    });

    setUpAll(() {
      initializeCache();
      initializeDatabase();
      initializeStorage();
      initializeTranslator();
    });
  });
}
