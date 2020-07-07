import 'package:flutter/material.dart';

import 'package:iboxpro_flutter/iboxpro_flutter.dart';
import 'package:signature_pad/signature_pad.dart';
import 'package:signature_pad_flutter/signature_pad_flutter.dart';

void main() => runApp(MyApp());

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: PaymentExample(),
    );
  }
}

class PaymentExample extends StatefulWidget {
  @override
  _PaymentExample createState() => _PaymentExample();
}

class _PaymentExample extends State<PaymentExample> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  String _loginEmail = '';
  String _password = '';
  String _deviceAddress = '';
  String _trId;
  bool _requiredSignature = false;
  String _paymentProgressText = 'Оплата не проводилась';
  int _timeout = 30;
  double _amount = 50;
  SignaturePadController _padController = SignaturePadController();

  void _showSnackBar(String content) {
    _scaffoldKey.currentState?.showSnackBar(SnackBar(content: Text(content)));
  }

  List<Widget> _buildLoginPart(BuildContext context) {
    return [
      TextFormField(
        initialValue: _loginEmail,
        maxLines: 1,
        decoration: InputDecoration(labelText: 'Логин'),
        onChanged: (val) => _loginEmail = val
      ),
      TextFormField(
        initialValue: _password,
        obscureText: true,
        maxLines: 1,
        decoration: InputDecoration(labelText: 'Пароль'),
        onChanged: (val) => _password = val
      ),
      RaisedButton(
        child: Text('Войти'),
        onPressed: () async {
          showDialog(
            context: context,
            builder: (BuildContext context) => Center(child: CircularProgressIndicator())
          );

          await PaymentController.login(
            email: _loginEmail,
            password: _password,
            onLogin: (Map<dynamic, dynamic> result) {
              Navigator.pop(context);

              if (result['errorCode'] == 0) {
                _showSnackBar('Успешно вошли в систему');
              } else {
                _showSnackBar('Произошла ошибка');
              }
            }
          );
        },
      )
    ];
  }

  List<Widget> _buildTimeoutPart(BuildContext context) {
    return [
      Row(
        children: <Widget>[
          Expanded(
            child: TextFormField(
              initialValue: _timeout.toString(),
              maxLines: 1,
              decoration: InputDecoration(labelText: 'Таймаут'),
              onChanged: (val) => _timeout = int.tryParse(val)
            )
          ),
          SizedBox(
            width: 150,
            child: RaisedButton(
              child: Text('Установить'),
              onPressed: () async {
                await PaymentController.setRequestTimeout(timeout: _timeout);
                _showSnackBar('Таймаут установлен');
              },
            )
          )
        ]
      )
    ];
  }

  List<Widget> _buildSearchDevicePart(BuildContext context) {
    return [
      TextFormField(
        initialValue: _deviceAddress,
        maxLines: 1,
        decoration: InputDecoration(labelText: 'MAC адрес терминала'),
        onChanged: (val) => _deviceAddress = val
      ),
      RaisedButton(
        child: Text('Подключиться к терминалу'),
        onPressed: () async {
          await PaymentController.startSearchBTDevice(
            deviceAddress: _deviceAddress,
            onReaderSetBTDevice: () async {
              _showSnackBar('Успешно установлена связь с терминалом');
            }
          );
        },
      ),
      RaisedButton(
        child: Text('Перестать искать терминал'),
        onPressed: () async {
          await PaymentController.stopSearchBTDevice();
          _showSnackBar('Поиск отключен');
        },
      )
    ];
  }

  List<Widget> _buildPaymentPart(BuildContext context) {
    return [
      Row(
        children: [
          Expanded(
            child: TextFormField(
              maxLines: 1,
              decoration: InputDecoration(labelText: 'Сумма оплаты'),
              initialValue: _amount.toString(),
              onChanged: (val) => _amount = double.tryParse(val),
            )
          ),
          SizedBox(
            width: 150,
            child: RaisedButton(
              child: Text('Оплатить'),
              onPressed: () async {
                setState(() {
                  _trId = null;
                  _paymentProgressText = 'Ожидание';
                });

                showDialog(
                  context: context,
                  builder: (BuildContext context) {
                    return Material(
                      type: MaterialType.transparency,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: _buildProgressPart()
                      )
                    );
                  }
                );

                await PaymentController.startPayment(
                  amount: _amount,
                  inputType: InputType.NFC,
                  description: 'Тестовая оплата',
                  singleStepAuth: true,
                  onPaymentError: (val) {
                    setState(() {
                      String fullErrorType = '${val['errorType']}/${val['nativeErrorType']}';

                      Navigator.pop(context);
                      _paymentProgressText = 'Произошла ошибка($fullErrorType) - ${val['errorMessage']}';
                    });
                  },
                  onPaymentStart: (val) {
                    setState(() {
                      _trId = val['id'];
                      _paymentProgressText = 'Начало операции оплаты';
                    });
                  },
                  onReaderEvent: (val) {
                    setState(() {
                      String fullReaderEventType = '${val['readerEventType']}/${val['nativeReaderEventType']}';
                      _paymentProgressText = 'Состояние терминала - $fullReaderEventType';
                    });
                  },
                  onPaymentComplete: (val) {
                    setState(() {
                      Navigator.pop(context);
                      _paymentProgressText = 'Оплата завершена успешно';
                      _trId = val['id'];
                      _requiredSignature = val['requiredSignature'];
                      print(val['transaction']);
                    });
                  }
                );
              },
            )
          )
        ]
      ),
      Padding(
        padding: EdgeInsets.only(top: 20, bottom: 20),
        child: Column(
          children: <Widget>[
            Text('Статус оплаты'),
            SizedBox(height: 10),
            Text(_paymentProgressText, style: TextStyle(fontWeight: FontWeight.bold)),
            SizedBox(height: 10),
            _trId != null ? Text('ID: $_trId') : Container()
          ]
        )
      )
    ];
  }

  List<Widget> _buildPaymentSignaturePart(BuildContext context) {
    if (!_requiredSignature)
      return [Container()];

    return [
      RaisedButton(
        child: Text('Добавить подпись'),
        onPressed: () async {
          showDialog(
            context: context,
            builder: (BuildContext context) => Center(child: CircularProgressIndicator())
          );

          await PaymentController.adjustPayment(
            trId: _trId,
            signature: await _padController.toPng(),
            onPaymentAdjust: (Map<dynamic, dynamic> result) {
              Navigator.pop(context);
              if (result['errorCode'] == 0) {
                _showSnackBar('Подпись добавлена');
                setState(() {
                  _requiredSignature = false;
                });
              } else {
                _showSnackBar('Произошла ошибка');
              }
            }
          );
      }),
      Container(
        decoration: BoxDecoration(
          border: Border.all(color: Colors.blueAccent)
        ),
        child: SizedBox(
          height: 200,
          width: 200,
          child: SignaturePadWidget(_padController, SignaturePadOptions(dotSize: 5.0, penColor: "#000000"))
        )
      )
    ];
  }

  List<Widget> _buildPaymentInfoPart(BuildContext context) {
    if (_trId == null)
      return [Container()];

    return [
      RaisedButton(
        child: Text('Информация об оплате'),
        onPressed: () async {
          showDialog(
            context: context,
            builder: (BuildContext context) => Center(child: CircularProgressIndicator())
          );

          await PaymentController.info(
            trId: _trId,
            onInfo: (Map<dynamic, dynamic> result) {
              Navigator.pop(context);
              _showSnackBar(result['errorCode'] == 0 ? 'Информация распечатана в консоль' : 'Произошла ошибка');
              print(result.toString());
            }
          );
        }
      )
    ];
  }

  List<Widget> _buildProgressPart() {
    return [
      CircularProgressIndicator(
        backgroundColor: Colors.white70,
        valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
      ),
      Container(height: 40),
      Container(height: 40),
      Container(
        height: 32,
        child: RaisedButton(
          child: Text('Отмена'),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30.0)),
          onPressed: () async {
            await PaymentController.cancel();
            Navigator.pop(context);
          }
        )
      ),
      Container(height: 40)
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        title: Text('IboxproFlutter'),
      ),
      body: Center(
        child: ListView(
          padding: EdgeInsets.all(8),
          children: _buildLoginPart(context)
            ..addAll(_buildTimeoutPart(context))
            ..addAll(_buildSearchDevicePart(context))
            ..addAll(_buildPaymentPart(context))
            ..addAll(_buildPaymentSignaturePart(context))
            ..addAll(_buildPaymentInfoPart(context))
        )
      ),
    );
  }
}
