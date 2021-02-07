import 'dart:async';

import 'package:fixnum/fixnum.dart';
import 'package:flutter/material.dart';
import 'package:phone_log/phone_log.dart';

void main() => runApp(new MyApp());

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => new _MyAppState();
}

class _MyAppState extends State<MyApp> {
  Iterable<CallRecord> _callRecords;
  final PhoneLog phoneLog = const PhoneLog();

  Future<void> fetchCallLogs() async {
    final Iterable<CallRecord> callLogs = await phoneLog.getPhoneLogs(
        // startDate: 20180605, duration: 15 seconds
        startDate: new Int64(1525590000000),
        duration: new Int64(13));
    setState(() {
      _callRecords = callLogs;
    });
  }

  void requestPermission() async {
    final bool res = await phoneLog.requestPermission();
    print("permission request result is: " + res.toString());
  }

  void checkPermission() async {
    final PermissionStatus res = await phoneLog.checkPermission();
    print("permission is: " + res.toString());
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> children = <Widget>[
      new Padding(
        padding: const EdgeInsets.all(8.0),
        child: new ElevatedButton(
            onPressed: checkPermission, child: const Text("Check permission")),
      ),
      new Padding(
        padding: const EdgeInsets.all(8.0),
        child: new ElevatedButton(
            onPressed: requestPermission,
            child: const Text("Request permission")),
      ),
      new Padding(
          padding: const EdgeInsets.all(8.0),
          child: new ElevatedButton(
              onPressed: fetchCallLogs, child: const Text("Fetch phone log"))),
    ];

    for (CallRecord call in _callRecords ?? <CallRecord>[]) {
      children.addAll(<Widget>[
        new Container(
          height: 16.0,
        ),
        new Row(
          children: <Widget>[
            new Text(call.formattedNumber ?? call.number ?? 'unknow'),
            new Padding(
              child: new Text(call.callType),
              padding: const EdgeInsets.only(left: 8.0),
            ),
          ],
          crossAxisAlignment: CrossAxisAlignment.center,
        ),
        new Row(
          children: <Widget>[
            new Padding(
              child: new Text(call.dateYear.toString() +
                  '-' +
                  call.dateMonth.toString() +
                  '-' +
                  call.dateDay.toString() +
                  '  ' +
                  call.dateHour.toString() +
                  ': ' +
                  call.dateMinute.toString() +
                  ': ' +
                  call.dateSecond.toString()),
              padding: const EdgeInsets.only(left: 8.0),
            ),
            new Padding(
                child: new Text(call.duration.toString() + 'seconds'),
                padding: const EdgeInsets.only(left: 8.0))
          ],
          crossAxisAlignment: CrossAxisAlignment.center,
        )
      ]);
    }

    return new MaterialApp(
      home: new Scaffold(
        appBar: new AppBar(title: const Text('PhoneLog plugin example')),
        body: new Center(
          child: new Column(children: children),
        ),
      ),
    );
  }
}
