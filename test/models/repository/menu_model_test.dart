import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:possystem/models/repository/menu_model.dart';

import '../../mocks/mockito/mock_product_model.dart';
import '../../mocks/mockito/mock_catalog_model.dart';
import '../../mocks/mockito/mock_product_ingredient_model.dart';
import '../../mocks/mocks.dart';
import '../../test_helpers/check_notifier.dart';
import '../menu/product_ingredient_model_test.mocks.dart';

void main() {
  test('#constructor', () {
    when(storage.get(any)).thenAnswer((e) => Future.value({
          'id1': {
            'name': 'catalog1',
            'index': 1,
            'createdAt': 1623639573,
            'products': {
              'pid1': {
                'name': 'product1',
                'index': 1,
                'price': 1,
                'cost': 2,
                'createdAt': 1623639573
              },
            },
          },
          'id2': {
            'name': 'catalog2',
            'index': 2,
            'createdAt': 1623639573,
          },
        }));
    final menu = MenuModel();

    var isCalled = false;
    menu.addListener(() {
      expect(menu.getItem('id1')!.getItem('pid1')!.name, equals('product1'));
      expect(menu.getItem('id2')!.items, isEmpty);
      expect(menu.isReady, isTrue);
      isCalled = true;
    });

    Future.delayed(Duration.zero, () => expect(isCalled, isTrue));
  });

  late MenuModel menu;

  MockCatalogModel createCatalog(
      String id, Map<String, Map<String, List<String>>> products) {
    final catalog = MockCatalogModel();

    when(catalog.id).thenReturn(id);
    when(catalog.name).thenReturn('$id-name');
    final cItems = <MockProductModel>[];
    when(catalog.items).thenReturn(cItems);
    when(catalog.getItem(any)).thenReturn(null);

    products.forEach((productId, ingredients) {
      final product = MockProductModel();

      when(product.id).thenReturn(productId);
      when(product.name).thenReturn('$productId-name');
      final pItems = <MockProductIngredientModel>[];
      when(product.items).thenReturn(pItems);
      when(product.getItem(any)).thenReturn(null);

      ingredients.forEach((ingredientId, quantities) {
        final ingredient = MockProductIngredientModel();
        when(ingredient.id).thenReturn(ingredientId);
        when(ingredient.prefix)
            .thenReturn('$id-$productId-$ingredientId-prefix');
        when(ingredient.product).thenReturn(product);
        when(ingredient.getItem(any)).thenReturn(null);

        final iItems = quantities.map((quantityId) {
          final quantity = MockProductQuantityModel();
          when(quantity.id).thenReturn(quantityId);
          when(quantity.prefix)
              .thenReturn('$id-$productId-$ingredientId-$quantityId-prefix');
          when(quantity.ingredient).thenReturn(ingredient);
          when(ingredient.getItem(quantityId)).thenReturn(quantity);

          return quantity;
        }).toList();

        when(ingredient.items).thenReturn(iItems);

        when(product.getItem(ingredientId)).thenReturn(ingredient);
        pItems.add(ingredient);
      });

      when(catalog.getItem(productId)).thenReturn(product);
      cItems.add(product);
    });

    menu.addItem(catalog);

    return catalog;
  }

  group('getter', () {
    test('#getProduct', () {
      createCatalog('id1', {'pdt_1': {}, 'pdt_2': {}});
      createCatalog('id2', {'pdt_3': {}, 'pdt_4': {}});

      expect(menu.getProduct('pdt_1'), isNotNull);
      expect(menu.getProduct('pdt_4'), isNotNull);
      expect(menu.getProduct('pdt_5'), isNull);
    });

    test('#getIngredients', () {
      createCatalog('id1', {
        'pdt_1': {'igt_1': [], 'igt_2': []},
        'pdt_2': {'igt_1': [], 'igt_3': []},
      });
      createCatalog('id2', {
        'pdt_3': {'igt_1': [], 'igt_3': []},
        'pdt_4': {'igt_2': [], 'igt_4': []},
      });

      expect(menu.getIngredients('igt_1').length, equals(3));
      expect(menu.getIngredients('igt_2').length, equals(2));
      expect(menu.getIngredients('igt_5'), isEmpty);
    });

    test('#getQuantities', () {
      createCatalog('id1', {
        'pdt_1': {
          'igt_1': ['qty_1', 'qty_2'],
          'igt_2': ['qty_1', 'qty_3'],
        },
        'pdt_2': {
          'igt_1': [],
          'igt_3': ['qty_2', 'qty_4']
        },
      });
      createCatalog('id2', {
        'pdt_3': {
          'igt_1': ['qty_2'],
          'igt_3': ['qty_4']
        },
      });

      expect(menu.getQuantities('qty_1').length, equals(2));
      expect(menu.getQuantities('qty_2').length, equals(3));
      expect(menu.getQuantities('qty_5'), isEmpty);
    });
  });

  group('checker', () {
    test('#hasCatalog', () {
      createCatalog('ctg_1', {'pdt_1': {}, 'pdt_2': {}});
      createCatalog('ctg_2', {});

      expect(menu.hasCatalog('ctg_1-name'), isTrue);
      expect(menu.hasCatalog('ctg_2'), isFalse);
      expect(menu.hasCatalog('ctg_3-name'), isFalse);
    });

    test('#hasProduct', () {
      createCatalog('ctg_1', {'pdt_1': {}, 'pdt_2': {}});
      createCatalog('ctg_2', {});

      expect(menu.hasProduct('pdt_1-name'), isTrue);
      expect(menu.hasProduct('pdt_2'), isFalse);
      expect(menu.hasProduct('pdt_3-name'), isFalse);
    });
  });

  group('remover', () {
    test('should do nothing if not found', () async {
      createCatalog('ctg_1', {
        'pdt_1': {'igt_1': []},
        'pdt_2': {'igt_1': []},
      });

      final isCalled = await checkNotifierCalled(
          menu, () => menu.removeIngredients('igt_2'));

      expect(isCalled, isFalse);
      verifyNever(storage.set(any, any));
    });

    test('should fire storage and notify listener', () async {
      createCatalog('ctg_1', {
        'pdt_1': {'igt_1': []},
        'pdt_2': {'igt_1': []},
      });

      final isCalled = await checkNotifierCalled(
          menu, () => menu.removeIngredients('igt_1'));

      expect(isCalled, isTrue);
      verify(storage.set(
        any,
        argThat(equals({
          'ctg_1-pdt_1-igt_1-prefix': null,
          'ctg_1-pdt_2-igt_1-prefix': null,
        })),
      ));
      final product1 = menu.getProduct('pdt_1') as MockProductModel;
      final product2 = menu.getProduct('pdt_2') as MockProductModel;
      verify(product1.removeItem(argThat(equals('igt_1'))));
      verify(product2.removeItem(argThat(equals('igt_1'))));
    });

    test('should work on quantity', () async {
      createCatalog('ctg_1', {
        'pdt_1': {
          'igt_1': ['qty_1']
        },
        'pdt_2': {
          'igt_2': ['qty_1']
        },
      });

      final isCalled =
          await checkNotifierCalled(menu, () => menu.removeQuantities('qty_1'));

      expect(isCalled, isTrue);
      verify(storage.set(
        any,
        argThat(equals({
          'ctg_1-pdt_1-igt_1-qty_1-prefix': null,
          'ctg_1-pdt_2-igt_2-qty_1-prefix': null,
        })),
      ));
      final igt1 =
          menu.getIngredients('igt_1').first as MockProductIngredientModel;
      final igt2 =
          menu.getIngredients('igt_2').first as MockProductIngredientModel;
      verify(igt1.removeItem(argThat(equals('qty_1'))));
      verify(igt2.removeItem(argThat(equals('qty_1'))));
    });
  });

  setUp(() {
    when(storage.get(any)).thenAnswer((e) => Future.value({}));
    menu = MenuModel();
  });

  setUpAll(() {
    initialize();
  });
}