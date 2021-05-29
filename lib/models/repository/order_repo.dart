import 'package:possystem/helper/util.dart';
import 'package:possystem/models/objects/order_object.dart';
import 'package:possystem/services/database.dart';
import 'package:possystem/ui/home/home_screen.dart';

class OrderRepo {
  static final OrderRepo _instance = OrderRepo._constructor();

  static OrderRepo get instance => _instance;

  OrderRepo._constructor();

  Future<num> getStashLength() {
    return Database.instance.count(Tables.order_stash);
  }

  Future<OrderObject> pop() async {
    final row = await Database.instance.getLast(
      Tables.order,
      columns: ['id', 'encodedProducts', 'createdAt'],
    );
    if (row == null) return null;
    print('order pop ${row['id']}');

    return OrderObject.build(row);
  }

  Future<void> push(OrderObject order) {
    print('add order ${order.totalPrice}');
    HomeScreen.orderInfo?.currentState?.reset();

    return Database.instance.push(Tables.order, order.toMap());
  }

  Future<void> update(OrderObject order) {
    print('update order ${order.id}');
    HomeScreen.orderInfo?.currentState?.reset();

    return Database.instance.update(
      Tables.order,
      order.id,
      order.toMap(),
    );
  }

  Future<void> stash(OrderObject order) {
    final data = order.toMap();
    return Database.instance.push(Tables.order_stash, {
      'createdAt': data['createdAt'],
      'encodedProducts': data['encodedProducts'],
    });
  }

  Future<OrderObject> popStash() async {
    final row = await Database.instance.getLast(
      Tables.order_stash,
      columns: ['id', 'encodedProducts', 'createdAt'],
    );
    if (row == null) return null;

    print('pop stash ${row['id']}');

    final object = OrderObject.build(row);

    await Database.instance.delete(Tables.order_stash, object.id);

    return object;
  }

  Future<Map<String, num>> todayOrder() async {
    final result = await Database.query(
      Tables.order,
      columns: ['COUNT(*) count', 'SUM(totalPrice) revenue'],
      where: 'createdAt > ${Util.toUTC(hour: 0)}',
    );
    print('totay order $result');

    return result.isEmpty || result[0]['count'] == 0
        ? {'revenue': 0, 'count': 0}
        : result[0];

    // return result.isEmpty ? {'revenue': 0, 'count': 0} : result[0];
  }

  Future<List<Map<String, Object>>> countByDay(DateTime start, DateTime end) {
    return Database.rawQuery(
      Tables.order,
      columns: ['COUNT(*) count', 'createdAt'],
      where: 'createdAt BETWEEN ? AND ?',
      groupBy: "STRFTIME('%d', createdAt,'unixepoch')",
      whereArgs: [
        Util.toUTC(now: start),
        Util.toUTC(now: end),
      ],
    );
  }

  Future getBetween(DateTime start, DateTime end) {
    return Database.query(
      Tables.order,
      where: 'createdAt BETWEEN ? AND ?',
      whereArgs: [
        Util.toUTC(now: start),
        Util.toUTC(now: end),
      ],
      orderBy: 'createdAt desc',
    );
  }
}