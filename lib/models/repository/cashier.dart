import 'dart:math';

import 'package:flutter/material.dart';
import 'package:possystem/helpers/logger.dart';
import 'package:possystem/models/objects/cashier_object.dart';
import 'package:possystem/services/storage.dart';

class Cashier extends ChangeNotifier {
  static const _FAVORITES = 'favorites';

  static const _CURRENT = 'current';

  static const _DEFAULT = 'default';

  static Cashier instance = Cashier();

  /// Cashier current status
  final List<CashierUnitObject> _current = [];

  /// Cashier default status
  final List<CashierUnitObject> _default = [];

  /// Changer favorite
  final List<CashierChangeBatchObject> _favorites = [];

  /// Cashier current using currency name
  late String _recordName;

  num get currentTotal => _current.fold(0, (value, e) => value + e.total);

  bool get defaultNotSet => _default.isEmpty;

  num get defaultTotal => _default.fold(0, (value, e) => value + e.total);

  bool get favoriteIsEmpty => _favorites.isEmpty;

  int get favoriteLength => _favorites.length;

  /// Cashier current using currency units lenght
  int get unitLength => _current.length;

  /// Add [count] money from unit [index] to cashier
  void add(int index, int count) {
    update({index: count});
  }

  Future<void> addFavorite(CashierChangeBatchObject item) {
    _favorites.add(item);

    return updateFavoriteStorage();
  }

  Future<void> paid(num price, {num? oldPrice}) {
    print(price);
    final deltas = getUpdateDataFromPrice(price);
    print(deltas);
    if (oldPrice != null) {
      getUpdateDataFromPrice(oldPrice).forEach((key, value) {
        deltas[key] = deltas.containsKey(key) ? deltas[key]! - value : -value;
      });
    }

    return update(deltas);
  }

  Map<int, int> getUpdateDataFromPrice(num price) {
    final result = <int, int>{};

    var index = unitLength - 1;
    for (var item in _current.reversed) {
      if (item.unit <= price) {
        final count = (price / item.unit).floor();
        result[index] = -count;

        price -= item.unit * count;
        if (price == 0) break;
      }
      index--;
    }

    return result;
  }

  Future<bool> applyFavorite(CashierChangeBatchObject item) async {
    final sourceIndex = indexOf(item.source.unit!);
    if (!validate(sourceIndex, item.source.count!)) {
      return false;
    }

    await update({
      sourceIndex: -item.source.count!,
      for (var target in item.targets) indexOf(target.unit!): target.count!
    });

    return true;
  }

  /// Get current unit from [index]
  CashierUnitObject at(int index) {
    return _current[index];
  }

  Future<void> deleteFavorite(int index) async {
    try {
      _favorites.removeAt(index);

      await updateFavoriteStorage();
    } catch (e) {
      await error(
        'total: $unitLength, index: $index',
        'cashier.favorite.not_found',
      );
    }
  }

  CashierChangeBatchObject favoriteAt(int index) {
    return _favorites[index];
  }

  /// Find Possible change from [count] and [unit]
  ///
  /// If [count] is equal 1, change smaller unit
  /// else change larger unit
  ///
  /// ```dart
  /// final units = [10, 100, 500, 1000]
  /// change(10, 100); // [2-500];
  /// change(1, 100); // [10-10];
  /// ```
  List<CashierChangeEntryObject> findPossibleChange(int count, num unit) {
    final index = indexOf(unit);
    if (index == -1) {
      return [];
    }

    if (count == 1) {
      final result = <CashierChangeEntryObject>[];
      for (var i = index - 1; i >= 0; i--) {
        final unitObject = _current[i];
        final unitCount = (unit / unitObject.unit).floor();
        unit -= unitCount * unitObject.unit;

        result.add(CashierChangeEntryObject(
          unit: unitObject.unit,
          count: unitCount,
        ));

        if (unit == 0) {
          break;
        }
      }

      return result;
    } else if (count > 1) {
      final total = count * unit;
      var i = unitLength - 1;

      if (i == index && i > 0) {
        final unit = _current[i - 1].unit;

        return [
          CashierChangeEntryObject(
            unit: unit,
            count: (total / unit).floor(),
          ),
        ];
      }

      final result = <CashierChangeEntryObject>[];

      for (i; i > index; i--) {
        final item = _current[i];
        // if not enough to change this unit
        if (total < item.unit) {
          continue;
        }

        final unitCount = (total / item.unit).floor();

        result.add(CashierChangeEntryObject(
          unit: item.unit,
          count: unitCount,
        ));

        break;
      }

      return result;
    }

    return [];
  }

