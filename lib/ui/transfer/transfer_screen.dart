import 'package:flutter/material.dart';
import 'package:possystem/components/style/pop_button.dart';

class TransferScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('匯出匯入'),
        leading: PopButton(),
      ),
      body: Container(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Image.asset('assets/working_on_it.png'),
            Text(
              '正在加緊趕工中！',
              style: Theme.of(context).textTheme.headline4,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