  /// Current and default difference
  Iterable<List<CashierUnitObject>> getDifference() sync* {
    final iterators = [
      _current,
      _default,
    ].map((e) => e.iterator).toList(growable: false);

    while (iterators.every((e) => e.moveNext())) {
      yield iterators.map((e) => e.current).toList(growable: false);
    }
  }

  /// Get index of specific [unit]
  int indexOf(num unit) {
    return _current.indexWhere((element) => element.unit == unit);
  }

  /// Minus [count] money from unit [index] to cashier
  void minus(int index, int count) {
    update({index: -count});
  }

  /// When [Currency] changed, it must be fired
  Future<void> reset(String name, List<num> units) async {
    _recordName = name;
    final record = await Storage.instance.get(Stores.cashier, _recordName);

    await setCurrent(record[_CURRENT], units);
    await setFavorite(record[_FAVORITES]);

    if (record[_DEFAULT] != null) {
      await setDefault(record: record[_DEFAULT]);
    }
  }

  Future<void> setCurrent(Object? record, List<num> currency) async {
    try {
      // if null, set to empty units
      assert(record != null);

      _current
        ..clear()
        ..addAll([
          for (var unit in record as Iterable)
            CashierUnitObject.fromMap(unit.cast<String, num>())
        ]);
    } catch (e, stack) {
      if (e is! AssertionError) {
        await error(e.toString(), 'cashier.fetch.unit.error', stack);
      }
      _current
        ..clear()
        ..addAll([
          for (var unit in currency) CashierUnitObject(unit: unit, count: 0)
        ]);

      // reset to empty
      await updateCurrentStorage();
    }
  }

  /// Set default data
  ///
  /// If [record] is null, [useCurrent] must be true
  Future<void> setDefault({
    Object? record,
    bool useCurrent = false,
  }) async {
    assert(record != null || useCurrent);

    if (useCurrent) {
      _default
        ..clear()
        ..addAll([
          for (var item in _current)
            CashierUnitObject(unit: item.unit, count: item.count)
        ]);
    } else {
      try {
        _default
          ..clear()
          ..addAll([
            for (var item in record as Iterable)
              CashierUnitObject.fromMap(item.cast<String, num>())
          ]);
      } catch (e, stack) {
        await error(e.toString(), 'cashier.fetch.unit.error', stack);
      }
    }

    await updateDefaultStorage();
  }

  Future<void> setFavorite(Object? record) async {
    try {
      _favorites
        ..clear()
        ..addAll([
          for (var map in (record ?? []) as Iterable)
            CashierChangeBatchObject.fromMap(map)
        ]);
    } catch (e, stack) {
      await error(e.toString(), 'cashier.fetch.favorite.error', stack);
      _favorites.clear();
    }
  }

  Future<void> surplus() async {
    final length = min(_current.length, _default.length);
    for (var i = 0; i < length; i++) {
      _current[i].count = _default[i].count;
    }

    await updateCurrentStorage();
    notifyListeners();
  }

  /// Update chashier by [deltas]
  ///
  /// [deltas] key is index of units
  Future<void> update(Map<int, int> deltas) async {
    var isUpdated = false;
    deltas.forEach((index, value) {
      _current[index].count += value;
      if (_current[index].count < 0) {
        _current[index].count = 0;
      }
      isUpdated = isUpdated || value != 0;
    });

    if (isUpdated) {
      await updateCurrentStorage();
      notifyListeners();
    }
  }

  Future<void> updateCurrentStorage() {
    return Storage.instance.set(Stores.cashier, {
      '$_recordName.$_CURRENT': _current.map((e) => e.toMap()).toList(),
    });
  }

  Future<void> updateDefaultStorage() {
    return Storage.instance.set(Stores.cashier, {
      '$_recordName.$_DEFAULT': _default.map((e) => e.toMap()).toList(),
    });
  }

  Future<void> updateFavoriteStorage() {
    return Storage.instance.set(Stores.cashier, {
      '$_recordName.$_FAVORITES': _favorites.map((e) => e.toMap()).toList(),
    });
  }

  /// Check specific unit by [index] has valid [count] to minus
  bool validate(int index, int count) {
    return _current[index].count >= count;
  }
}